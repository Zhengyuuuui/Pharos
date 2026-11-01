import Foundation
import SQLite3
import PharosCore

func testAgentRelocationAndMarkdown() {
    let tmpDir = NSTemporaryDirectory() + "pharos_reloc_test_\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let dbPath = "\(tmpDir)/test_reloc.db"
    var db: OpaquePointer?
    expectEq(sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil), SQLITE_OK, "open reloc db")

    let schema = """
    CREATE TABLE session (
        id TEXT PRIMARY KEY,
        title TEXT,
        time_created INTEGER,
        time_updated INTEGER,
        directory TEXT
    );
    CREATE TABLE message (
        id TEXT PRIMARY KEY,
        session_id TEXT,
        role TEXT,
        time_created INTEGER
    );
    CREATE TABLE part (
        id TEXT PRIMARY KEY,
        message_id TEXT,
        time_created INTEGER,
        data TEXT
    );
    CREATE TABLE project_directory (
        directory TEXT PRIMARY KEY
    );
    """
    expectEq(sqlite3_exec(db, schema, nil, nil, nil), SQLITE_OK, "create schema")

    let missingDir = "/non/existent/path/for/pharos/test/project_alpha"
    let newDir = tmpDir // guaranteed to exist

    // Insert session pointing to missing directory
    let ins = """
    INSERT INTO session VALUES ('s1', 'Refactoring Project', 1700000000000, 1700001000000, '\(missingDir)');
    INSERT INTO project_directory VALUES ('\(missingDir)');
    INSERT INTO message VALUES ('m1', 's1', 'user', 1700000010000);
    INSERT INTO part VALUES ('p1', 'm1', 1700000011000, '{"type":"text","text":"How do I test relocation?"}');
    INSERT INTO message VALUES ('m2', 's1', 'assistant', 1700000020000);
    INSERT INTO part VALUES ('p2', 'm2', 1700000021000, '{"type":"reasoning","text":"Analyzing DB schema..."}');
    INSERT INTO part VALUES ('p3', 'm2', 1700000022000, '{"type":"text","text":"Here is the solution."}');
    """
    expectEq(sqlite3_exec(db, ins, nil, nil, nil), SQLITE_OK, "insert seed")
    sqlite3_close(db)

    // 1. Test finding missing projects
    let missingList = AgentRelocation.findMissingProjects(dbPath: dbPath, editor: .openCode)
    expectEq(missingList.count, 1, "found 1 missing project")
    expectEq(missingList.first?.originalDirectory, missingDir, "matching original directory")
    expectEq(missingList.first?.sessionCount, 1, "1 session counted")

    // 2. Test remapping project
    do {
        let updatedCount = try AgentRelocation.relocateProject(
            dbPath: dbPath,
            editor: .openCode,
            oldDirectory: missingDir,
            newDirectory: newDir
        )
        expectEq(updatedCount, 1, "relocated 1 session")

        // Missing list should now be empty
        let afterList = AgentRelocation.findMissingProjects(dbPath: dbPath, editor: .openCode)
        expectEq(afterList.count, 0, "0 missing projects after relocation")
    } catch {
        expect(false, "relocateProject threw: \(error)")
    }

    // 3. Test Markdown export single session
    let md = AgentMarkdownExporter.exportSession(dbPath: dbPath, editor: .openCode, sessionId: "s1")
    expect(md != nil, "exported session markdown")
    if let text = md {
        expect(text.contains("# Refactoring Project"), "markdown contains session title")
        expect(text.contains("How do I test relocation?"), "markdown contains user prompt")
        expect(text.contains("Thinking"), "markdown contains reasoning block")
        expect(text.contains("Here is the solution."), "markdown contains assistant response")
    }

    // 4. Test Export All Sessions to Directory
    let exportDir = URL(fileURLWithPath: "\(tmpDir)/exported_md")
    do {
        let exported = try AgentMarkdownExporter.exportAllSessions(
            dbPath: dbPath,
            editor: .openCode,
            toDirectory: exportDir
        )
        expectEq(exported.count, 1, "exported 1 file to directory")
        expect(FileManager.default.fileExists(atPath: exported[0].path), "exported file exists on disk")
    } catch {
        expect(false, "exportAllSessions threw: \(error)")
    }
}
