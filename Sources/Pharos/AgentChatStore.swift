import Foundation
import AppKit
import PharosCore

/// How the editor entry points are shown on the AI chats overview (Settings → AI chats).
enum AgentEditorLayout: String, CaseIterable, Identifiable {
    case grid
    case strip
    var id: String { rawValue }
}

@MainActor
final class AgentChatStore: ObservableObject {
    static let shared = AgentChatStore()

    @Published private(set) var entries: [AgentDatabaseEntry] = [] {
        didSet {
            summaries = AgentChatCatalog.summarize(entries)
            summaryByEditor = Dictionary(uniqueKeysWithValues: summaries.map { ($0.editor, $0) })
            recomputeFiltered()
        }
    }
    /// Cached per-editor rollups; views read these instead of re-filtering `entries` on every render.
    @Published private(set) var summaries: [AgentEditorSummary] = []
    private var summaryByEditor: [AgentEditorKind: AgentEditorSummary] = [:]

    @Published private(set) var isScanning = false
    @Published var selectedEditor: AgentEditorKind? = nil {
        didSet {
            guard selectedEditor != oldValue else { return }
            // Each page starts unfiltered; a leftover overview search would hide the editor's databases.
            detailSearch = ""
            searchQuery = ""
            selectedScope = nil
            showOnlyOrphaned = false
            recomputeFiltered()
        }
    }
    @Published var selectedScope: AgentDatabaseScope? = nil {
        didSet { recomputeFiltered() }
    }
    @Published var showOnlyOrphaned = false {
        didSet { recomputeFiltered() }
    }
    @Published var searchQuery = "" {
        didSet { recomputeFiltered() }
    }
    @Published var detailSearch = ""
    @Published var sortOrder: AgentChatSortOrder = .sizeDesc {
        didSet { recomputeFiltered() }
    }
    /// Overview: cross-editor results (only shown while searching / filtering).
    /// Detail: databases of the selected editor.
    @Published private(set) var filteredEntries: [AgentDatabaseEntry] = []
    @Published var statusMessage: String? = nil
    @Published var isSuccessMessage = true

    @Published var editorLayout: AgentEditorLayout =
        AgentEditorLayout(rawValue: UserDefaults.standard.string(forKey: "agentEditorLayout") ?? "") ?? .grid {
        didSet { UserDefaults.standard.set(editorLayout.rawValue, forKey: "agentEditorLayout") }
    }
    @Published var chartCollapsed: Bool = UserDefaults.standard.bool(forKey: "agentChartCollapsed") {
        didSet { UserDefaults.standard.set(chartCollapsed, forKey: "agentChartCollapsed") }
    }

    private var hasScanned = false
    private var isHeavyCacheReleased = false

    private init() {
        // Lazy initialization: do not scan in init(). Scanned on-demand when AgentChatView appears.
    }

    var totalDatabases: Int { entries.count }
    var totalSize: UInt64 { summaries.reduce(0) { $0 + $1.totalBytes } }
    var totalConversations: Int { summaries.reduce(0) { $0 + $1.conversationCount } }
    var orphanedEntries: [AgentDatabaseEntry] { entries.filter(\.isOrphaned) }
    var orphanedCount: Int { summaries.reduce(0) { $0 + $1.orphanedCount } }
    var orphanedSize: UInt64 { orphanedEntries.reduce(0) { $0 + $1.fileSizeBytes } }

    /// Editors with nothing detected on disk.
    var inactiveEditors: [AgentEditorKind] {
        AgentEditorKind.allCases.filter { summaryByEditor[$0] == nil }
    }

