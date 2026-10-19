import Foundation
import PharosCore
import SQLite3

func testAgentEditorKinds() {
    expect(AgentEditorKind.allCases.count >= 20, "all agent editors registered (found \(AgentEditorKind.allCases.count))")
    expectEq(AgentEditorKind.cursor.displayName, "Cursor", "cursor name")
    expectEq(AgentEditorKind.trae.displayName, "Trae", "trae name")
    expectEq(AgentEditorKind.vscode.displayName, "VS Code", "vscode name")
    expectEq(AgentEditorKind.antigravity.displayName, "Antigravity", "antigravity name")
    expectEq(AgentEditorKind.qoder.displayName, "Qoder", "qoder name")
    expectEq(AgentEditorKind.cherryStudio.displayName, "Cherry Studio", "cherry studio name")
    expectEq(AgentEditorKind.codeBuddy.displayName, "CodeBuddy", "codebuddy name")
    expectEq(AgentEditorKind.kiro.displayName, "Kiro", "kiro name")
    expectEq(AgentEditorKind.doubao.displayName, "豆包 (Doubao)", "doubao name")
    expectEq(AgentEditorKind.chatgpt.displayName, "ChatGPT / Codex", "chatgpt name")
    expectEq(AgentEditorKind.marvis.displayName, "Marvis AI", "marvis name")
    expectEq(AgentEditorKind.wechatDevTools.displayName, "微信开发者工具", "wechat devtools name")
    expectEq(AgentEditorKind.hbuilder.displayName, "HBuilderX", "hbuilder name")
    expectEq(AgentEditorKind.deepseek.displayName, "DeepSeek", "deepseek name")
    expectEq(AgentEditorKind.autoClaw.displayName, "AutoClaw", "autoclaw name")
    expectEq(AgentEditorKind.ccSwitch.displayName, "CC Switch", "ccSwitch name")
    expectEq(AgentEditorKind.yDevSphere.displayName, "YDevSphere", "ydevsphere name")
    expectEq(AgentEditorKind.devin.displayName, "Devin", "devin name")

    for ed in AgentEditorKind.allCases {
        let paths = ed.knownStoragePaths(home: "/Users/test")
        expect(!paths.isEmpty, "\(ed.rawValue) has known storage paths")
        if !ed.appNames.isEmpty {
            expect(!ed.bundleIdentifiers.isEmpty, "\(ed.rawValue) has bundle identifiers")
        }
    }
}

