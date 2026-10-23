import Darwin
import Foundation

public enum AgentScanner {
    /// Resolves an entry incrementally: if the file attributes and WAL attributes match the cached entry,
    /// reuses previously parsed conversations, skipping expensive disk I/O.
    public static func resolveDatabaseEntry(
        id: String? = nil,
        editor: AgentEditorKind,
        scope: AgentDatabaseScope,
        filePath: String,
        fileName: String? = nil,
        storageDirectory: String? = nil,
        workspacePath: String? = nil,
        workspaceName: String,
        isOrphaned: Bool,
        customEditorName: String? = nil,
        customAppPath: String? = nil,
        customCount: Int? = nil,
        cache: [String: AgentDatabaseEntry] = [:],
        readConversations: () -> [AgentConversationSummary] = { [] }
    ) -> AgentDatabaseEntry? {
        guard let fingerprint = AgentDatabaseFingerprint.compute(for: filePath, isOrphaned: isOrphaned) else {
            return nil
        }
        let totalSize = fingerprint.fileSizeBytes + fingerprint.walSizeBytes
        let resolvedFileName = fileName ?? (filePath as NSString).lastPathComponent
        let resolvedStorageDir = storageDirectory ?? (filePath as NSString).deletingLastPathComponent
        let entryId = id ?? filePath

        // Incremental cache lookup
        if let previous = cache[filePath] ?? cache[entryId],
           fingerprint.matchesPrevious(entry: previous) {
            // CACHE HIT: reuse previous conversations and counts
            return AgentDatabaseEntry(
                id: entryId,
                editor: editor,
                scope: scope,
                filePath: filePath,
                fileName: resolvedFileName,
                storageDirectory: resolvedStorageDir,
                fileSizeBytes: totalSize,
                lastModified: fingerprint.modificationDate,
                workspacePath: workspacePath,
                workspaceName: workspaceName,
                isOrphaned: isOrphaned,
                conversationCount: previous.conversationCount,
                conversations: previous.conversations,
                customEditorName: customEditorName,
                customAppPath: customAppPath,
                fingerprint: fingerprint
            )
        }

        // CACHE MISS: parse conversations
        let convs = readConversations()
        let count = customCount ?? convs.count
        return AgentDatabaseEntry(
            id: entryId,
            editor: editor,
            scope: scope,
            filePath: filePath,
            fileName: resolvedFileName,
            storageDirectory: resolvedStorageDir,
            fileSizeBytes: totalSize,
            lastModified: fingerprint.modificationDate,
            workspacePath: workspacePath,
            workspaceName: workspaceName,
            isOrphaned: isOrphaned,
            conversationCount: count,
            conversations: convs,
            customEditorName: customEditorName,
            customAppPath: customAppPath,
            fingerprint: fingerprint
        )
    }

    /// Scans all supported local AI agent editors for conversation databases, plus any user-specified custom application paths.
    public static func scanAll(
        homeDirectory: String = NSHomeDirectory(),
        customAppPaths: [String] = [],
        previousEntries: [AgentDatabaseEntry] = []
    ) -> [AgentDatabaseEntry] {
        let cache = Dictionary(previousEntries.map { ($0.filePath, $0) }, uniquingKeysWith: { first, _ in first })
        var entries: [AgentDatabaseEntry] = []
        entries += scanCursor(home: homeDirectory, cache: cache)
        entries += scanTrae(home: homeDirectory, cache: cache)
        entries += scanWindsurf(home: homeDirectory, cache: cache)
        entries += scanVSCode(home: homeDirectory, cache: cache)
        entries += scanAntigravity(home: homeDirectory, cache: cache)
        entries += scanQoder(home: homeDirectory, cache: cache)
        entries += scanCherryStudio(home: homeDirectory, cache: cache)
        entries += scanCodeBuddy(home: homeDirectory, cache: cache)
        entries += scanKiro(home: homeDirectory, cache: cache)
        entries += scanOpenCode(home: homeDirectory, cache: cache)
        entries += scanClaudeCode(home: homeDirectory, cache: cache)
        entries += scanZed(home: homeDirectory, cache: cache)
        entries += scanWorkBuddy(home: homeDirectory, cache: cache)
        entries += scanMiniMax(home: homeDirectory, cache: cache)
        entries += scanZCode(home: homeDirectory, cache: cache)
        entries += scanContinue(home: homeDirectory, cache: cache)
        entries += scanAider(home: homeDirectory, cache: cache)
        entries += scanDoubao(home: homeDirectory, cache: cache)
        entries += scanChatGPT(home: homeDirectory, cache: cache)
        entries += scanMarvis(home: homeDirectory, cache: cache)
        entries += scanWeChatDevTools(home: homeDirectory, cache: cache)
        entries += scanHBuilder(home: homeDirectory, cache: cache)
        entries += scanDeepSeek(home: homeDirectory, cache: cache)
        entries += scanAutoClaw(home: homeDirectory, cache: cache)
        entries += scanCCSwitch(home: homeDirectory, cache: cache)
        entries += scanYDevSphere(home: homeDirectory, cache: cache)
        entries += scanDevin(home: homeDirectory, cache: cache)

        for path in customAppPaths {
            entries += scanApplication(at: path, homeDirectory: homeDirectory, previousEntries: previousEntries)
        }

        // Deduplicate by entry.id and sort by file size descending
        var seen = Set<String>()
        var deduped: [AgentDatabaseEntry] = []
        for e in entries {
            if seen.insert(e.id).inserted {
                deduped.append(e)
            }
        }
        return deduped.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
    }

    /// Scans all supported local AI agent editors for conversation databases, plus any user-specified custom application paths.
    public static func scan(
        homeDirectory: String = NSHomeDirectory(),
        customAppPaths: [String] = [],
        previousEntries: [AgentDatabaseEntry] = []
    ) -> [AgentDatabaseEntry] {
        scanAll(homeDirectory: homeDirectory, customAppPaths: customAppPaths, previousEntries: previousEntries)
    }



