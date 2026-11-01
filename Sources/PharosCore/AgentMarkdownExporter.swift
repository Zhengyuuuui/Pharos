import Foundation
import SQLite3

/// Engine to export historic AI conversations to clean, portable GitHub Flavored Markdown.
public enum AgentMarkdownExporter {

    /// Exports a specific session from an AI agent database as a Markdown string.
    public static func exportSession(
        dbPath: String,
        editor: AgentEditorKind,
        sessionId: String
    ) -> String? {
        guard AgentSQLiteReader.isSQLiteFile(atPath: dbPath) else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }

        switch editor {
        case .openCode, .miniMax:
            return exportOpenCodeSession(db: db, sessionId: sessionId)
        default:
            return nil
        }
    }

    private static func exportOpenCodeSession(db: OpaquePointer?, sessionId: String) -> String? {
        // 1. Query session header
        let sessionSql = "SELECT id, title, time_created, time_updated, directory FROM session WHERE id = ? LIMIT 1;"
        var sStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sessionSql, -1, &sStmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(sStmt) }

        sqlite3_bind_text(sStmt, 1, (sessionId as NSString).utf8String, -1, nil)
        guard sqlite3_step(sStmt) == SQLITE_ROW else { return nil }

        let sId = sqlite3_column_text(sStmt, 0).flatMap { String(cString: $0) } ?? sessionId
        let title = sqlite3_column_text(sStmt, 1).flatMap { String(cString: $0) } ?? "OpenCode Session"
        let createdMs = sqlite3_column_int64(sStmt, 2)
        let updatedMs = sqlite3_column_int64(sStmt, 3)
        let directory = sqlite3_column_text(sStmt, 4).flatMap { String(cString: $0) }

        let createdDateStr = createdMs > 0 ? Date(timeIntervalSince1970: Double(createdMs) / 1000.0).formatted() : "未知"
        let updatedDateStr = updatedMs > 0 ? Date(timeIntervalSince1970: Double(updatedMs) / 1000.0).formatted() : "未知"

        var md = "# \(title)\n\n"
        md += "- **Session ID**: `\(sId)`\n"
        md += "- **Created**: \(createdDateStr)\n"
        md += "- **Updated**: \(updatedDateStr)\n"
        if let directory, !directory.isEmpty {
            md += "- **Workspace Directory**: `\(directory)`\n"
        }
        md += "\n---\n\n"

        // 2. Query messages and their parts
        let msgSql = """
        SELECT m.id, m.role, m.time_created, p.data
        FROM message m
        LEFT JOIN part p ON p.message_id = m.id
        WHERE m.session_id = ?
        ORDER BY m.time_created ASC, p.time_created ASC;
        """

        var mStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, msgSql, -1, &mStmt, nil) == SQLITE_OK else { return md }
        defer { sqlite3_finalize(mStmt) }

        sqlite3_bind_text(mStmt, 1, (sessionId as NSString).utf8String, -1, nil)

        var currentMsgId = ""
        while sqlite3_step(mStmt) == SQLITE_ROW {
            let msgId = sqlite3_column_text(mStmt, 0).flatMap { String(cString: $0) } ?? ""
            let role = sqlite3_column_text(mStmt, 1).flatMap { String(cString: $0) } ?? "user"
            let partDataStr = sqlite3_column_text(mStmt, 3).flatMap { String(cString: $0) }

            if msgId != currentMsgId {
                currentMsgId = msgId
                let roleEmoji = role.lowercased() == "user" ? "👤 User" : (role.lowercased() == "assistant" ? "🤖 Assistant" : "⚙️ \(role.capitalized)")
                md += "\n### \(roleEmoji)\n\n"
            }

            if let partDataStr, let partData = partDataStr.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: partData) as? [String: Any] {
                let pType = json["type"] as? String ?? ""
                if pType == "text", let text = json["text"] as? String {
                    md += "\(text)\n\n"
                } else if pType == "reasoning", let reasoning = json["text"] as? String {
                    md += "> 💭 **Thinking**:\n>\n"
                    for line in reasoning.components(separatedBy: .newlines) {
                        md += "> \(line)\n"
                    }
                    md += "\n"
                } else if pType == "tool", let tool = json["tool"] as? String {
                    md += "<details><summary>🛠️ Tool Invocation: <code>\(tool)</code></summary>\n\n"
                    if let state = json["state"] as? [String: Any],
                       let output = state["output"] as? String {
                        md += "```\n\(output.prefix(2000))\n```\n"
                    }
                    md += "</details>\n\n"
                }
            }
        }

        return md
    }

    /// Exports session directly to a designated file URL.
    public static func exportSession(
        dbPath: String,
        editor: AgentEditorKind,
        sessionId: String,
        to targetURL: URL
    ) throws {
        guard let md = exportSession(dbPath: dbPath, editor: editor, sessionId: sessionId) else {
            throw VacuumError.sqliteError(message: "未找到指定会话数据")
        }
        try md.write(to: targetURL, atomically: true, encoding: .utf8)
    }

    /// Exports all sessions found in this database into individual Markdown files in the target directory.
    public static func exportAllSessions(
        dbPath: String,
        editor: AgentEditorKind,
        toDirectory targetDirURL: URL
    ) throws -> [URL] {
        guard AgentSQLiteReader.isSQLiteFile(atPath: dbPath) else { return [] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var sessionIds: [(id: String, title: String)] = []
        let sql = "SELECT id, title FROM session ORDER BY time_updated DESC;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? ""
                let title = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? id
                if !id.isEmpty {
                    sessionIds.append((id: id, title: title))
                }
            }
        }

        var exportedURLs: [URL] = []
        let fm = FileManager.default
        if !fm.fileExists(atPath: targetDirURL.path) {
            try fm.createDirectory(at: targetDirURL, withIntermediateDirectories: true)
        }

        for item in sessionIds {
            if let md = exportOpenCodeSession(db: db, sessionId: item.id) {
                let safeTitle = item.title
                    .components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|"))
                    .joined(separator: "_")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let name = (safeTitle.isEmpty ? item.id : safeTitle) + ".md"
                let fileURL = targetDirURL.appendingPathComponent(name)
                try md.write(to: fileURL, atomically: true, encoding: .utf8)
                exportedURLs.append(fileURL)
            }
        }

        return exportedURLs
    }
}