func testSyntheticSQLiteReaders() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-synthetic-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    // 1. Antigravity test
    let agPath = tmp.appendingPathComponent("conversation_summaries.db").path
    var agDb: OpaquePointer?
    if sqlite3_open(agPath, &agDb) == SQLITE_OK {
        sqlite3_exec(agDb, "CREATE TABLE conversation_summaries (conversation_id TEXT, title TEXT, preview TEXT, step_count INT, last_modified_time TEXT, workspace_uris TEXT);", nil, nil, nil)
        sqlite3_exec(agDb, "INSERT INTO conversation_summaries VALUES ('ag-1', 'Build Antigravity App', 'Preview text', 10, '2026-03-01T12:00:00Z', 'file:///Users/test/workspace');", nil, nil, nil)
        sqlite3_close(agDb)

        let convs = AgentSQLiteReader.readAntigravityConversations(dbPath: agPath)
        expectEq(convs.count, 1, "Antigravity parsed 1 session")
        expectEq(convs.first?.id, "ag-1", "Antigravity id match")
        expectEq(convs.first?.title, "Build Antigravity App", "Antigravity title match")
        expectEq(convs.first?.messageCount, 10, "Antigravity step count match")
    }

    // 2. Qoder test
    let qdPath = tmp.appendingPathComponent("qoder_local.db").path
    var qdDb: OpaquePointer?
    if sqlite3_open(qdPath, &qdDb) == SQLITE_OK {
        sqlite3_exec(qdDb, "CREATE TABLE chat_session (session_id TEXT, session_title TEXT, project_name TEXT, mode TEXT, gmt_create INT, gmt_modified INT);", nil, nil, nil)
        sqlite3_exec(qdDb, "INSERT INTO chat_session VALUES ('qd-1', 'Fix Navbar Component', 'MyProject', 'agent', 1780000000000, 1780000001000);", nil, nil, nil)
        sqlite3_close(qdDb)

        let convs = AgentSQLiteReader.readQoderConversations(dbPath: qdPath)
        expectEq(convs.count, 1, "Qoder parsed 1 session")
        expectEq(convs.first?.id, "qd-1", "Qoder id match")
        expectEq(convs.first?.title, "Fix Navbar Component", "Qoder title match")
        expectEq(convs.first?.snippet, "MyProject", "Qoder snippet match")
    }

    // 3. Cherry Studio test
    let csPath = tmp.appendingPathComponent("cherry_agents.db").path
    var csDb: OpaquePointer?
    if sqlite3_open(csPath, &csDb) == SQLITE_OK {
        sqlite3_exec(csDb, "CREATE TABLE sessions (id TEXT, name TEXT, updated_at TEXT, created_at TEXT);", nil, nil, nil)
        sqlite3_exec(csDb, "INSERT INTO sessions VALUES ('cs-1', 'Marketing Agent', '2026-05-01T10:00:00Z', '2026-05-01T09:00:00Z');", nil, nil, nil)
        sqlite3_close(csDb)

        let convs = AgentSQLiteReader.readCherryStudioConversations(dbPath: csPath)
        expectEq(convs.count, 1, "Cherry Studio parsed 1 session")
        expectEq(convs.first?.id, "cs-1", "Cherry Studio id match")
        expectEq(convs.first?.title, "Marketing Agent", "Cherry Studio title match")
    }

    // 4. CodeBuddy test
    let cbPath = tmp.appendingPathComponent("codebuddy-sessions.vscdb").path
    var cbDb: OpaquePointer?
    if sqlite3_open(cbPath, &cbDb) == SQLITE_OK {
        sqlite3_exec(cbDb, "CREATE TABLE ItemTable (key TEXT, value TEXT);", nil, nil, nil)
        let jsonVal = "{\"conversationId\":\"cb-1\",\"title\":\"Refactor Parser\",\"cwd\":\"/Users/dev/project\",\"createdAt\":1780000000000,\"updatedAt\":1780000002000}"
        let insertSQL = "INSERT INTO ItemTable VALUES ('session:cb-1', '\(jsonVal)');"
        sqlite3_exec(cbDb, insertSQL, nil, nil, nil)
        sqlite3_close(cbDb)

        let convs = AgentSQLiteReader.readCodeBuddyConversations(dbPath: cbPath)
        expectEq(convs.count, 1, "CodeBuddy parsed 1 session")
        expectEq(convs.first?.id, "cb-1", "CodeBuddy id match")
        expectEq(convs.first?.title, "Refactor Parser", "CodeBuddy title match")
    }

    // 5. Copilot test
    let cpPath = tmp.appendingPathComponent("session-store.db").path
    var cpDb: OpaquePointer?
    if sqlite3_open(cpPath, &cpDb) == SQLITE_OK {
        sqlite3_exec(cpDb, "CREATE TABLE sessions (id TEXT, summary TEXT, agent_name TEXT, cwd TEXT, created_at TEXT, updated_at TEXT);", nil, nil, nil)
        sqlite3_exec(cpDb, "INSERT INTO sessions VALUES ('cp-1', 'Explain algorithm', 'copilot', '/Users/test', '2026-02-01T12:00:00Z', '2026-02-01T12:05:00Z');", nil, nil, nil)
        sqlite3_close(cpDb)

        let convs = AgentSQLiteReader.readCopilotConversations(dbPath: cpPath)
        expectEq(convs.count, 1, "Copilot parsed 1 session")
        expectEq(convs.first?.id, "cp-1", "Copilot id match")
        expectEq(convs.first?.title, "Explain algorithm", "Copilot summary match")
    }

    // 6. Trae Modular Agent Sessions test
    let traeModular = tmp.appendingPathComponent("TraeModular")
    let sandboxDir = traeModular.appendingPathComponent("sandbox")
    try? FileManager.default.createDirectory(at: sandboxDir, withIntermediateDirectories: true)
    let sJson = """
    {
      "name": "session-trae-test",
      "permission": [
        { "dir_type": "workspace", "file_inherit_user": "/Users/test/Workspace/SuperProject" }
      ]
    }
    """
    try? sJson.write(to: sandboxDir.appendingPathComponent("session-trae-test.json"), atomically: true, encoding: .utf8)
    let traeConvs = AgentSQLiteReader.readTraeAgentDatabaseSessions(modularDir: traeModular.path)
    expect(traeConvs.contains(where: { $0.id == "session-trae-test" }), "Trae agent session parsed")

    // 7. OpenCode / MiniMax opencode.db test
    let opPath = tmp.appendingPathComponent("opencode.db").path
    var opDb: OpaquePointer?
    if sqlite3_open(opPath, &opDb) == SQLITE_OK {
        sqlite3_exec(opDb, "CREATE TABLE session (id TEXT, title TEXT, time_created INT, time_updated INT, directory TEXT);", nil, nil, nil)
        sqlite3_exec(opDb, "INSERT INTO session VALUES ('ses-1', 'Build API', 1780000000000, 1780000001000, '/Users/test/api');", nil, nil, nil)
        sqlite3_close(opDb)

        let convs = AgentSQLiteReader.readOpenCodeSessions(dbPath: opPath)
        expectEq(convs.count, 1, "OpenCode parsed 1 session")
        expectEq(convs.first?.id, "ses-1", "OpenCode id match")
        expectEq(convs.first?.title, "Build API", "OpenCode title match")
    }

    // 8. Marvis data.db test
    let mvPath = tmp.appendingPathComponent("marvis_data.db").path
    var mvDb: OpaquePointer?
    if sqlite3_open(mvPath, &mvDb) == SQLITE_OK {
        sqlite3_exec(mvDb, "CREATE TABLE conversations (conversation_id TEXT, title TEXT, created_at TEXT, updated_at TEXT);", nil, nil, nil)
        sqlite3_exec(mvDb, "INSERT INTO conversations VALUES ('mv-1', 'Chat with Marvis', '2026-09-28T04:56:15Z', '2026-09-28T05:00:00Z');", nil, nil, nil)
        sqlite3_close(mvDb)

        let convs = AgentSQLiteReader.readMarvisConversations(dbPath: mvPath)
        expectEq(convs.count, 1, "Marvis parsed 1 session")
        expectEq(convs.first?.id, "mv-1", "Marvis id match")
        expectEq(convs.first?.title, "Chat with Marvis", "Marvis title match")
    }
}

