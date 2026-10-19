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
    @Published var selectedCustomName: String? = nil
    @Published var selectedCustomAppPath: String? = nil

    func selectEditor(_ summary: AgentEditorSummary) {
        selectedCustomName = summary.customEditorName
        selectedCustomAppPath = summary.customAppPath
        selectedEditor = summary.editor
    }

    func resetSelection() {
        selectedCustomName = nil
        selectedCustomAppPath = nil
        selectedEditor = nil
    }

    private let customAppPathsKey = "customAgentAppPaths"
    var customAppPaths: [String] {
        get { UserDefaults.standard.stringArray(forKey: customAppPathsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: customAppPathsKey) }
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
        AgentEditorKind.allCases.filter { ed in
            ed != .custom && summaryByEditor[ed] == nil
        }
    }

    /// Overview shows search results only when the user is actively searching.
    var isOverviewFiltering: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func summary(for editor: AgentEditorKind, customName: String? = nil) -> AgentEditorSummary? {
        if editor == .custom {
            return summaries.first { $0.editor == .custom && $0.customEditorName == customName }
        }
        return summaryByEditor[editor]
    }

    func conversationRefs(for editor: AgentEditorKind, customName: String? = nil) -> [AgentConversationRef] {
        AgentChatCatalog.conversations(for: editor, in: entries, query: detailSearch, customName: customName)
    }

    func isTruncated(_ editor: AgentEditorKind) -> Bool {
        AgentChatCatalog.isTruncated(entries.filter { $0.editor == editor })
    }

    private func recomputeFiltered() {
        let base = entries.filter { entry in
            if let editor = selectedEditor {
                if entry.editor != editor { return false }
                if editor == .custom, let custom = selectedCustomName, entry.customEditorName != custom {
                    return false
                }
            }
            if let scope = selectedScope, entry.scope != scope { return false }
            if showOnlyOrphaned && !entry.isOrphaned { return false }
            return AgentChatCatalog.matches(entry, query: searchQuery)
        }
        filteredEntries = AgentChatCatalog.sorted(base, by: sortOrder)
    }

    // MARK: - Write-operation policy

    func isEditorRunning(_ editor: AgentEditorKind) -> Bool {
        if editor == .custom {
            return false
        }
        let ids = Set(editor.bundleIdentifiers)
        guard !ids.isEmpty else { return false }
        return NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier.map(ids.contains) ?? false
        }
    }

    func isCustomAppRunning(appPath: String?) -> Bool {
        guard let appPath else { return false }
        let normPath = (appPath as NSString).standardizingPath
        return NSWorkspace.shared.runningApplications.contains { app in
            guard let bundleURL = app.bundleURL else { return false }
            return (bundleURL.path as NSString).standardizingPath == normPath
        }
    }

    func deleteVerdict(_ entry: AgentDatabaseEntry) -> AgentDeletePolicy.Verdict {
        let known = entry.editor == .custom ? [
            AgentKnownPath(label: entry.workspaceName, fullPath: entry.filePath, scope: entry.scope),
            AgentKnownPath(label: entry.workspaceName, fullPath: entry.storageDirectory, scope: entry.scope, isDirectory: true)
        ] : entry.editor.knownStoragePaths()
        let running = entry.editor == .custom ? isCustomAppRunning(appPath: entry.customAppPath) : isEditorRunning(entry.editor)
        return AgentDeletePolicy.evaluate(entry, knownPaths: known, appRunning: running)
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
        let paths = customAppPaths
        Task.detached(priority: .userInitiated) { [weak self] in
            let results = autoreleasepool {
                AgentScanner.scan(customAppPaths: paths)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.entries = results
                self.isScanning = false
            }
        }
    }

    /// Adds a user-selected application bundle from /Applications and triggers a dedicated scan.
    func addCustomApplication() {
        let l10n = L10n.shared
        let panel = NSOpenPanel()
        panel.title = l10n.agentAddAppPanelTitle
        panel.message = l10n.agentAddAppPanelMessage
        panel.prompt = l10n.agentAddAppPanelPrompt
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        addAndScanApplication(at: url.path)
    }

    /// Specifically scans a single application added by the user.
    func addAndScanApplication(at path: String) {
        var paths = customAppPaths
        if !paths.contains(path) {
            paths.append(path)
            customAppPaths = paths
        }

        isScanning = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let newEntries = autoreleasepool {
                AgentScanner.scanApplication(at: path)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isScanning = false
                let appName = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")

                if newEntries.isEmpty {
                    self.isSuccessMessage = false
                    self.statusMessage = L10n.shared.agentAddAppNoDbsFound(appName)
                } else {
                    var updated = self.entries.filter { old in !newEntries.contains { $0.id == old.id } }
                    updated.append(contentsOf: newEntries)
                    self.entries = updated
                    let totalBytes = newEntries.reduce(0) { $0 + $1.fileSizeBytes }
                    self.isSuccessMessage = true
                    self.statusMessage = L10n.shared.agentAddAppSuccess(appName, count: newEntries.count, size: ByteFormat.short(totalBytes))
                }
            }
        }
    }

    /// Removes a custom application and its entries from Pharos.
    func removeCustomApplication(named name: String?, appPath: String?) {
        if let appPath {
            var paths = customAppPaths
            paths.removeAll { $0 == appPath }
            customAppPaths = paths
        }
        entries.removeAll { e in
            if let name, e.customEditorName == name { return true }
            if let appPath, e.customAppPath == appPath { return true }
            return false
        }
        resetSelection()
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
                conversations: [],
                customEditorName: e.customEditorName,
                customAppPath: e.customAppPath
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

    /// Prompts the user with 2 consecutive confirmation dialogs before deleting the database.
    func confirmAndDelete(_ entry: AgentDatabaseEntry) {
        let l10n = L10n.shared

        // --- Dialog 1: Warning about the database file & editor running state ---
        let alert1 = NSAlert()
        alert1.alertStyle = .warning
        alert1.messageText = l10n.deleteDbFirstAlertTitle(entry.workspaceName)

        let scopeLabel = entry.scope == .global ? l10n.agentScopeShortGlobal : (entry.scope == .vectorCache ? l10n.agentScopeShortCache : l10n.agentScopeShortWorkspace)
        var info1 = l10n.deleteDbFirstAlertMessage(
            path: entry.filePath,
            size: ByteFormat.disk(entry.fileSizeBytes),
            scope: scopeLabel
        )
        if isEditorRunning(entry.editor) {
            info1 += "\n\n⚠️ " + l10n.deleteDbEditorRunningWarning(entry.editor.displayName)
        }
        alert1.informativeText = info1

        let btnProceed = alert1.addButton(withTitle: l10n.deleteDbProceedToConfirm)
        alert1.addButton(withTitle: l10n.cancel)
        btnProceed.hasDestructiveAction = true

        guard alert1.runModal() == .alertFirstButtonReturn else {
            return
        }

        // --- Dialog 2: Critical irreversible warning ---
        let alert2 = NSAlert()
        alert2.alertStyle = .critical
        alert2.messageText = l10n.deleteDbSecondAlertTitle(entry.workspaceName)
        alert2.informativeText = l10n.deleteDbSecondAlertMessage

        let btnDelete = alert2.addButton(withTitle: l10n.deleteDbFinalConfirmButton)
        alert2.addButton(withTitle: l10n.cancel)
        btnDelete.hasDestructiveAction = true

        guard alert2.runModal() == .alertFirstButtonReturn else {
            return
        }

        // Both confirmed -> perform actual deletion
        deleteEntry(entry)
    }

    func deleteEntry(_ entry: AgentDatabaseEntry) {
        let l10n = L10n.shared
        do {
            let known = entry.editor == .custom ? [
                AgentKnownPath(label: entry.workspaceName, fullPath: entry.filePath, scope: entry.scope),
                AgentKnownPath(label: entry.workspaceName, fullPath: entry.storageDirectory, scope: entry.scope, isDirectory: true)
            ] : entry.editor.knownStoragePaths()
            let running = entry.editor == .custom ? isCustomAppRunning(appPath: entry.customAppPath) : isEditorRunning(entry.editor)
            try AgentDatabaseManager.deleteEntry(entry, knownPaths: known, appRunning: running)
            if entry.isOrphaned && entry.scope == .workspace {
                let dir = entry.storageDirectory
                entries.removeAll { $0.storageDirectory == dir || $0.filePath.hasPrefix(dir) }
            } else {
                entries.removeAll { $0.id == entry.id }
            }
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

    func cleanOrphaned(for editor: AgentEditorKind) {
        let targets = entries.filter { $0.editor == editor && $0.isOrphaned }
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