    // MARK: - Cursor
    public static func scanCursor(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        let base = (home as NSString).appendingPathComponent("Library/Application Support/Cursor/User")
        var results: [AgentDatabaseEntry] = []

        // Global storage
        let globalDb = (base as NSString).appendingPathComponent("globalStorage/state.vscdb")
        if let entry = resolveDatabaseEntry(
            id: globalDb,
            editor: .cursor,
            scope: .global,
            filePath: globalDb,
            fileName: "state.vscdb",
            storageDirectory: (globalDb as NSString).deletingLastPathComponent,
            workspaceName: "Global Composer Sessions",
            isOrphaned: false,
            cache: cache,
            readConversations: { AgentSQLiteReader.readCursorConversations(dbPath: globalDb) }
        ) {
            results.append(entry)
        }

        // AI code tracking
        let trackDb = (home as NSString).appendingPathComponent(".cursor/ai-tracking/ai-code-tracking.db")
        if let entry = resolveDatabaseEntry(
            id: trackDb,
            editor: .cursor,
            scope: .global,
            filePath: trackDb,
            fileName: "ai-code-tracking.db",
            storageDirectory: (trackDb as NSString).deletingLastPathComponent,
            workspaceName: "Cursor AI 代码追踪库",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }

        // Workspace storage
        let wsRoot = (base as NSString).appendingPathComponent("workspaceStorage")
        results += scanWorkspaceStorage(root: wsRoot, editor: .cursor, cache: cache)

        return results
    }

    // MARK: - Trae
    public static func scanTrae(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let variants = ["Trae CN", "TRAE SOLO CN", "Trae"]

        for variant in variants {
            let base = (home as NSString).appendingPathComponent("Library/Application Support/\(variant)/User")

            // Modular AI Agent Database (Trae's primary conversation DB ~481+ MB)
            let modularDb = (home as NSString).appendingPathComponent("Library/Application Support/\(variant)/ModularData/ai-agent/database.db")
            let modularDir = (modularDb as NSString).deletingLastPathComponent
            if let entry = resolveDatabaseEntry(
                id: modularDb,
                editor: .trae,
                scope: .global,
                filePath: modularDb,
                fileName: "database.db (AI Agent)",
                storageDirectory: modularDir,
                workspaceName: "\(variant) AI Agent Sessions",
                isOrphaned: false,
                cache: cache,
                readConversations: { AgentSQLiteReader.readTraeAgentDatabaseSessions(modularDir: modularDir) }
            ) {
                results.append(entry)
            }

            // Global storage
            let globalDb = (base as NSString).appendingPathComponent("globalStorage/state.vscdb")
            if let entry = resolveDatabaseEntry(
                id: globalDb,
                editor: .trae,
                scope: .global,
                filePath: globalDb,
                fileName: "state.vscdb",
                storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                workspaceName: "\(variant) Global Storage",
                isOrphaned: false,
                cache: cache,
                readConversations: { AgentSQLiteReader.readTraeSessions(dbPath: globalDb) }
            ) {
                results.append(entry)
            }

            // Vector & Knowledge Graph DBs (.ckg/storage)
            let ckgRoot = (base as NSString).appendingPathComponent("globalStorage/.ckg/storage")
            if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: ckgRoot) {
                for dir in subdirs {
                    let dirPath = (ckgRoot as NSString).appendingPathComponent(dir)
                    if let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath) {
                        for file in files where file.hasSuffix(".db") {
                            let filePath = (dirPath as NSString).appendingPathComponent(file)
                            let cleanName = file.components(separatedBy: "_").first ?? file
                            if let entry = resolveDatabaseEntry(
                                id: filePath,
                                editor: .trae,
                                scope: .vectorCache,
                                filePath: filePath,
                                fileName: file,
                                storageDirectory: dirPath,
                                workspaceName: "\(cleanName) (Knowledge Cache)",
                                isOrphaned: false,
                                cache: cache
                            ) {
                                results.append(entry)
                            }
                        }
                    }
                }
            }