func testWorkspaceJsonParsing() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-ws-test-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    // Test 1: points to existing dir
    let validJson = """
    { "folder": "file://\(tmp.path)" }
    """
    let jsonPath = tmp.appendingPathComponent("workspace.json")
    try? validJson.write(to: jsonPath, atomically: true, encoding: .utf8)

    let parsed1 = AgentScanner.parseWorkspaceJson(dirPath: tmp.path)
    expectEq(parsed1.path, tmp.path, "parsed path matches")
    expectEq(parsed1.isOrphaned, false, "valid folder is not orphaned")
    expectEq(parsed1.name, tmp.lastPathComponent, "valid folder name")

    // Test 2: points to non-existent dir
    let deadPath = "/path/to/definitely/dead/project_\(UUID().uuidString)"
    let deadJson = """
    { "folder": "file://\(deadPath)" }
    """
    try? deadJson.write(to: jsonPath, atomically: true, encoding: .utf8)

    let parsed2 = AgentScanner.parseWorkspaceJson(dirPath: tmp.path)
    expectEq(parsed2.path, deadPath, "parsed dead path matches")
    expectEq(parsed2.isOrphaned, true, "missing folder is orphaned")
}

func testSQLiteMagicHeader() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-sqlite-test-\(UUID().uuidString).db")
    defer { try? FileManager.default.removeItem(at: tmp) }

    // Dummy text file
    try? "not a sqlite file".write(to: tmp, atomically: true, encoding: .utf8)
    expectEq(AgentSQLiteReader.isSQLiteFile(atPath: tmp.path), false, "plain text is not sqlite")

    // Real SQLite file
    try? FileManager.default.removeItem(at: tmp)
    var db: OpaquePointer?
    let rc = sqlite3_open(tmp.path, &db)
    expectEq(rc, SQLITE_OK, "sqlite3_open succeeds")
    sqlite3_exec(db, "CREATE TABLE test (id INT);", nil, nil, nil)
    sqlite3_close(db)

    expectEq(AgentSQLiteReader.isSQLiteFile(atPath: tmp.path), true, "real sqlite file recognized")
}

