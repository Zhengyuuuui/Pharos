import Foundation
import PharosCore
import SQLite3

func testAgentVacuumEngineAndExclusivity() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-vac-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    // 1. Test ProcessExclusivityGuard with mock processes
    let mockRunning = [
        ProcessSnapshot(pid: 1234, ppid: 1, name: "OpenCode", executablePath: "/Applications/OpenCode.app/Contents/MacOS/OpenCode", memoryBytes: 100),
        ProcessSnapshot(pid: 5678, ppid: 1, name: "Safari", executablePath: "/Applications/Safari.app/Contents/MacOS/Safari", memoryBytes: 50)
    ]
    let (isRunning, pids) = ProcessExclusivityGuard.check(editor: .openCode, processes: mockRunning)
    expect(isRunning, "OpenCode is detected as running")
    expectEq(pids, [1234], "PIDs match running OpenCode")

    let (isCursorRunning, _) = ProcessExclusivityGuard.check(editor: .cursor, processes: mockRunning)
    expect(!isCursorRunning, "Cursor is not running")

    // 2. Synthetic Database Setup
    let dbPath = tmp.appendingPathComponent("opencode.db").path
    var db: OpaquePointer?
    if sqlite3_open(dbPath, &db) == SQLITE_OK {
        sqlite3_exec(db, """
        CREATE TABLE session (id TEXT PRIMARY KEY, title TEXT, time_created INT, time_updated INT, directory TEXT);
        CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, role TEXT, time_created INT);
        CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INT, time_updated INT, data TEXT);
        CREATE TABLE event (id TEXT PRIMARY KEY, type TEXT, time_created INT, data TEXT);
        """, nil, nil, nil)

        sqlite3_exec(db, "INSERT INTO session VALUES ('ses_1', 'Hello Pharos', 1780000000000, 1780000010000, '\(tmp.path)');", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO message VALUES ('msg_1', 'ses_1', 'user', 1780000001000);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO part VALUES ('p_1', 'msg_1', 'ses_1', 1780000001000, 1780000001000, '{\"type\":\"text\",\"text\":\"What is Pharos?\"}');", nil, nil, nil)

        sqlite3_exec(db, "INSERT INTO message VALUES ('msg_2', 'ses_1', 'assistant', 1780000002000);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO part VALUES ('p_2', 'msg_2', 'ses_1', 1780000002000, 1780000002000, '{\"type\":\"text\",\"text\":\"Pharos is an AI session manager.\"}');", nil, nil, nil)

        // 100 streaming events (bloat)
        let payload = String(repeating: "STREAM_DATA_", count: 100)
        for i in 0..<100 {
            sqlite3_exec(db, "INSERT INTO event VALUES ('ev_\(i)', 'message.part.updated.1', 1780000001000, '\(payload)');", nil, nil, nil)
        }
        // 5 non-streaming events
        for i in 0..<5 {
            sqlite3_exec(db, "INSERT INTO event VALUES ('ev_keep_\(i)', 'session.created.1', 1780000001000, 'meta');", nil, nil, nil)
        }

        sqlite3_close(db)
    }

    // 3. Test Pre-flight Backup & Restore
    do {
        let bak = try AgentVacuumEngine.createPreflightBackup(for: dbPath)
        expect(FileManager.default.fileExists(atPath: bak), "backup file exists on disk")

        let backups = AgentVacuumEngine.listBackups(for: dbPath)
        expectEq(backups.count, 1, "found 1 backup")
        expectEq(backups.first?.backupPath, bak, "backup path matched")

        // Test backup rotation: second backup rotates and keeps only 1 latest snapshot on disk
        // Sleep slightly to guarantee distinct timestamp/filename
        usleep(100_000)
        let bak2 = try AgentVacuumEngine.createPreflightBackup(for: dbPath)
        let backupsAfterSecond = AgentVacuumEngine.listBackups(for: dbPath)
        expectEq(backupsAfterSecond.count, 1, "backup rotation keeps only 1 latest snapshot")
        expectEq(backupsAfterSecond.first?.backupPath, bak2, "latest backup is retained")
        expect(!FileManager.default.fileExists(atPath: bak), "older backup was automatically removed")

        // Mutate db then restore
        var mDb: OpaquePointer?
        if sqlite3_open(dbPath, &mDb) == SQLITE_OK {
            sqlite3_exec(mDb, "DROP TABLE event;", nil, nil, nil)
            sqlite3_close(mDb)
        }

        try AgentVacuumEngine.restoreBackup(from: bak2, to: dbPath)

        // Verify restoration
        var rDb: OpaquePointer?
        if sqlite3_open(dbPath, &rDb) == SQLITE_OK {
            var stmt: OpaquePointer?
            let check = sqlite3_prepare_v2(rDb, "SELECT count(*) FROM event;", -1, &stmt, nil)
            expectEq(check, SQLITE_OK, "event table restored from backup")
            if check == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    expectEq(sqlite3_column_int(stmt, 0), 105, "105 events restored")
                }
                sqlite3_finalize(stmt)
            }
            sqlite3_close(rDb)
        }
    } catch {
        expect(false, "backup/restore threw: \(error)")
    }

    // 4. Test compactAndVacuum execution
    // Mock no running editor
    do {
        let res = try AgentVacuumEngine.compactAndVacuum(
            dbPath: dbPath,
            editor: .openCode,
            options: CompactionOptions(level: .level1StreamEvents, autoBackup: true, vacuumAfter: true),
            processes: []
        )
        expect(res.deletedCount == 100, "deleted exactly 100 streaming events (found \(res.deletedCount))")
        expect(res.backupPath != nil, "pre-flight backup created")

        // Verify database integrity: session, message, and part remain completely intact!
        var vDb: OpaquePointer?
        if sqlite3_open(dbPath, &vDb) == SQLITE_OK {
            var sStmt: OpaquePointer?
            if sqlite3_prepare_v2(vDb, "SELECT count(*) FROM session;", -1, &sStmt, nil) == SQLITE_OK {
                if sqlite3_step(sStmt) == SQLITE_ROW { expectEq(sqlite3_column_int(sStmt, 0), 1, "session intact") }
                sqlite3_finalize(sStmt)
            }

            var pStmt: OpaquePointer?
            if sqlite3_prepare_v2(vDb, "SELECT count(*) FROM part;", -1, &pStmt, nil) == SQLITE_OK {
                if sqlite3_step(pStmt) == SQLITE_ROW { expectEq(sqlite3_column_int(pStmt, 0), 2, "2 parts intact") }
                sqlite3_finalize(pStmt)
            }

            var eStmt: OpaquePointer?
            if sqlite3_prepare_v2(vDb, "SELECT count(*) FROM event;", -1, &eStmt, nil) == SQLITE_OK {
                if sqlite3_step(eStmt) == SQLITE_ROW { expectEq(sqlite3_column_int(eStmt, 0), 5, "5 non-streaming events preserved") }
                sqlite3_finalize(eStmt)
            }
            sqlite3_close(vDb)
        }
    } catch {
        expect(false, "compactAndVacuum threw: \(error)")
    }

    // 5. Test Relocation
    let missing = AgentRelocation.findMissingProjects(dbPath: dbPath, editor: .openCode)
    expectEq(missing.count, 0, "directory currently exists")

    // Update to non-existent dir and find it
    var rDb: OpaquePointer?
    if sqlite3_open(dbPath, &rDb) == SQLITE_OK {
        sqlite3_exec(rDb, "UPDATE session SET directory = '/Users/ghost/abandoned_project';", nil, nil, nil)
        sqlite3_close(rDb)
    }
    let missingFound = AgentRelocation.findMissingProjects(dbPath: dbPath, editor: .openCode)
    expectEq(missingFound.count, 1, "found 1 missing project")
    expectEq(missingFound.first?.originalDirectory, "/Users/ghost/abandoned_project", "missing path match")

    // Relocate to existing tmp dir
    do {
        let updated = try AgentRelocation.relocateProject(
            dbPath: dbPath,
            editor: .openCode,
            oldDirectory: "/Users/ghost/abandoned_project",
            newDirectory: tmp.path
        )
        expectEq(updated, 1, "1 session relocated")

        let postMissing = AgentRelocation.findMissingProjects(dbPath: dbPath, editor: .openCode)
        expectEq(postMissing.count, 0, "no missing projects after relocation")
    } catch {
        expect(false, "relocation threw: \(error)")
    }

    // 6. Test Markdown Export
    guard let md = AgentMarkdownExporter.exportSession(dbPath: dbPath, editor: .openCode, sessionId: "ses_1") else {
        expect(false, "markdown export returned nil")
        return
    }
    expect(md.contains("# Hello Pharos"), "markdown contains title")
    expect(md.contains("👤 User"), "markdown contains user section")
    expect(md.contains("What is Pharos?"), "markdown contains prompt text")
    expect(md.contains("🤖 Assistant"), "markdown contains assistant section")
    expect(md.contains("Pharos is an AI session manager."), "markdown contains response text")
}
