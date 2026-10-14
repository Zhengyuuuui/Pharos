import Foundation
import AppKit
import PharosCore

@MainActor
final class AgentChatStore: ObservableObject {
    static let shared = AgentChatStore()

    @Published private(set) var entries: [AgentDatabaseEntry] = [] {
        didSet { recomputeFiltered() }
    }
    @Published private(set) var isScanning = false
    @Published var selectedEditor: AgentEditorKind? = nil {
        didSet { recomputeFiltered() }
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
    @Published var sortOrder: SortOrder = .sizeDesc {
        didSet { recomputeFiltered() }
    }
    @Published private(set) var filteredEntries: [AgentDatabaseEntry] = []
    @Published var selectedEntryId: String? = nil
    @Published var statusMessage: String? = nil
    @Published var isSuccessMessage = true

    enum SortOrder: String, CaseIterable, Identifiable {
        case sizeDesc
        case mtimeDesc
        case nameAsc

        var id: String { rawValue }
    }

    private init() {
        scan()
    }

    var totalDatabases: Int { entries.count }
    var totalSize: UInt64 { entries.reduce(0) { $0 + $1.fileSizeBytes } }
    var totalConversations: Int { entries.reduce(0) { $0 + $1.conversationCount } }
    var orphanedEntries: [AgentDatabaseEntry] { entries.filter(\.isOrphaned) }
    var orphanedCount: Int { orphanedEntries.count }
    var orphanedSize: UInt64 { orphanedEntries.reduce(0) { $0 + $1.fileSizeBytes } }

    var editorsInUse: [AgentEditorKind] {
        let set = Set(entries.map(\.editor))
        return AgentEditorKind.allCases.filter { set.contains($0) }
    }

    /// Editors that have detected databases on the machine, sorted by total size descending
    var activeEditorsWithData: [AgentEditorKind] {
        let set = Set(entries.map(\.editor))
        return AgentEditorKind.allCases
            .filter { set.contains($0) && count(for: $0) > 0 }
            .sorted { size(for: $0) > size(for: $1) }
    }

    /// Editors that have NO database data detected on disk (or are uninstalled without DB)
    var inactiveEditors: [AgentEditorKind] {
        let set = Set(entries.map(\.editor))
        return AgentEditorKind.allCases.filter { !set.contains($0) || count(for: $0) == 0 }
    }

    var displayedEditors: [AgentEditorKind] {
        let inUseSet = Set(entries.map(\.editor))
        let inUse = AgentEditorKind.allCases.filter { inUseSet.contains($0) }
        let installed = AgentEditorKind.allCases.filter { !inUseSet.contains($0) && $0.isAppInstalled }
        let others = AgentEditorKind.allCases.filter { !inUseSet.contains($0) && !$0.isAppInstalled }
        return inUse + installed + others
    }

    func conversations(for editor: AgentEditorKind) -> [AgentConversationSummary] {
        entries.filter { $0.editor == editor }.flatMap(\.conversations)
    }

    func count(for editor: AgentEditorKind) -> Int {
        entries.filter { $0.editor == editor }.count
    }

    func conversationCount(for editor: AgentEditorKind) -> Int {
        entries.filter { $0.editor == editor }.reduce(0) { $0 + $1.conversationCount }
    }

    func size(for editor: AgentEditorKind) -> UInt64 {
        entries.filter { $0.editor == editor }.reduce(0) { $0 + $1.fileSizeBytes }
    }

    struct EditorStorageSummary: Identifiable {
        let editor: AgentEditorKind
        let totalBytes: UInt64
        let databaseCount: Int
        let conversationCount: Int
        let workspaceBytes: UInt64
        let globalBytes: UInt64
        let cacheBytes: UInt64

        var id: String { editor.rawValue }
    }

    var editorSummaries: [EditorStorageSummary] {
        let inUse = editorsInUse
        return inUse.map { ed in
            let edEntries = entries.filter { $0.editor == ed }
            let total = edEntries.reduce(0) { $0 + $1.fileSizeBytes }
            let ws = edEntries.filter { $0.scope == .workspace }.reduce(0) { $0 + $1.fileSizeBytes }
            let glob = edEntries.filter { $0.scope == .global }.reduce(0) { $0 + $1.fileSizeBytes }
            let cache = edEntries.filter { $0.scope == .vectorCache }.reduce(0) { $0 + $1.fileSizeBytes }
            let convs = edEntries.reduce(0) { $0 + $1.conversationCount }
            return EditorStorageSummary(
                editor: ed,
                totalBytes: total,
                databaseCount: edEntries.count,
                conversationCount: convs,
                workspaceBytes: ws,
                globalBytes: glob,
                cacheBytes: cache
            )
        }
        .sorted { $0.totalBytes > $1.totalBytes }
    }

    private func recomputeFiltered() {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        filteredEntries = entries.filter { entry in
            if let editor = selectedEditor, entry.editor != editor { return false }
            if let scope = selectedScope, entry.scope != scope { return false }
            if showOnlyOrphaned && !entry.isOrphaned { return false }
            if !q.isEmpty {
                let matchesName = entry.workspaceName.lowercased().contains(q)
                let matchesPath = (entry.workspacePath?.lowercased().contains(q) ?? false) || entry.filePath.lowercased().contains(q)
                let matchesConv = entry.conversations.contains { $0.title.lowercased().contains(q) }
                if !matchesName && !matchesPath && !matchesConv { return false }
            }
            return true
        }
        .sorted { a, b in
            switch sortOrder {
            case .sizeDesc: return a.fileSizeBytes > b.fileSizeBytes
            case .mtimeDesc: return a.lastModified > b.lastModified
            case .nameAsc: return a.workspaceName.localizedCaseInsensitiveCompare(b.workspaceName) == .orderedAscending
            }
        }
    }

    var selectedEntry: AgentDatabaseEntry? {
        if let id = selectedEntryId, let found = entries.first(where: { $0.id == id }) {
            return found
        }
        return filteredEntries.first
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let results = AgentScanner.scan()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.entries = results
                self.isScanning = false
                if self.selectedEntryId == nil || !results.contains(where: { $0.id == self.selectedEntryId }) {
                    self.selectedEntryId = results.first?.id
                }
            }
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

    func backupEntry(_ entry: AgentDatabaseEntry) {
        let home = NSHomeDirectory()
        let backupDir = URL(fileURLWithPath: (home as NSString).appendingPathComponent("Library/Application Support/Pharos/backups/agent_dbs"))
        do {
            let saved = try AgentDatabaseManager.backupEntry(entry, toDirectory: backupDir)
            isSuccessMessage = true
            statusMessage = L10n.shared.agentDbBackupSuccess(saved.lastPathComponent)
        } catch {
            isSuccessMessage = false
            statusMessage = "Backup failed: \(error.localizedDescription)"
        }
    }

    func deleteEntry(_ entry: AgentDatabaseEntry) {
        do {
            try AgentDatabaseManager.deleteEntry(entry)
            entries.removeAll { $0.id == entry.id }
            isSuccessMessage = true
            statusMessage = L10n.shared.agentDbCleanSuccess(entry.workspaceName)
        } catch {
            isSuccessMessage = false
            statusMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    func cleanAllOrphaned() {
        let targets = orphanedEntries
        guard !targets.isEmpty else { return }
        do {
            let result = try AgentDatabaseManager.cleanOrphanedEntries(targets)
            entries.removeAll { $0.isOrphaned }
            isSuccessMessage = true
            statusMessage = L10n.shared.agentOrphanedCleanSuccess(count: result.count, size: ByteFormat.short(result.bytesFreed))
        } catch {
            isSuccessMessage = false
            statusMessage = "Clean orphaned failed: \(error.localizedDescription)"
        }
    }
}