private func makeEntry(
    id: String? = nil, editor: AgentEditorKind = .cursor, scope: AgentDatabaseScope, file: String, dir: String,
    size: UInt64 = 10, mtime: Date = Date(timeIntervalSince1970: 1_000), orphaned: Bool = false,
    name: String = "db", convs: [AgentConversationSummary] = []
) -> AgentDatabaseEntry {
    AgentDatabaseEntry(
        id: id ?? file, editor: editor, scope: scope, filePath: file, fileName: (file as NSString).lastPathComponent,
        storageDirectory: dir, fileSizeBytes: size, lastModified: mtime, workspacePath: orphaned ? "/nonexistent" : nil,
        workspaceName: name, isOrphaned: orphaned, conversationCount: convs.count, conversations: convs
    )
}

func testAgentDatabaseBackupAndDelete() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-db-mgmt-\(UUID().uuidString)")
    let wsRoot = tmp.appendingPathComponent("workspaceStorage")
    let wsDir = wsRoot.appendingPathComponent("abc123")
    try? FileManager.default.createDirectory(at: wsDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let known = [AgentKnownPath(label: "ws", fullPath: wsRoot.path, scope: .workspace, isDirectory: true)]

    let dbFile = wsDir.appendingPathComponent("state.vscdb")
    try? "dummy db content".write(to: dbFile, atomically: true, encoding: .utf8)
    try? "wal".write(toFile: dbFile.path + "-wal", atomically: true, encoding: .utf8)
    let entry = makeEntry(scope: .workspace, file: dbFile.path, dir: wsDir.path, size: 16, orphaned: true, name: "Dead/Project")

    let backup = tmp.appendingPathComponent(AgentDatabaseManager.suggestedBackupName(for: entry, now: Date(timeIntervalSince1970: 0)))
    do {
        try AgentDatabaseManager.backupEntry(entry, to: backup)
        expect(FileManager.default.fileExists(atPath: backup.path), "backup file created at chosen URL")
        expect(FileManager.default.fileExists(atPath: backup.path + "-wal"), "backup keeps -wal")
        expect(!backup.lastPathComponent.contains("/"), "backup name has no slash")
        expect(backup.lastPathComponent.hasPrefix("cursor_Dead_Project_"), "backup name sanitised")
    } catch {
        expect(false, "backupEntry failed: \(error)")
    }
    do {
        try AgentDatabaseManager.backupEntry(entry, to: backup)
        expect(false, "backup must not overwrite an existing file")
    } catch {}

    // Refused deletes leave the file in place.
    let outside = makeEntry(scope: .workspace, file: backup.path, dir: tmp.path)
    do {
        try AgentDatabaseManager.deleteEntry(outside, knownPaths: known, appRunning: false)
        expect(false, "delete outside known paths must throw")
    } catch {
        expect(FileManager.default.fileExists(atPath: backup.path), "refused delete keeps file")
    }

    do {
        let freed = try AgentDatabaseManager.deleteEntry(entry, knownPaths: known, appRunning: true)
        expectEq(freed, 16, "freed bytes reported")
        expect(!FileManager.default.fileExists(atPath: wsDir.path), "orphaned workspace folder removed")
        expect(FileManager.default.fileExists(atPath: wsRoot.path), "workspace root itself kept")
    } catch {
        expect(false, "deleteEntry failed: \(error)")
    }
}