    /// Overview shows the database list only when the user is actually looking for something.
    var isOverviewFiltering: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || showOnlyOrphaned || selectedScope != nil
    }

    func summary(for editor: AgentEditorKind) -> AgentEditorSummary? { summaryByEditor[editor] }

    func conversationRefs(for editor: AgentEditorKind) -> [AgentConversationRef] {
        AgentChatCatalog.conversations(for: editor, in: entries, query: detailSearch)
    }

    func isTruncated(_ editor: AgentEditorKind) -> Bool {
        AgentChatCatalog.isTruncated(entries.filter { $0.editor == editor })
    }

    private func recomputeFiltered() {
        let base = entries.filter { entry in
            if let editor = selectedEditor, entry.editor != editor { return false }
            if let scope = selectedScope, entry.scope != scope { return false }
            if showOnlyOrphaned && !entry.isOrphaned { return false }
            return AgentChatCatalog.matches(entry, query: searchQuery)
        }
        filteredEntries = AgentChatCatalog.sorted(base, by: sortOrder)
    }

    // MARK: - Write-operation policy

    func isEditorRunning(_ editor: AgentEditorKind) -> Bool {
        let ids = Set(editor.bundleIdentifiers)
        guard !ids.isEmpty else { return false }
        return NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier.map(ids.contains) ?? false
        }
    }

    func deleteVerdict(_ entry: AgentDatabaseEntry) -> AgentDeletePolicy.Verdict {
        AgentDeletePolicy.evaluate(entry, knownPaths: entry.editor.knownStoragePaths(), appRunning: isEditorRunning(entry.editor))
    }

    func scanIfNeeded() {
        if !hasScanned || isHeavyCacheReleased {
            isHeavyCacheReleased = false
            scan()
        }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        hasScanned = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let results = autoreleasepool {
                AgentScanner.scan()
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.entries = results
                self.isScanning = false
            }
        }
    }

    /// Releases heavy conversation arrays and text excerpts while retaining
    /// database summaries (name, path, size, counts) to prevent UI flicker when reopened.
    func releaseHeavyCache() {
        guard !entries.isEmpty else { return }
        isHeavyCacheReleased = true
        entries = entries.map { e in
            guard !e.conversations.isEmpty else { return e }
            return AgentDatabaseEntry(
                id: e.id,
                editor: e.editor,
                scope: e.scope,
                filePath: e.filePath,
                fileName: e.fileName,
                storageDirectory: e.storageDirectory,
                fileSizeBytes: e.fileSizeBytes,
                lastModified: e.lastModified,
                workspacePath: e.workspacePath,
                workspaceName: e.workspaceName,
                isOrphaned: e.isOrphaned,
                conversationCount: e.conversationCount,
                conversations: []
            )
        }
    }

    func revealInFinder(_ entry: AgentDatabaseEntry) {
        NSWorkspace.shared.selectFile(entry.filePath, inFileViewerRootedAtPath: (entry.filePath as NSString).deletingLastPathComponent)
    }

    func revealPath(_ path: String) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            } else {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: (path as NSString).deletingLastPathComponent)
            }
        }
    }

    func openProjectInTerminal(_ entry: AgentDatabaseEntry) {
        guard let path = entry.workspacePath, FileManager.default.fileExists(atPath: path) else { return }
        let term = UserDefaults.standard.string(forKey: "preferredTerminal") ?? "terminal"
        let app = switch term {
        case "iterm2": "iTerm"
        case "ghostty": "Ghostty"
        case "warp": "Warp"
        default: "Terminal"
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", app, path]
        try? proc.run()
    }

    /// Backups go only to the file the user picks in the save panel (AGENTS.md §4 backups).
    func backupEntry(_ entry: AgentDatabaseEntry) {
        let l10n = L10n.shared
        let panel = NSSavePanel()
        panel.nameFieldStringValue = AgentDatabaseManager.suggestedBackupName(for: entry)
        panel.canCreateDirectories = true
        panel.title = l10n.backupDatabase
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                // The panel already asked the user to confirm replacing the file.
                try FileManager.default.removeItem(at: url)
            }
            try AgentDatabaseManager.backupEntry(entry, to: url)
            isSuccessMessage = true
            statusMessage = l10n.agentDbBackupSuccess(url.lastPathComponent)
        } catch {
            isSuccessMessage = false
            statusMessage = l10n.agentBackupFailed(error.localizedDescription)
        }
    }

    func deleteEntry(_ entry: AgentDatabaseEntry) {
        let l10n = L10n.shared
        do {
            try AgentDatabaseManager.deleteEntry(entry, appRunning: isEditorRunning(entry.editor))
            entries.removeAll { $0.id == entry.id }
            isSuccessMessage = true
            statusMessage = l10n.agentDbCleanSuccess(entry.workspaceName)
        } catch AgentDatabaseManager.DeleteError.refused(let verdict) {
            isSuccessMessage = false
            statusMessage = l10n.agentDeleteRefused(verdict)
        } catch {
            isSuccessMessage = false
            statusMessage = l10n.agentDeleteFailed(error.localizedDescription)
        }
    }

    func cleanAllOrphaned() {
        let targets = orphanedEntries
        guard !targets.isEmpty else { return }
        let result = AgentDatabaseManager.cleanOrphanedEntries(targets)
        let removed = Set(result.deletedIds)
        entries.removeAll { removed.contains($0.id) }
        isSuccessMessage = result.failed == 0
        statusMessage = L10n.shared.agentOrphanedCleanResult(
            count: removed.count, size: ByteFormat.short(result.bytesFreed), skipped: result.skipped, failed: result.failed
        )
    }
}