            // Workspaces
            let wsRoot = (base as NSString).appendingPathComponent("workspaceStorage")
            results += scanWorkspaceStorage(root: wsRoot, editor: .trae, cache: cache)
        }

        // Forensics baseline database if available (~428 MB)
        let forensicsRoot = (home as NSString).appendingPathComponent("trae-forensics/original-copies")
        if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: forensicsRoot) {
            for sub in subdirs {
                let db = (forensicsRoot as NSString).appendingPathComponent("\(sub)/database.db")
                if let entry = resolveDatabaseEntry(
                    id: db,
                    editor: .trae,
                    scope: .global,
                    filePath: db,
                    fileName: "database.db (Forensics Baseline)",
                    storageDirectory: (db as NSString).deletingLastPathComponent,
                    workspaceName: "Trae 基准归档数据库 (\(sub))",
                    isOrphaned: false,
                    cache: cache
                ) {
                    results.append(entry)
                }
            }
        }

        return results
    }

    // MARK: - Windsurf
    public static func scanWindsurf(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        let base = (home as NSString).appendingPathComponent("Library/Application Support/Windsurf/User")
        var results: [AgentDatabaseEntry] = []

        let globalDb = (base as NSString).appendingPathComponent("globalStorage/state.vscdb")
        if let entry = resolveDatabaseEntry(
            id: globalDb,
            editor: .windsurf,
            scope: .global,
            filePath: globalDb,
            fileName: "state.vscdb",
            storageDirectory: (globalDb as NSString).deletingLastPathComponent,
            workspaceName: "Windsurf Global Cascade",
            isOrphaned: false,
            customCount: AgentSQLiteReader.countItemTableRows(dbPath: globalDb),
            cache: cache
        ) {
            results.append(entry)
        }

        let wsRoot = (base as NSString).appendingPathComponent("workspaceStorage")
        results += scanWorkspaceStorage(root: wsRoot, editor: .windsurf, cache: cache)

        return results
    }

    // MARK: - VS Code
    public static func scanVSCode(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let variants = ["Code", "Code - Insiders"]

        for variant in variants {
            let base = (home as NSString).appendingPathComponent("Library/Application Support/\(variant)/User")

            // GitHub Copilot Chat Session Store DB
            let copilotDb = (base as NSString).appendingPathComponent("globalStorage/github.copilot-chat/session-store.db")
            if let entry = resolveDatabaseEntry(
                id: copilotDb,
                editor: .vscode,
                scope: .global,
                filePath: copilotDb,
                fileName: "session-store.db",
                storageDirectory: (copilotDb as NSString).deletingLastPathComponent,
                workspaceName: "Copilot Chat Sessions",
                isOrphaned: false,
                cache: cache,
                readConversations: { AgentSQLiteReader.readCopilotConversations(dbPath: copilotDb) }
            ) {
                results.append(entry)
            }

            // Global storage state.vscdb
            let globalDb = (base as NSString).appendingPathComponent("globalStorage/state.vscdb")
            if let entry = resolveDatabaseEntry(
                id: globalDb,
                editor: .vscode,
                scope: .global,
                filePath: globalDb,
                fileName: "state.vscdb",
                storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                workspaceName: "VS Code Global State",
                isOrphaned: false,
                cache: cache
            ) {
                results.append(entry)
            }

            // Workspaces
            let wsRoot = (base as NSString).appendingPathComponent("workspaceStorage")
            results += scanWorkspaceStorage(root: wsRoot, editor: .vscode, cache: cache)
        }

        return results
    }

    // MARK: - Antigravity
    public static func scanAntigravity(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let dbPath = (home as NSString).appendingPathComponent(".gemini/antigravity/conversation_summaries.db")
        if let entry = resolveDatabaseEntry(
            id: dbPath,
            editor: .antigravity,
            scope: .global,
            filePath: dbPath,
            fileName: "conversation_summaries.db",
            storageDirectory: (dbPath as NSString).deletingLastPathComponent,
            workspaceName: "Antigravity 对话汇总数据库",
            isOrphaned: false,
            cache: cache,
            readConversations: { AgentSQLiteReader.readAntigravityConversations(dbPath: dbPath) }
        ) {
            results.append(entry)
        }

        // Scan individual conversation databases in ~/.gemini/antigravity/conversations/*.db
        let convsDir = (home as NSString).appendingPathComponent(".gemini/antigravity/conversations")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: convsDir) {
            for file in files where file.hasSuffix(".db") {
                let fullPath = (convsDir as NSString).appendingPathComponent(file)
                let convId = (file as NSString).deletingPathExtension
                if let entry = resolveDatabaseEntry(
                    id: fullPath,
                    editor: .antigravity,
                    scope: .global,
                    filePath: fullPath,
                    fileName: file,
                    storageDirectory: convsDir,
                    workspaceName: "Antigravity 会话库 (\(convId.prefix(8)))",
                    isOrphaned: false,
                    customCount: 1,
                    cache: cache
                ) {
                    results.append(entry)
                }
            }
        }

        return results
    }

    // MARK: - Qoder / Qoder CN
    public static func scanQoder(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let variants = ["QoderCN", "Qoder"]

        for variant in variants {
            let base = (home as NSString).appendingPathComponent("Library/Application Support/\(variant)")

            // Main chat session SQLite local.db
            let localDb = (base as NSString).appendingPathComponent("SharedClientCache/cache/db/local.db")
            if let entry = resolveDatabaseEntry(
                id: localDb,
                editor: .qoder,
                scope: .global,
                filePath: localDb,
                fileName: "local.db",
                storageDirectory: (localDb as NSString).deletingLastPathComponent,
                workspaceName: "\(variant) Chat Sessions",
                isOrphaned: false,
                cache: cache,
                readConversations: { AgentSQLiteReader.readQoderConversations(dbPath: localDb) }
            ) {
                results.append(entry)
            }

            // Vector index DBs in index/vector/v5
            let vectorRoot = (base as NSString).appendingPathComponent("SharedClientCache/index/vector/v5")
            if let enumerator = FileManager.default.enumerator(atPath: vectorRoot) {
                while let item = enumerator.nextObject() as? String {
                    if item.hasSuffix(".db") {
                        let fullPath = (vectorRoot as NSString).appendingPathComponent(item)
                        let projName = item.components(separatedBy: "/").first ?? item
                        if let entry = resolveDatabaseEntry(
                            id: fullPath,
                            editor: .qoder,
                            scope: .vectorCache,
                            filePath: fullPath,
                            fileName: (item as NSString).lastPathComponent,
                            storageDirectory: (fullPath as NSString).deletingLastPathComponent,
                            workspaceName: "\(variant) 向量索引 (\(projName.prefix(20)))",
                            isOrphaned: false,
                            cache: cache
                        ) {
                            results.append(entry)
                        }
                    }
                }
            }

            // Meta index DBs in index/meta/v8
            let metaRoot = (base as NSString).appendingPathComponent("SharedClientCache/index/meta/v8")
            if let enumerator = FileManager.default.enumerator(atPath: metaRoot) {
                while let item = enumerator.nextObject() as? String {
                    if item.hasSuffix(".db") {
                        let fullPath = (metaRoot as NSString).appendingPathComponent(item)
                        if let entry = resolveDatabaseEntry(
                            id: fullPath,
                            editor: .qoder,
                            scope: .vectorCache,
                            filePath: fullPath,
                            fileName: (item as NSString).lastPathComponent,
                            storageDirectory: (fullPath as NSString).deletingLastPathComponent,
                            workspaceName: "\(variant) 元数据索引",
                            isOrphaned: false,
                            cache: cache
                        ) {
                            results.append(entry)
                        }
                    }
                }
            }

            // Knowledge DB
            let knowledgeDb = (base as NSString).appendingPathComponent("SharedClientCache/repowiki/knowledge.db")
            if let entry = resolveDatabaseEntry(
                id: knowledgeDb,
                editor: .qoder,
                scope: .vectorCache,
                filePath: knowledgeDb,
                fileName: "knowledge.db",
                storageDirectory: (knowledgeDb as NSString).deletingLastPathComponent,
                workspaceName: "\(variant) Knowledge Base",
                isOrphaned: false,
                cache: cache
            ) {
                results.append(entry)
            }

            // Global state.vscdb
            let globalDb = (base as NSString).appendingPathComponent("User/globalStorage/state.vscdb")
            if let entry = resolveDatabaseEntry(
                id: globalDb,
                editor: .qoder,
                scope: .global,
                filePath: globalDb,
                fileName: "state.vscdb",
                storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                workspaceName: "\(variant) Global Storage",
                isOrphaned: false,
                cache: cache
            ) {
                results.append(entry)
            }

            // Workspace storage
            let wsRoot = (base as NSString).appendingPathComponent("User/workspaceStorage")
            results += scanWorkspaceStorage(root: wsRoot, editor: .qoder, cache: cache)
        }

        // Main.sqlite in stable support dirs
        let appSupportDirs = [
            "Library/Application Support/com.qoder.app.stable",
            "Library/Application Support/com.qodercn.app.stable"
        ]
        for rel in appSupportDirs {
            let fullPath = (home as NSString).appendingPathComponent("\(rel)/main.sqlite")
            if let entry = resolveDatabaseEntry(
                id: fullPath,
                editor: .qoder,
                scope: .global,
                filePath: fullPath,
                fileName: "main.sqlite",
                storageDirectory: (fullPath as NSString).deletingLastPathComponent,
                workspaceName: "\((rel as NSString).lastPathComponent) 主数据库",
                isOrphaned: false,
                cache: cache
            ) {
                results.append(entry)
            }
        }

        return results
    }

    // MARK: - Cherry Studio
    public static func scanCherryStudio(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let candidates = [
            "Library/Application Support/CherryStudio/Data/agents.db",
            "Library/Application Support/Cherry Studio/Data/agents.db",
            "Library/Application Support/CherryStudio/agents.db"
        ]

        for rel in candidates {
            let dbPath = (home as NSString).appendingPathComponent(rel)
            if let entry = resolveDatabaseEntry(
                id: dbPath,
                editor: .cherryStudio,
                scope: .global,
                filePath: dbPath,
                fileName: "agents.db",
                storageDirectory: (dbPath as NSString).deletingLastPathComponent,
                workspaceName: "Cherry Studio Agent Sessions",
                isOrphaned: false,
                cache: cache,
                readConversations: { AgentSQLiteReader.readCherryStudioConversations(dbPath: dbPath) }
            ) {
                results.append(entry)
                break
            }
        }

        return results
    }

    // MARK: - CodeBuddy
    public static func scanCodeBuddy(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        let base = (home as NSString).appendingPathComponent("Library/Application Support/CodeBuddy CN")
        var results: [AgentDatabaseEntry] = []

        // Dedicated session database
        let sessionDb = (base as NSString).appendingPathComponent("codebuddy-sessions.vscdb")
        if let entry = resolveDatabaseEntry(
            id: sessionDb,
            editor: .codeBuddy,
            scope: .global,
            filePath: sessionDb,
            fileName: "codebuddy-sessions.vscdb",
            storageDirectory: base,
            workspaceName: "CodeBuddy Session Store",
            isOrphaned: false,
            cache: cache,
            readConversations: { AgentSQLiteReader.readCodeBuddyConversations(dbPath: sessionDb) }
        ) {
            results.append(entry)
        }

        // Global storage
        let globalDb = (base as NSString).appendingPathComponent("User/globalStorage/state.vscdb")
        if let entry = resolveDatabaseEntry(
            id: globalDb,
            editor: .codeBuddy,
            scope: .global,
            filePath: globalDb,
            fileName: "state.vscdb",
            storageDirectory: (globalDb as NSString).deletingLastPathComponent,
            workspaceName: "CodeBuddy Global Storage",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }

        let wsRoot = (base as NSString).appendingPathComponent("User/workspaceStorage")
        results += scanWorkspaceStorage(root: wsRoot, editor: .codeBuddy, cache: cache)

        return results
    }

    // MARK: - Kiro
    public static func scanKiro(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        let base = (home as NSString).appendingPathComponent("Library/Application Support/Kiro/User")
        var results: [AgentDatabaseEntry] = []

        let globalDb = (base as NSString).appendingPathComponent("globalStorage/state.vscdb")
        if let entry = resolveDatabaseEntry(
            id: globalDb,
            editor: .kiro,
            scope: .global,
            filePath: globalDb,
            fileName: "state.vscdb",
            storageDirectory: (globalDb as NSString).deletingLastPathComponent,
            workspaceName: "Kiro Global Storage",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }

        let wsRoot = (base as NSString).appendingPathComponent("workspaceStorage")
        results += scanWorkspaceStorage(root: wsRoot, editor: .kiro, cache: cache)

        return results
    }

    // MARK: - Claude Code
    public static func scanClaudeCode(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let historyPath = (home as NSString).appendingPathComponent(".claude/history.jsonl")

        if let entry = resolveDatabaseEntry(
            id: historyPath,
            editor: .claudeCode,
            scope: .global,
            filePath: historyPath,
            fileName: "history.jsonl",
            storageDirectory: (historyPath as NSString).deletingLastPathComponent,
            workspaceName: "Claude Code CLI History",
            isOrphaned: false,
            cache: cache,
            readConversations: { parseClaudeHistory(path: historyPath) }
        ) {
            results.append(entry)
        }

        return results
    }

    // MARK: - OpenCode
    public static func scanOpenCode(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. Primary conversation database in ~/.local/share/opencode/opencode.db (~5.5 GB)
        let mainDb = (home as NSString).appendingPathComponent(".local/share/opencode/opencode.db")
        if let entry = resolveDatabaseEntry(
            id: mainDb,
            editor: .openCode,
            scope: .global,
            filePath: mainDb,
            fileName: "opencode.db",
            storageDirectory: (mainDb as NSString).deletingLastPathComponent,
            workspaceName: "OpenCode 核心会话数据库",
            isOrphaned: false,
            cache: cache,
            readConversations: { AgentSQLiteReader.readOpenCodeSessions(dbPath: mainDb) }
        ) {
            results.append(entry)
        }

        // 2. Auxiliary drafts database in Library/Application Support/ai.opencode.desktop
        let base = (home as NSString).appendingPathComponent("Library/Application Support/ai.opencode.desktop")
        let draftsDb = (base as NSString).appendingPathComponent("drafts.sqlite")
        if let entry = resolveDatabaseEntry(
            id: draftsDb,
            editor: .openCode,
            scope: .global,
            filePath: draftsDb,
            fileName: "drafts.sqlite",
            storageDirectory: base,
            workspaceName: "OpenCode 草稿与临时存储",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }

        return results
    }

    // MARK: - Zed
    public static func scanZed(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let dbDir = (home as NSString).appendingPathComponent("Library/Application Support/Zed/db")
        if let enumerator = FileManager.default.enumerator(atPath: dbDir) {
            while let file = enumerator.nextObject() as? String {
                if file.hasSuffix(".sqlite") || file.hasSuffix(".db") {
                    let fullPath = (dbDir as NSString).appendingPathComponent(file)
                    if let entry = resolveDatabaseEntry(
                        id: fullPath,
                        editor: .zed,
                        scope: .global,
                        filePath: fullPath,
                        fileName: (file as NSString).lastPathComponent,
                        storageDirectory: (fullPath as NSString).deletingLastPathComponent,
                        workspaceName: "Zed Database (\((file as NSString).lastPathComponent))",
                        isOrphaned: false,
                        cache: cache
                    ) {
                        results.append(entry)
                    }
                }
            }
        }
        return results
    }

    // MARK: - WorkBuddy
    public static func scanWorkBuddy(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. ~/.workbuddy and ~/.workbuddy-ai
        let homeDirs = [
            (home as NSString).appendingPathComponent(".workbuddy"),
            (home as NSString).appendingPathComponent(".workbuddy-ai")
        ]
        for dir in homeDirs {
            let isAI = dir.contains("-ai")
            let prefix = isAI ? "WorkBuddy AI" : "WorkBuddy"

            // Main workbuddy.db
            let mainDb = (dir as NSString).appendingPathComponent("workbuddy.db")
            if let entry = resolveDatabaseEntry(
                id: mainDb,
                editor: .workBuddy,
                scope: .global,
                filePath: mainDb,
                fileName: "workbuddy.db",
                storageDirectory: dir,
                workspaceName: "\(prefix) 核心数据库",
                isOrphaned: false,
                cache: cache
            ) {
                results.append(entry)
            }

            // Threat database
            let threatDir = (dir as NSString).appendingPathComponent("security/threat-database")
            if let files = try? FileManager.default.contentsOfDirectory(atPath: threatDir) {
                for file in files where file.hasSuffix(".db") {
                    let fullPath = (threatDir as NSString).appendingPathComponent(file)
                    if let entry = resolveDatabaseEntry(
                        id: fullPath,
                        editor: .workBuddy,
                        scope: .global,
                        filePath: fullPath,
                        fileName: file,
                        storageDirectory: threatDir,
                        workspaceName: "\(prefix) 安全与威胁数据库",
                        isOrphaned: false,
                        cache: cache
                    ) {
                        results.append(entry)
                    }
                }
            }
        }

        // 2. Library/Application Support dirs
        let dirs = [
            "Library/Application Support/com.tencent.workbuddy.mac",
            "Library/Application Support/WorkBuddy AI",
            "Library/Application Support/WorkBuddy"
        ]
        for rel in dirs {
            let fullDir = (home as NSString).appendingPathComponent(rel)
            if let files = try? FileManager.default.contentsOfDirectory(atPath: fullDir) {
                for file in files where file.hasSuffix(".db") || file.hasSuffix(".sqlite") || file.hasSuffix(".vscdb") {
                    let filePath = (fullDir as NSString).appendingPathComponent(file)
                    if let entry = resolveDatabaseEntry(
                        id: filePath,
                        editor: .workBuddy,
                        scope: .global,
                        filePath: filePath,
                        fileName: file,
                        storageDirectory: fullDir,
                        workspaceName: "WorkBuddy Data (\(file))",
                        isOrphaned: false,
                        cache: cache
                    ) {
                        results.append(entry)
                    }
                }
            }
        }
        return results
    }

    // MARK: - MiniMax
    public static func scanMiniMax(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. MiniMax Code runtime opencode.db (~3.7 GB)
        let hiloDb = (home as NSString).appendingPathComponent("Library/Application Support/@hilo/MiniMax Hub Global/ai-runtime/data-home/opencode/opencode.db")
        if let entry = resolveDatabaseEntry(
            id: hiloDb,
            editor: .miniMax,
            scope: .global,
            filePath: hiloDb,
            fileName: "opencode.db (MiniMax Runtime)",
            storageDirectory: (hiloDb as NSString).deletingLastPathComponent,
            workspaceName: "MiniMax Code 核心对话数据库",
            isOrphaned: false,
            cache: cache,
            readConversations: { AgentSQLiteReader.readOpenCodeSessions(dbPath: hiloDb) }
        ) {
            results.append(entry)
        }

        // 2. ~/.minimax/v2/sqlite/runtime-state.sqlite (+ WAL ~5.5 MB)
        let minimaxSqliteDir = (home as NSString).appendingPathComponent(".minimax/v2/sqlite")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: minimaxSqliteDir) {
            for file in files where file.hasSuffix(".sqlite") || file.hasSuffix(".db") {
                let fullPath = (minimaxSqliteDir as NSString).appendingPathComponent(file)
                if let entry = resolveDatabaseEntry(
                    id: fullPath,
                    editor: .miniMax,
                    scope: .global,
                    filePath: fullPath,
                    fileName: file,
                    storageDirectory: minimaxSqliteDir,
                    workspaceName: "MiniMax 运行时状态数据库",
                    isOrphaned: false,
                    cache: cache
                ) {
                    results.append(entry)
                }
            }
        }

        // 3. MiniMax Agent / Support dirs
        let dirs = [
            "Library/Application Support/MiniMax Agent",
            "Library/Application Support/MiniMax"
        ]
        for rel in dirs {
            let fullDir = (home as NSString).appendingPathComponent(rel)
            let sharedDb = (fullDir as NSString).appendingPathComponent("Shared Dictionary/db")
            if let entry = resolveDatabaseEntry(
                id: sharedDb,
                editor: .miniMax,
                scope: .global,
                filePath: sharedDb,
                fileName: "Shared Dictionary db",
                storageDirectory: (sharedDb as NSString).deletingLastPathComponent,
                workspaceName: "\((rel as NSString).lastPathComponent) 缓存数据库",
                isOrphaned: false,
                cache: cache
            ) {
                results.append(entry)
            }
        }
        return results
    }

    // MARK: - ZCode
    public static func scanZCode(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. ~/.zcode/cli/db/db.sqlite (4.8 MB)
        let cliDb = (home as NSString).appendingPathComponent(".zcode/cli/db/db.sqlite")
        if let entry = resolveDatabaseEntry(
            id: cliDb,
            editor: .zCode,
            scope: .global,
            filePath: cliDb,
            fileName: "db.sqlite",
            storageDirectory: (cliDb as NSString).deletingLastPathComponent,
            workspaceName: "ZCode CLI 核心数据库",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }

        // 2. ~/.zcode/v2/tasks-index.sqlite (296 KB)
        let taskDb = (home as NSString).appendingPathComponent(".zcode/v2/tasks-index.sqlite")
        if let entry = resolveDatabaseEntry(
            id: taskDb,
            editor: .zCode,
            scope: .global,
            filePath: taskDb,
            fileName: "tasks-index.sqlite",
            storageDirectory: (taskDb as NSString).deletingLastPathComponent,
            workspaceName: "ZCode 任务索引库",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }

        // 3. Library/Application Support/ZCode/session
        let base = (home as NSString).appendingPathComponent("Library/Application Support/ZCode/session")
        if let enumerator = FileManager.default.enumerator(atPath: base) {
            while let file = enumerator.nextObject() as? String {
                if file.hasSuffix(".db") || file.hasSuffix(".sqlite") || file == "SharedStorage" {
                    let fullPath = (base as NSString).appendingPathComponent(file)
                    if let entry = resolveDatabaseEntry(
                        id: fullPath,
                        editor: .zCode,
                        scope: .global,
                        filePath: fullPath,
                        fileName: (file as NSString).lastPathComponent,
                        storageDirectory: (fullPath as NSString).deletingLastPathComponent,
                        workspaceName: "ZCode Session Storage",
                        isOrphaned: false,
                        cache: cache
                    ) {
                        results.append(entry)
                    }
                }
            }
        }
        return results
    }

    // MARK: - Continue
    public static func scanContinue(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let idxPath = (home as NSString).appendingPathComponent(".continue/index/index.sqlite")
        if let entry = resolveDatabaseEntry(
            id: idxPath,
            editor: .continueExt,
            scope: .global,
            filePath: idxPath,
            fileName: "index.sqlite",
            storageDirectory: (idxPath as NSString).deletingLastPathComponent,
            workspaceName: "Continue Index Database",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }
        return results
    }

    // MARK: - Aider
    public static func scanAider(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let histPath = (home as NSString).appendingPathComponent(".aider.chat.history.md")
        if let entry = resolveDatabaseEntry(
            id: histPath,
            editor: .aider,
            scope: .global,
            filePath: histPath,
            fileName: ".aider.chat.history.md",
            storageDirectory: home,
            workspaceName: "Aider Conversation History",
            isOrphaned: false,
            cache: cache,
            readConversations: {
                let mtime = (try? FileManager.default.attributesOfItem(atPath: histPath))?[.modificationDate] as? Date
                return [
                    AgentConversationSummary(
                        id: histPath,
                        title: "Aider CLI Chat History",
                        createdAt: mtime,
                        mode: "aider"
                    )
                ]
            }
        ) {
            results.append(entry)
        }
        return results
    }

    // MARK: - Doubao
    public static func scanDoubao(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let base = (home as NSString).appendingPathComponent("Library/Application Support/Doubao")
        let sessionsDir = (base as NSString).appendingPathComponent("Default/.doubao/agent_mode/workspace/.sessions")
        if let sessionIds = try? FileManager.default.contentsOfDirectory(atPath: sessionsDir) {
            var convSummaries: [AgentConversationSummary] = []
            var totalSessionBytes: UInt64 = 0
            var latestDate = Date.distantPast

            for sid in sessionIds where !sid.hasPrefix(".") {
                let sPath = (sessionsDir as NSString).appendingPathComponent(sid)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: sPath, isDirectory: &isDir), isDir.boolValue {
                    let attrs = (try? FileManager.default.attributesOfItem(atPath: sPath)) ?? [:]
                    let mtime = (attrs[.modificationDate] as? Date) ?? Date()
                    if mtime > latestDate { latestDate = mtime }

                    var sessionSize: UInt64 = 0
                    if let enumr = FileManager.default.enumerator(atPath: sPath) {
                        while let item = enumr.nextObject() as? String {
                            let p = (sPath as NSString).appendingPathComponent(item)
                            if let a = try? FileManager.default.attributesOfItem(atPath: p), let s = a[.size] as? UInt64 {
                                sessionSize += s
                            }
                        }
                    }
                    totalSessionBytes += sessionSize

                    var title = "豆包 Agent 会话 \(sid.prefix(8))"
                    let boardPath = (sPath as NSString).appendingPathComponent("board.md")
                    if let boardContent = try? String(contentsOfFile: boardPath, encoding: .utf8) {
                        let lines = boardContent.components(separatedBy: .newlines)
                        if let first = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                            title = String(first.prefix(60)).replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                        }
                    }

                    convSummaries.append(AgentConversationSummary(
                        id: sid,
                        title: title,
                        createdAt: mtime,
                        updatedAt: mtime,
                        mode: "agent_mode"
                    ))
                }
            }

            if !convSummaries.isEmpty {
                results.append(AgentDatabaseEntry(
                    id: sessionsDir,
                    editor: .doubao,
                    scope: .workspace,
                    filePath: sessionsDir,
                    fileName: ".sessions",
                    storageDirectory: (sessionsDir as NSString).deletingLastPathComponent,
                    fileSizeBytes: max(totalSessionBytes, 1024),
                    lastModified: latestDate == Date.distantPast ? Date() : latestDate,
                    workspacePath: nil,
                    workspaceName: "豆包智能体 会话工作区",
                    isOrphaned: false,
                    conversationCount: convSummaries.count,
                    conversations: convSummaries
                ))
            }
        }

        let dbPaths = [
            (base as NSString).appendingPathComponent("gecko_cache/gecko2.db"),
            (base as NSString).appendingPathComponent("first_party_sets.db")
        ]
        for p in dbPaths {
            if let entry = resolveDatabaseEntry(
                id: p,
                editor: .doubao,
                scope: .global,
                filePath: p,
                fileName: (p as NSString).lastPathComponent,
                storageDirectory: (p as NSString).deletingLastPathComponent,
                workspaceName: "豆包缓存 (\((p as NSString).lastPathComponent))",
                isOrphaned: false,
                cache: cache
            ) {
                results.append(entry)
            }
        }
        return results
    }

    // MARK: - ChatGPT & Codex
    public static func scanChatGPT(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. Scan ~/.codex and ~/.codex/sqlite for large databases
        let codexDirs = [
            (home as NSString).appendingPathComponent(".codex"),
            (home as NSString).appendingPathComponent(".codex/sqlite")
        ]
        for dir in codexDirs {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for file in files where file.hasSuffix(".sqlite") || file.hasSuffix(".db") {
                    let fullPath = (dir as NSString).appendingPathComponent(file)
                    let label: String
                    if file.contains("thread_history") {
                        label = "Codex 线程历史数据库"
                    } else if file.contains("logs") {
                        label = "Codex 会话与调用日志库"
                    } else if file.contains("state") {
                        label = "Codex 运行时状态库"
                    } else {
                        label = "Codex 数据库 (\(file))"
                    }
                    if let entry = resolveDatabaseEntry(
                        id: fullPath,
                        editor: .chatgpt,
                        scope: .global,
                        filePath: fullPath,
                        fileName: file,
                        storageDirectory: dir,
                        workspaceName: label,
                        isOrphaned: false,
                        cache: cache
                    ) {
                        results.append(entry)
                    }
                }
            }
        }

        // 2. Fallbacks for Analytics.db and Codex support dirs
        let candidatePaths = [
            (home as NSString).appendingPathComponent("Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Application Support/Software/Analytics.db")
        ]
        for path in candidatePaths {
            if let entry = resolveDatabaseEntry(
                id: path,
                editor: .chatgpt,
                scope: .global,
                filePath: path,
                fileName: (path as NSString).lastPathComponent,
                storageDirectory: (path as NSString).deletingLastPathComponent,
                workspaceName: "ChatGPT/Codex 服务数据库",
                isOrphaned: false,
                cache: cache
            ) {
                results.append(entry)
            }
        }
        return results
    }

    // MARK: - Tencent Marvis
    public static func scanMarvis(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. ~/.marvis/database/*.db
        let dotMarvis = (home as NSString).appendingPathComponent(".marvis/database")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: dotMarvis) {
            for file in files where file.hasSuffix(".db") {
                let full = (dotMarvis as NSString).appendingPathComponent(file)
                let isVector = file.contains("vector")
                if let entry = resolveDatabaseEntry(
                    id: full,
                    editor: .marvis,
                    scope: isVector ? .vectorCache : .global,
                    filePath: full,
                    fileName: file,
                    storageDirectory: dotMarvis,
                    workspaceName: "Marvis 数据库 (\(file))",
                    isOrphaned: false,
                    cache: cache
                ) {
                    results.append(entry)
                }
            }
        }

        // 2. Library/Application Support/com.tencent.mac.marvis
        let base = (home as NSString).appendingPathComponent("Library/Application Support/com.tencent.mac.marvis")

        // 1. User conversation database (data.db) & vector databases
        let userBase = (base as NSString).appendingPathComponent("MarvisData/User")
        if let userDirs = try? FileManager.default.contentsOfDirectory(atPath: userBase) {
            for u in userDirs where !u.hasPrefix(".") {
                let dbDir = (userBase as NSString).appendingPathComponent("\(u)/database")
                let dataDb = (dbDir as NSString).appendingPathComponent("data.db")
                if let entry = resolveDatabaseEntry(
                    id: dataDb,
                    editor: .marvis,
                    scope: .global,
                    filePath: dataDb,
                    fileName: "data.db",
                    storageDirectory: dbDir,
                    workspaceName: "腾讯云 Marvis 会话库 (\(u.prefix(8)))",
                    isOrphaned: false,
                    cache: cache,
                    readConversations: { AgentSQLiteReader.readMarvisConversations(dbPath: dataDb) }
                ) {
                    results.append(entry)
                }

                // Check vector index DBs
                let vectorDbs = ["tool_index_vector.db", "memory_vector.db", "memory.db", "business.db"]
                for v in vectorDbs {
                    let vPath = (dbDir as NSString).appendingPathComponent(v)
                    if let entry = resolveDatabaseEntry(
                        id: vPath,
                        editor: .marvis,
                        scope: .vectorCache,
                        filePath: vPath,
                        fileName: v,
                        storageDirectory: dbDir,
                        workspaceName: "腾讯云 Marvis (\(v))",
                        isOrphaned: false,
                        cache: cache
                    ) {
                        results.append(entry)
                    }
                }
            }
        }

        // 2. Knowledgebase DBs
        let kbDir = (base as NSString).appendingPathComponent("Knowledgebase/storage/database")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: kbDir) {
            for file in files where file.hasSuffix(".db") {
                let full = (kbDir as NSString).appendingPathComponent(file)
                if let entry = resolveDatabaseEntry(
                    id: full,
                    editor: .marvis,
                    scope: .vectorCache,
                    filePath: full,
                    fileName: file,
                    storageDirectory: kbDir,
                    workspaceName: "腾讯云 Marvis 知识库 (\(file))",
                    isOrphaned: false,
                    cache: cache
                ) {
                    results.append(entry)
                }
            }
        }

        // 3. Local app info
        let legacyDbDir = (base as NSString).appendingPathComponent("db")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: legacyDbDir) {
            for file in files where file.hasSuffix(".db") || file.hasSuffix(".sqlite") {
                let full = (legacyDbDir as NSString).appendingPathComponent(file)
                if let entry = resolveDatabaseEntry(
                    id: full,
                    editor: .marvis,
                    scope: .global,
                    filePath: full,
                    fileName: file,
                    storageDirectory: legacyDbDir,
                    workspaceName: "腾讯云 Marvis (\(file))",
                    isOrphaned: false,
                    cache: cache
                ) {
                    results.append(entry)
                }
            }
        }
        return results
    }

    // MARK: - WeChat DevTools
    public static func scanWeChatDevTools(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let base = (home as NSString).appendingPathComponent("Library/Application Support/微信开发者工具")
        guard let subdirs = try? FileManager.default.contentsOfDirectory(atPath: base) else { return [] }
        for sub in subdirs {
            let userDir = (base as NSString).appendingPathComponent("\(sub)/Default/Editor/1.78/user-data/User")
            let globalDb = (userDir as NSString).appendingPathComponent("globalStorage/state.vscdb")
            if let entry = resolveDatabaseEntry(
                id: globalDb,
                editor: .wechatDevTools,
                scope: .global,
                filePath: globalDb,
                fileName: "state.vscdb",
                storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                workspaceName: "微信开发者工具 全局状态",
                isOrphaned: false,
                cache: cache
            ) {
                results.append(entry)
            }

            let wsRoot = (userDir as NSString).appendingPathComponent("workspaceStorage")
            results += scanWorkspaceStorage(root: wsRoot, editor: .wechatDevTools, cache: cache)
        }
        return results
    }

    // MARK: - HBuilder X
    public static func scanHBuilder(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let base = (home as NSString).appendingPathComponent("Library/Application Support/HBuilder X")
        let idxDir = (base as NSString).appendingPathComponent("newIndexDb")
        if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: idxDir) {
            for sub in subdirs where !sub.hasPrefix(".") {
                let subPath = (idxDir as NSString).appendingPathComponent(sub)
                var totalSize: UInt64 = 0
                var latestDate = Date.distantPast
                if let files = try? FileManager.default.contentsOfDirectory(atPath: subPath) {
                    for file in files {
                        let fp = (subPath as NSString).appendingPathComponent(file)
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: fp),
                           let size = attrs[.size] as? UInt64,
                           let mtime = attrs[.modificationDate] as? Date {
                            totalSize += size
                            if mtime > latestDate { latestDate = mtime }
                        }
                    }
                }
                if totalSize > 0 {
                    results.append(AgentDatabaseEntry(
                        id: subPath,
                        editor: .hbuilder,
                        scope: .workspace,
                        filePath: subPath,
                        fileName: sub,
                        storageDirectory: idxDir,
                        fileSizeBytes: totalSize,
                        lastModified: latestDate == Date.distantPast ? Date() : latestDate,
                        workspacePath: nil,
                        workspaceName: "HBuilder X 索引库 (\(sub.prefix(8)))",
                        isOrphaned: false,
                        conversationCount: 0,
                        conversations: []
                    ))
                }
            }
        }
        return results
    }

    // MARK: - DeepSeek
    public static func scanDeepSeek(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let dbPath = (home as NSString).appendingPathComponent("Library/Application Support/@deepseek-ai/dsh-desktop/declarative_performance_observer.db")
        if let entry = resolveDatabaseEntry(
            id: dbPath,
            editor: .deepseek,
            scope: .global,
            filePath: dbPath,
            fileName: "declarative_performance_observer.db",
            storageDirectory: (dbPath as NSString).deletingLastPathComponent,
            workspaceName: "DeepSeek 桌面端持久化库",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }
        return results
    }

    // MARK: - AutoClaw
    public static func scanAutoClaw(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. ~/.openclaw-autoclaw/state/openclaw.sqlite (~936 KB)
        let mainDb = (home as NSString).appendingPathComponent(".openclaw-autoclaw/state/openclaw.sqlite")
        if let entry = resolveDatabaseEntry(
            id: mainDb,
            editor: .autoClaw,
            scope: .global,
            filePath: mainDb,
            fileName: "openclaw.sqlite",
            storageDirectory: (mainDb as NSString).deletingLastPathComponent,
            workspaceName: "AutoClaw 核心状态数据库",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }

        // 2. Library/Application Support/autoclaw/log_sdk_v2.db
        let logDb = (home as NSString).appendingPathComponent("Library/Application Support/autoclaw/log_sdk_v2.db")
        if let entry = resolveDatabaseEntry(
            id: logDb,
            editor: .autoClaw,
            scope: .global,
            filePath: logDb,
            fileName: "log_sdk_v2.db",
            storageDirectory: (logDb as NSString).deletingLastPathComponent,
            workspaceName: "AutoClaw SDK 日志库",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }
        return results
    }

    // MARK: - CC Switch
    public static func scanCCSwitch(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. ~/.cc-switch/cc-switch.db (17.75 MB)
        let mainDb = (home as NSString).appendingPathComponent(".cc-switch/cc-switch.db")
        if let entry = resolveDatabaseEntry(
            id: mainDb,
            editor: .ccSwitch,
            scope: .global,
            filePath: mainDb,
            fileName: "cc-switch.db",
            storageDirectory: (mainDb as NSString).deletingLastPathComponent,
            workspaceName: "CC Switch 核心配置数据库",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }

        // 2. ~/.cc-switch/backups/*.db (backups ~17.5 MB each)
        let backupDir = (home as NSString).appendingPathComponent(".cc-switch/backups")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: backupDir) {
            for file in files where file.hasSuffix(".db") {
                let full = (backupDir as NSString).appendingPathComponent(file)
                if let entry = resolveDatabaseEntry(
                    id: full,
                    editor: .ccSwitch,
                    scope: .global,
                    filePath: full,
                    fileName: file,
                    storageDirectory: backupDir,
                    workspaceName: "CC Switch 历史备份 (\(file))",
                    isOrphaned: false,
                    cache: cache
                ) {
                    results.append(entry)
                }
            }
        }
        return results
    }

    // MARK: - YDevSphere
    public static func scanYDevSphere(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let mainDb = (home as NSString).appendingPathComponent(".ydevsphere/database.sqlite")
        if let entry = resolveDatabaseEntry(
            id: mainDb,
            editor: .yDevSphere,
            scope: .global,
            filePath: mainDb,
            fileName: "database.sqlite",
            storageDirectory: (mainDb as NSString).deletingLastPathComponent,
            workspaceName: "YDevSphere 核心数据库",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }
        return results
    }

    // MARK: - Devin
    public static func scanDevin(home: String, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let stateDb = (home as NSString).appendingPathComponent(".devin-shared/sharedStorage/state.vscdb")
        if let entry = resolveDatabaseEntry(
            id: stateDb,
            editor: .devin,
            scope: .global,
            filePath: stateDb,
            fileName: "state.vscdb",
            storageDirectory: (stateDb as NSString).deletingLastPathComponent,
            workspaceName: "Devin 全局共享状态数据库",
            isOrphaned: false,
            cache: cache
        ) {
            results.append(entry)
        }
        return results
    }

    // MARK: - Helper: WorkspaceStorage Scanner
    static func scanWorkspaceStorage(root: String, editor: AgentEditorKind, cache: [String: AgentDatabaseEntry] = [:]) -> [AgentDatabaseEntry] {
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }
        var list: [AgentDatabaseEntry] = []

        for dir in dirs {
            let dirPath = (root as NSString).appendingPathComponent(dir)
            let dbPath = (dirPath as NSString).appendingPathComponent("state.vscdb")

            guard FileManager.default.fileExists(atPath: dbPath) else { continue }
            let wsInfo = parseWorkspaceJson(dirPath: dirPath)

            if let entry = resolveDatabaseEntry(
                id: dbPath,
                editor: editor,
                scope: .workspace,
                filePath: dbPath,
                fileName: "state.vscdb",
                storageDirectory: dirPath,
                workspacePath: wsInfo.path,
                workspaceName: wsInfo.name,
                isOrphaned: wsInfo.isOrphaned,
                cache: cache,
                readConversations: {
                    AgentSQLiteReader.readConversations(for: editor, dbPath: dbPath)
                }
            ) {
                list.append(entry)
            }
        }

        return list
    }

    // MARK: - Helper: Parse workspace.json
    public static func parseWorkspaceJson(dirPath: String) -> (path: String?, name: String, isOrphaned: Bool) {
        let jsonPath = (dirPath as NSString).appendingPathComponent("workspace.json")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, (dirPath as NSString).lastPathComponent, false)
        }

        let rawUri = (json["folder"] as? String) ?? (json["workspace"] as? String) ?? (json["configuration"] as? String)
        guard let rawUri else {
            return (nil, (dirPath as NSString).lastPathComponent, false)
        }

        var decodedPath: String?
        if let url = URL(string: rawUri), url.scheme == "file" {
            decodedPath = url.path
        } else if let unescaped = rawUri.removingPercentEncoding {
            decodedPath = unescaped.replacingOccurrences(of: "file://", with: "")
        }

        guard let path = decodedPath, !path.isEmpty else {
            return (nil, (dirPath as NSString).lastPathComponent, false)
        }

        let isOrphaned = !FileManager.default.fileExists(atPath: path)
        let name = (path as NSString).lastPathComponent
        return (path, name.isEmpty ? (dirPath as NSString).lastPathComponent : name, isOrphaned)
    }

    // MARK: - Helper: Parse Claude history
    private static func parseClaudeHistory(path: String) -> [AgentConversationSummary] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        var list: [AgentConversationSummary] = []
        var seenSessions: Set<String> = []

        let lines = content.components(separatedBy: .newlines)
        for line in lines.reversed() {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let sId = (json["sessionId"] as? String) ?? UUID().uuidString
            if seenSessions.contains(sId) { continue }
            seenSessions.insert(sId)

            let prompt = (json["display"] as? String) ?? "Prompt"
            let project = json["project"] as? String
            let ts = (json["timestamp"] as? NSNumber)?.int64Value ?? 0
            let date = ts > 0 ? Date(timeIntervalSince1970: Double(ts) / 1000.0) : nil

            list.append(AgentConversationSummary(
                id: sId,
                title: String(prompt.prefix(60)).replacingOccurrences(of: "\n", with: " "),
                createdAt: date,
                mode: "claude",
                snippet: project
            ))

            if list.count >= 50 { break }
        }

        return list
    }
}