func testAgentDeletePolicy() {
    let root = "/Users/t/Library/Application Support/Cursor/User"
    let known = [
        AgentKnownPath(label: "g", fullPath: "\(root)/globalStorage/state.vscdb", scope: .global),
        AgentKnownPath(label: "w", fullPath: "\(root)/workspaceStorage", scope: .workspace, isDirectory: true),
        AgentKnownPath(label: "c", fullPath: "/Users/t/.cache/idx", scope: .vectorCache, isDirectory: true),
    ]
    let ws = "\(root)/workspaceStorage/abc"

    let global = makeEntry(scope: .global, file: "\(root)/globalStorage/state.vscdb", dir: "\(root)/globalStorage")
    expectEq(AgentDeletePolicy.evaluate(global, knownPaths: known, appRunning: false), .allowed(target: "\(root)/globalStorage/state.vscdb", isDirectory: false), "global DB deletable with confirmation")

    let liveWs = makeEntry(scope: .workspace, file: "\(ws)/state.vscdb", dir: ws)
    expectEq(AgentDeletePolicy.evaluate(liveWs, knownPaths: known, appRunning: false), .allowed(target: "\(ws)/state.vscdb", isDirectory: false), "workspace DB deletable when app closed")
    expectEq(AgentDeletePolicy.evaluate(liveWs, knownPaths: known, appRunning: true), .allowed(target: "\(ws)/state.vscdb", isDirectory: false), "workspace DB deletable with confirmation even while app runs")

    let orphan = makeEntry(scope: .workspace, file: "\(ws)/state.vscdb", dir: ws, orphaned: true)
    expectEq(AgentDeletePolicy.evaluate(orphan, knownPaths: known, appRunning: true), .allowed(target: ws, isDirectory: true), "orphaned workspace folder deletable even while app runs")

    let deepOrphan = makeEntry(scope: .workspace, file: "\(ws)/x/state.vscdb", dir: "\(ws)/x", orphaned: true)
    expectEq(AgentDeletePolicy.evaluate(deepOrphan, knownPaths: known, appRunning: false), .outsideKnownPaths, "orphan folder must be a direct child of the root")

    let rootAsDir = makeEntry(scope: .workspace, file: "\(root)/workspaceStorage/state.vscdb", dir: "\(root)/workspaceStorage", orphaned: true)
    expectEq(AgentDeletePolicy.evaluate(rootAsDir, knownPaths: known, appRunning: false), .outsideKnownPaths, "workspace root itself never removed")

    let traversal = makeEntry(scope: .workspace, file: "\(root)/workspaceStorage/../../../../.ssh/id_rsa", dir: ws)
    expectEq(AgentDeletePolicy.evaluate(traversal, knownPaths: known, appRunning: false), .outsideKnownPaths, "path traversal rejected")

    let forensic = makeEntry(scope: .workspace, file: "/Users/t/forensics/database.db", dir: "/Users/t/forensics")
    expectEq(AgentDeletePolicy.evaluate(forensic, knownPaths: known, appRunning: false), .outsideKnownPaths, "copies outside known paths untouched")

    let cache = makeEntry(scope: .vectorCache, file: "/Users/t/.cache/idx/k.db", dir: "/Users/t/.cache/idx")
    expectEq(AgentDeletePolicy.evaluate(cache, knownPaths: known, appRunning: false), .allowed(target: "/Users/t/.cache/idx/k.db", isDirectory: false), "cache DB deletable")

    let nestedRoot = "/Users/t/Library/Application Support/微信开发者工具"
    let nestedKnown = [AgentKnownPath(label: "wc", fullPath: nestedRoot, scope: .workspace, isDirectory: true)]
    let nestedDir = "\(nestedRoot)/hash123/Default/Editor/1.78/user-data/User/workspaceStorage/proj456"
    let nestedOrphan = makeEntry(scope: .workspace, file: "\(nestedDir)/state.vscdb", dir: nestedDir, orphaned: true)
    expectEq(AgentDeletePolicy.evaluate(nestedOrphan, knownPaths: nestedKnown, appRunning: false), .allowed(target: nestedDir, isDirectory: true), "nested profile workspaceStorage orphan deletable")

    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-orphans-\(UUID().uuidString)")
    let wsRoot = tmp.appendingPathComponent("workspaceStorage")
    let good = wsRoot.appendingPathComponent("good")
    try? FileManager.default.createDirectory(at: good, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }
    try? "x".write(to: good.appendingPathComponent("state.vscdb"), atomically: true, encoding: .utf8)
    let tmpKnown = [AgentKnownPath(label: "w", fullPath: wsRoot.path, scope: .workspace, isDirectory: true)]
    let orphans = [
        makeEntry(scope: .workspace, file: good.appendingPathComponent("state.vscdb").path, dir: good.path, size: 5, orphaned: true),
        makeEntry(scope: .workspace, file: "/elsewhere/state.vscdb", dir: "/elsewhere", size: 7, orphaned: true),
    ]
    let result = AgentDatabaseManager.cleanOrphanedEntries(orphans, knownPaths: { _ in tmpKnown })
    expectEq(result.deletedIds.count, 1, "one orphan cleaned")
    expectEq(result.skipped, 1, "orphan outside known paths skipped")
    expectEq(result.bytesFreed, 5, "only cleaned bytes counted")
}

