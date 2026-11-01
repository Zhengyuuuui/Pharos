import Foundation
import PharosCore
import SQLite3

func testAgentStorageProfiler() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-prof-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    // 1. Synthetic OpenCode Database
    let openCodePath = tmp.appendingPathComponent("opencode.db").path
    var db: OpaquePointer?
    if sqlite3_open(openCodePath, &db) == SQLITE_OK {
        sqlite3_exec(db, """
        CREATE TABLE session (id TEXT PRIMARY KEY, title TEXT, time_created INT, time_updated INT, directory TEXT);
        CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, role TEXT, time_created INT);
        CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INT, time_updated INT, data TEXT);
        CREATE TABLE event (id TEXT PRIMARY KEY, type TEXT, time_created INT, data TEXT);
        """, nil, nil, nil)

        // Insert session & messages
        sqlite3_exec(db, "INSERT INTO session VALUES ('s1', 'Build Website', 1780000000000, 1780000010000, '/Users/test/web');", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO session VALUES ('s2', 'Fix Database Bug', 1780000000000, 1780000020000, '/Users/test/api');", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO message VALUES ('m1', 's1', 'user', 1780000001000);", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO message VALUES ('m2', 's1', 'assistant', 1780000002000);", nil, nil, nil)

        // Insert parts (100KB payload)
        let chunk10k = String(repeating: "A", count: 10_000)
        for i in 0..<10 {
            sqlite3_exec(db, "INSERT INTO part VALUES ('p\(i)', 'm2', 's1', 1780000002000, 1780000002000, '{\"type\":\"text\",\"text\":\"\(chunk10k)\"}');", nil, nil, nil)
        }

        // Insert streaming events (500KB total bloat)
        let chunk50k = String(repeating: "E", count: 50_000)
        for i in 0..<10 {
            sqlite3_exec(db, "INSERT INTO event VALUES ('e\(i)', 'message.part.updated.1', 1780000002000, '\(chunk50k)');", nil, nil, nil)
        }
        // Non-streaming events (small)
        sqlite3_exec(db, "INSERT INTO event VALUES ('e_create', 'session.created.1', 1780000000000, '{\"id\":\"s1\"}');", nil, nil, nil)

        sqlite3_close(db)
    }

    guard let profile = AgentStorageProfiler.profile(dbPath: openCodePath, editor: .openCode) else {
        expect(false, "OpenCode profiler returned nil")
        return
    }

    expect(profile.pageSize >= 512, "page size valid")
    expect(profile.pageCount > 0, "page count > 0")
    expectEq(profile.tableBreakdown.count, 4, "table breakdown has 4 tables")

    let eventTable = profile.tableBreakdown.first { $0.name.contains("event") }
    expect(eventTable != nil, "event table found")
    expect(eventTable?.isBloatCandidate == true, "event table is flagged as bloat candidate")
    expectEq(eventTable?.rowCount, 11, "11 event rows")
    expect(eventTable!.payloadBytes >= 500_000, "event payload >= 500KB")

    let partTable = profile.tableBreakdown.first { $0.name.contains("part") }
    expect(partTable != nil, "part table found")
    expect(partTable?.isBloatCandidate == false, "part table is not a bloat candidate")
    expectEq(partTable?.rowCount, 10, "10 part rows")

    expect(profile.reclaimableBytes >= 500_000, "reclaimable bytes captures streaming events")
    expectEq(profile.topHeavySessions.count, 2, "2 top heavy sessions")
    expectEq(profile.topHeavySessions.first?.id, "s1", "s1 is top session")
    expect(profile.topHeavySessions.first!.sizeBytes >= 100_000, "top session size >= 100KB")

    // 2. Synthetic Cursor Database
    let cursorPath = tmp.appendingPathComponent("state.vscdb").path
    var curDb: OpaquePointer?
    if sqlite3_open(cursorPath, &curDb) == SQLITE_OK {
        sqlite3_exec(curDb, """
        CREATE TABLE cursorDiskKV (key TEXT UNIQUE, value BLOB);
        CREATE TABLE composerHeaders (composerId TEXT PRIMARY KEY, value TEXT);
        """, nil, nil, nil)

        let bloatChunk = String(repeating: "C", count: 20_000)
        for i in 0..<5 {
            sqlite3_exec(curDb, "INSERT INTO cursorDiskKV VALUES ('checkpointId:cp\(i)', '\(bloatChunk)');", nil, nil, nil)
            sqlite3_exec(curDb, "INSERT INTO cursorDiskKV VALUES ('agentKv:ak\(i)', '\(bloatChunk)');", nil, nil, nil)
        }
        sqlite3_exec(curDb, "INSERT INTO cursorDiskKV VALUES ('composerData:cd1', 'important active data');", nil, nil, nil)

        sqlite3_close(curDb)
    }

    guard let curProfile = AgentStorageProfiler.profile(dbPath: cursorPath, editor: .cursor) else {
        expect(false, "Cursor profiler returned nil")
        return
    }

    expect(curProfile.reclaimableBytes >= 200_000, "Cursor reclaimable captures checkpoints & agentKv")
    let checkpointItem = curProfile.tableBreakdown.first { $0.name.contains("checkpointId") }
    expect(checkpointItem?.isBloatCandidate == true, "checkpointId is candidate")
}
