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

func testAgentDatabaseBackupAndDelete() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-db-mgmt-\(UUID().uuidString)")
    let backupDir = tmp.appendingPathComponent("backups")
    let wsDir = tmp.appendingPathComponent("workspace_storage_123")
    try? FileManager.default.createDirectory(at: wsDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let dbFile = wsDir.appendingPathComponent("state.vscdb")
    try? "dummy db content".write(to: dbFile, atomically: true, encoding: .utf8)

    let entry = AgentDatabaseEntry(
        id: dbFile.path,
        editor: .cursor,
        scope: .workspace,
        filePath: dbFile.path,
        fileName: "state.vscdb",
        storageDirectory: wsDir.path,
        fileSizeBytes: 16,
        lastModified: Date(),
        workspacePath: "/nonexistent/dead",
        workspaceName: "TestDeadProject",
        isOrphaned: true,
        conversationCount: 0,
        conversations: []
    )

    // Test Backup
    do {
        let backedUpURL = try AgentDatabaseManager.backupEntry(entry, toDirectory: backupDir)
        expect(FileManager.default.fileExists(atPath: backedUpURL.path), "backup file created")
    } catch {
        expect(false, "backupEntry failed: \(error)")
    }

    // Test Delete Orphaned Workspace Directory
    do {
        try AgentDatabaseManager.deleteEntry(entry)
        expect(!FileManager.default.fileExists(atPath: wsDir.path), "orphaned storage directory was removed")
    } catch {
        expect(false, "deleteEntry failed: \(error)")
    }
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