func testAgentChatCatalog() {
    let c1 = AgentConversationSummary(id: "a", title: "Fix navbar", updatedAt: Date(timeIntervalSince1970: 300))
    let c2 = AgentConversationSummary(id: "b", title: "Refactor store", createdAt: Date(timeIntervalSince1970: 500), snippet: "PharosCore")
    let c3 = AgentConversationSummary(id: "c", title: "Undated")
    let entries = [
        makeEntry(id: "e1", editor: .cursor, scope: .workspace, file: "/a/1.db", dir: "/a", size: 100, mtime: Date(timeIntervalSince1970: 10), name: "Beta", convs: [c1, c3]),
        makeEntry(id: "e2", editor: .cursor, scope: .global, file: "/a/2.db", dir: "/a", size: 50, mtime: Date(timeIntervalSince1970: 30), name: "alpha", convs: [c2]),
        makeEntry(id: "e3", editor: .trae, scope: .vectorCache, file: "/b/3.db", dir: "/b", size: 300, mtime: Date(timeIntervalSince1970: 20), orphaned: true, name: "Gamma"),
    ]

    let sums = AgentChatCatalog.summarize(entries)
    expectEq(sums.map(\.editor), [.trae, .cursor], "summaries sorted by size")
    let cursor = sums.first { $0.editor == .cursor }
    expectEq(cursor?.totalBytes, 150, "cursor total")
    expectEq(cursor?.workspaceBytes, 100, "cursor workspace bytes")
    expectEq(cursor?.globalBytes, 50, "cursor global bytes")
    expectEq(cursor?.databaseCount, 2, "cursor db count")
    expectEq(cursor?.conversationCount, 3, "cursor conversation count")
    expectEq(cursor?.lastModified, Date(timeIntervalSince1970: 30), "cursor latest mtime")
    expectEq(sums.first?.orphanedCount, 1, "trae orphan count")

    expectEq(AgentChatCatalog.sorted(entries, by: .sizeDesc).map(\.id), ["e3", "e1", "e2"], "sort by size")
    expectEq(AgentChatCatalog.sorted(entries, by: .mtimeDesc).map(\.id), ["e2", "e3", "e1"], "sort by mtime")
    expectEq(AgentChatCatalog.sorted(entries, by: .nameAsc).map(\.id), ["e2", "e1", "e3"], "sort by name, case-insensitive")

    expect(AgentChatCatalog.matches(entries[0], query: "  NAVBAR "), "matches conversation title, trimmed and case-insensitive")
    expect(AgentChatCatalog.matches(entries[1], query: "pharoscore"), "matches conversation snippet")
    expect(AgentChatCatalog.matches(entries[2], query: "/b/"), "matches file path")
    expect(!AgentChatCatalog.matches(entries[2], query: "navbar"), "no false match")
    expect(AgentChatCatalog.matches(entries[2], query: ""), "empty query matches all")

    let refs = AgentChatCatalog.conversations(for: .cursor, in: entries)
    expectEq(refs.map(\.conversation.id), ["b", "a", "c"], "merged conversations newest first, undated last")
    expectEq(refs.first?.databaseName, "alpha", "conversation knows its database")
    expectEq(refs.first?.scope, .global, "conversation knows its scope")
    expectEq(AgentChatCatalog.conversations(for: .cursor, in: entries, query: "fix").map(\.conversation.id), ["a"], "conversation search")
    expectEq(Set(refs.map(\.id)).count, refs.count, "conversation ref ids unique")

    expect(!AgentChatCatalog.isTruncated(entries), "small DBs not truncated")
    let many = (0..<100).map { AgentConversationSummary(id: "\($0)", title: "t") }
    expect(AgentChatCatalog.isTruncated([makeEntry(scope: .global, file: "/x", dir: "/", convs: many)]), "DB at reader cap is truncated")
}

