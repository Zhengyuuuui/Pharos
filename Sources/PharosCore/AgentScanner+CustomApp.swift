import Darwin
import Foundation

extension AgentScanner {
    /// Specifically scans a single application added by the user (from /Applications or any path).
    public static func scanApplication(
        at appPath: String,
        homeDirectory: String = NSHomeDirectory(),
        previousEntries: [AgentDatabaseEntry] = []
    ) -> [AgentDatabaseEntry] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: appPath) else { return [] }
        let cache = Dictionary(previousEntries.map { ($0.filePath, $0) }, uniquingKeysWith: { first, _ in first })

        // Read Info.plist if available
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        var bundleId: String?
        var bundleName: String?
        var displayName: String?

        if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            bundleId = plist["CFBundleIdentifier"] as? String
            bundleName = plist["CFBundleName"] as? String
            displayName = plist["CFBundleDisplayName"] as? String
        }

        let rawAppName = ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let resolvedName = displayName ?? bundleName ?? rawAppName

        // Check if it matches a predefined AgentEditorKind
        let appFileName = (appPath as NSString).lastPathComponent
        var matchedKind: AgentEditorKind? = nil
        for kind in AgentEditorKind.allCases where kind != .custom {
            if let bid = bundleId, kind.bundleIdentifiers.contains(bid) { matchedKind = kind; break }
            if kind.appNames.contains(appFileName) { matchedKind = kind; break }
            if kind.displayName.lowercased() == resolvedName.lowercased() { matchedKind = kind; break }
            if resolvedName.lowercased().contains(kind.rawValue.lowercased()) { matchedKind = kind; break }
        }

        var results: [AgentDatabaseEntry] = []

        if let kind = matchedKind {
            switch kind {
            case .cursor: results += scanCursor(home: homeDirectory, cache: cache)
            case .trae: results += scanTrae(home: homeDirectory, cache: cache)
            case .windsurf: results += scanWindsurf(home: homeDirectory, cache: cache)
            case .vscode: results += scanVSCode(home: homeDirectory, cache: cache)
            case .antigravity: results += scanAntigravity(home: homeDirectory, cache: cache)
            case .qoder: results += scanQoder(home: homeDirectory, cache: cache)
            case .cherryStudio: results += scanCherryStudio(home: homeDirectory, cache: cache)
            case .codeBuddy: results += scanCodeBuddy(home: homeDirectory, cache: cache)
            case .kiro: results += scanKiro(home: homeDirectory, cache: cache)
            case .openCode: results += scanOpenCode(home: homeDirectory, cache: cache)
            case .claudeCode: results += scanClaudeCode(home: homeDirectory, cache: cache)
            case .zed: results += scanZed(home: homeDirectory, cache: cache)
            case .workBuddy: results += scanWorkBuddy(home: homeDirectory, cache: cache)
            case .miniMax: results += scanMiniMax(home: homeDirectory, cache: cache)
            case .zCode: results += scanZCode(home: homeDirectory, cache: cache)
            case .continueExt: results += scanContinue(home: homeDirectory, cache: cache)
            case .aider: results += scanAider(home: homeDirectory, cache: cache)
            case .doubao: results += scanDoubao(home: homeDirectory, cache: cache)
            case .chatgpt: results += scanChatGPT(home: homeDirectory, cache: cache)
            case .marvis: results += scanMarvis(home: homeDirectory, cache: cache)
            case .wechatDevTools: results += scanWeChatDevTools(home: homeDirectory, cache: cache)
            case .hbuilder: results += scanHBuilder(home: homeDirectory, cache: cache)
            case .deepseek: results += scanDeepSeek(home: homeDirectory, cache: cache)
            case .autoClaw: results += scanAutoClaw(home: homeDirectory, cache: cache)
            case .ccSwitch: results += scanCCSwitch(home: homeDirectory, cache: cache)
            case .yDevSphere: results += scanYDevSphere(home: homeDirectory, cache: cache)
            case .devin: results += scanDevin(home: homeDirectory, cache: cache)
            case .custom: break
            }
        }

        // Deep probe candidate storage directories for this app
        var candidateDirs: Set<String> = []
        var namesToProbe: [String] = [resolvedName, rawAppName]
        if let bn = bundleName { namesToProbe.append(bn) }
        if let bid = bundleId, let lastPart = bid.components(separatedBy: ".").last { namesToProbe.append(lastPart) }

        for name in namesToProbe {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/\(trimmed)")
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/\(trimmed) CN")
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/\(trimmed) AI")
            candidateDirs.insert("\(homeDirectory)/.\(trimmed.lowercased())")
            candidateDirs.insert("\(homeDirectory)/.\(trimmed.lowercased())-ai")
            candidateDirs.insert("\(homeDirectory)/.config/\(trimmed.lowercased())")
            candidateDirs.insert("\(homeDirectory)/.local/share/\(trimmed.lowercased())")
        }

        if let bid = bundleId, !bid.isEmpty {
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/\(bid)")
            candidateDirs.insert("\(homeDirectory)/Library/Containers/\(bid)/Data/Library/Application Support/\(resolvedName)")
            candidateDirs.insert("\(homeDirectory)/Library/Containers/\(bid)/Data/Library/Application Support")
        }

        if resolvedName.lowercased().contains("ollama") {
            candidateDirs.insert("\(homeDirectory)/.ollama")
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/Ollama")
        }
        if resolvedName.lowercased().contains("lm studio") {
            candidateDirs.insert("\(homeDirectory)/.cache/lm-studio")
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/LM Studio")
        }

        let editorKind = matchedKind ?? .custom

        for dir in candidateDirs {
            guard fm.fileExists(atPath: dir) else { continue }

            // 1. VS Code style workspaceStorage
            let wsCandidates = [
                (dir as NSString).appendingPathComponent("User/workspaceStorage"),
                (dir as NSString).appendingPathComponent("workspaceStorage")
            ]
            for wsRoot in wsCandidates where fm.fileExists(atPath: wsRoot) {
                let wsEntries = scanWorkspaceStorage(root: wsRoot, editor: editorKind, cache: cache)
                for entry in wsEntries {
                    results.append(AgentDatabaseEntry(
                        id: entry.id,
                        editor: editorKind,
                        scope: .workspace,
                        filePath: entry.filePath,
                        fileName: entry.fileName,
                        storageDirectory: entry.storageDirectory,
                        fileSizeBytes: entry.fileSizeBytes,
                        lastModified: entry.lastModified,
                        workspacePath: entry.workspacePath,
                        workspaceName: entry.workspaceName,
                        isOrphaned: entry.isOrphaned,
                        conversationCount: entry.conversationCount,
                        conversations: entry.conversations,
                        customEditorName: resolvedName,
                        customAppPath: appPath,
                        fingerprint: entry.fingerprint
                    ))
                }
            }

            // 2. Global state.vscdb
            let globalCandidates = [
                (dir as NSString).appendingPathComponent("User/globalStorage/state.vscdb"),
                (dir as NSString).appendingPathComponent("globalStorage/state.vscdb")
            ]
            for gPath in globalCandidates where fm.fileExists(atPath: gPath) {
                if let entry = resolveDatabaseEntry(
                    id: gPath,
                    editor: editorKind,
                    scope: .global,
                    filePath: gPath,
                    fileName: "state.vscdb",
                    storageDirectory: (gPath as NSString).deletingLastPathComponent,
                    workspaceName: "\(resolvedName) 全局状态",
                    isOrphaned: false,
                    customEditorName: resolvedName,
                    customAppPath: appPath,
                    cache: cache,
                    readConversations: { AgentSQLiteReader.readCursorConversations(dbPath: gPath) }
                ) {
                    results.append(entry)
                }
            }

            // 3. Scan directory files for SQLite databases (*.db, *.sqlite, *.sqlite3)
            let dbFiles = findDatabaseFiles(in: dir, maxDepth: 2)
            for filePath in dbFiles {
                let fileName = (filePath as NSString).lastPathComponent
                if fileName == "state.vscdb" && results.contains(where: { $0.filePath == filePath }) {
                    continue
                }
                guard AgentSQLiteReader.isSQLiteFile(atPath: filePath) else { continue }
                let scope: AgentDatabaseScope = filePath.contains("cache") || filePath.contains("index") ? .vectorCache : .global

                if let entry = resolveDatabaseEntry(
                    id: filePath,
                    editor: editorKind,
                    scope: scope,
                    filePath: filePath,
                    fileName: fileName,
                    storageDirectory: (filePath as NSString).deletingLastPathComponent,
                    workspaceName: "\(resolvedName) (\(fileName))",
                    isOrphaned: false,
                    customEditorName: resolvedName,
                    customAppPath: appPath,
                    cache: cache,
                    readConversations: { AgentSQLiteReader.readGenericConversations(dbPath: filePath) }
                ) {
                    results.append(entry)
                }
            }
        }

        // Deduplicate by entry.id
        var seen = Set<String>()
        var uniqueResults: [AgentDatabaseEntry] = []
        for e in results {
            if seen.insert(e.id).inserted {
                uniqueResults.append(e)
            }
        }

        return uniqueResults.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
    }

    private static func findDatabaseFiles(in dir: String, maxDepth: Int) -> [String] {
        guard maxDepth >= 0 else { return [] }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        var results: [String] = []
        for item in items {
            if item.hasPrefix(".") || item == "node_modules" || item == "Pods" || item == "DerivedData" || item == "Cache" || item == "Caches" {
                continue
            }
            let fullPath = (dir as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: fullPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    if maxDepth > 0 && !["GPUCache", "DawnCache", "blob_storage", "Session Storage", "IndexedDB", "Local Storage"].contains(item) {
                        results += findDatabaseFiles(in: fullPath, maxDepth: maxDepth - 1)
                    }
                } else {
                    let ext = (item as NSString).pathExtension.lowercased()
                    if ["db", "sqlite", "sqlite3", "vscdb", "db3"].contains(ext) {
                        if !item.hasSuffix("-wal") && !item.hasSuffix("-shm") && !item.hasSuffix("-journal") {
                            results.append(fullPath)
                        }
                    }
                }
            }
        }
        return results
    }

}