func testLiveAgentScanner() {
    let list = AgentScanner.scan()
    print("Detected \(list.count) AI agent databases (\(list.filter(\.isOrphaned).count) orphaned).")
    for entry in list.prefix(5) {
        let mb = Double(entry.fileSizeBytes) / (1024 * 1024)
        print("  - [\(entry.editor.displayName)] \(entry.fileName) (\(String(format: "%.1f", mb)) MB, \(entry.conversationCount) convs): \(entry.workspaceName)")
    }
    expect(list.count > 0, "found local AI agent databases")
}

func testCustomApplicationScanner() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-custom-app-\(UUID().uuidString)")
    let home = tmp.appendingPathComponent("fake-home")
    let appBundle = tmp.appendingPathComponent("MyCustomAI.app")
    let contents = appBundle.appendingPathComponent("Contents")
    try? FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    // 1. Write Info.plist
    let plist: [String: Any] = [
        "CFBundleIdentifier": "com.example.mycustomai",
        "CFBundleName": "MyCustomAI",
        "CFBundleDisplayName": "My Custom AI",
        "CFBundleExecutable": "MyCustomAI"
    ]
    let plistData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try? plistData?.write(to: contents.appendingPathComponent("Info.plist"))

    // 2. Create Application Support directories & databases
    let appSupport = home.appendingPathComponent("Library/Application Support/My Custom AI")
    let wsDir = appSupport.appendingPathComponent("User/workspaceStorage/ws101")
    try? FileManager.default.createDirectory(at: wsDir, withIntermediateDirectories: true)

    // A. SQLite database in appSupport root
    let dbPath = appSupport.appendingPathComponent("conversations.db").path
    var db: OpaquePointer?
    if sqlite3_open(dbPath, &db) == SQLITE_OK {
        sqlite3_exec(db, "CREATE TABLE chats (id TEXT, title TEXT, created_at TEXT);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO chats VALUES ('c1', 'Custom chat session 1', '2026-10-18 12:00:00');", nil, nil, nil)
        sqlite3_close(db)
    }

    // B. VSCode-style workspaceStorage state.vscdb
    let wsDbPath = wsDir.appendingPathComponent("state.vscdb").path
    if sqlite3_open(wsDbPath, &db) == SQLITE_OK {
        sqlite3_exec(db, "CREATE TABLE ItemTable (key TEXT, value TEXT);", nil, nil, nil)
        sqlite3_close(db)
    }
    let wsJson: [String: Any] = ["folder": "file:///Users/test/workspace/myproject"]
    if let d = try? JSONSerialization.data(withJSONObject: wsJson) {
        try? d.write(to: wsDir.appendingPathComponent("workspace.json"))
    }

    // 3. Scan the application
    let entries = AgentScanner.scanApplication(at: appBundle.path, homeDirectory: home.path)
    expect(entries.count >= 2, "found at least 2 databases in custom app (found \(entries.count))")

    for entry in entries {
        expectEq(entry.editor, .custom, "editor kind is custom")
        expectEq(entry.customEditorName, "My Custom AI", "resolved name matches CFBundleDisplayName")
        expectEq(entry.customAppPath, appBundle.path, "customAppPath recorded")
    }

    // Verify conversation parsing from generic reader
    if let convDb = entries.first(where: { $0.fileName == "conversations.db" }) {
        expectEq(convDb.conversationCount, 1, "parsed 1 conversation from chats table")
        expectEq(convDb.conversations.first?.title, "Custom chat session 1", "conversation title matches")
    }

    // 4. Summarize and verify grouping
    let summaries = AgentChatCatalog.summarize(entries)
    expectEq(summaries.count, 1, "custom app summarized into 1 card")
    expectEq(summaries.first?.displayName, "My Custom AI", "summary displays custom name")
    expectEq(summaries.first?.customAppPath, appBundle.path, "summary preserves app path")

    // 5. Test scan with customAppPaths
    let allEntries = AgentScanner.scan(homeDirectory: home.path, customAppPaths: [appBundle.path])
    expect(allEntries.contains { $0.customEditorName == "My Custom AI" }, "scan(customAppPaths:) includes custom app")
}
