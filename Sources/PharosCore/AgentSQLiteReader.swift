import Foundation
import SQLite3

public struct AgentSQLiteReader {
    /// Validates if a file begins with the standard 16-byte SQLite 3 magic header: "SQLite format 3\0".
    public static func isSQLiteFile(atPath path: String) -> Bool {
        guard let file = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? file.close() }
        let data = file.readData(ofLength: 16)
        guard data.count == 16 else { return false }
        let header = String(decoding: data, as: UTF8.self)
        return header.hasPrefix("SQLite format 3")
    }

    /// Reads Cursor Composer conversations from globalStorage or workspace state.vscdb.
    public static func readCursorConversations(dbPath: String) -> [AgentConversationSummary] {
        guard isSQLiteFile(atPath: dbPath) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var results: [AgentConversationSummary] = []

        // Try reading composerHeaders table (standard in modern Cursor)
        let query = "SELECT composerId, createdAt, lastUpdatedAt, value FROM composerHeaders ORDER BY createdAt DESC LIMIT 100;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idStr = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? UUID().uuidString
                let createdMs = sqlite3_column_int64(stmt, 1)
                let updatedMs = sqlite3_column_int64(stmt, 2)
                let valStr = sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) } ?? ""

                var title = ""
                var mode: String? = nil
                var snippet: String? = nil

                if let valData = valStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: valData) as? [String: Any] {
                    if let name = json["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = name
                    }
                    if let unified = json["unifiedMode"] as? String {
                        mode = unified
                    }
                    if let ws = json["workspaceIdentifier"] as? [String: Any],
                       let uri = ws["uri"] as? [String: Any],
                       let fsPath = uri["fsPath"] as? String {
                        snippet = fsPath
                    }
                }

                if title.isEmpty {
                    if mode == "agent" {
                        title = "Agent Composer"
                    } else if mode == "chat" {
                        title = "Chat Composer"
                    } else {
                        title = "Composer Session"
                    }
                }

                let createdDate = createdMs > 0 ? Date(timeIntervalSince1970: Double(createdMs) / 1000.0) : nil
                let updatedDate = updatedMs > 0 ? Date(timeIntervalSince1970: Double(updatedMs) / 1000.0) : nil

                results.append(AgentConversationSummary(
                    id: idStr,
                    title: title,
                    createdAt: createdDate,
                    updatedAt: updatedDate,
                    mode: mode,
                    messageCount: nil,
                    snippet: snippet
                ))
            }
        }

        // Fallback for older Cursor versions: ItemTable key 'composer.composerHeaders'
        if results.isEmpty {
            let itemQuery = "SELECT value FROM ItemTable WHERE key = 'composer.composerHeaders' LIMIT 1;"
            var itemStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, itemQuery, -1, &itemStmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(itemStmt) }
                if sqlite3_step(itemStmt) == SQLITE_ROW,
                   let valStr = sqlite3_column_text(itemStmt, 0).flatMap({ String(cString: $0) }),
                   let valData = valStr.data(using: .utf8),
                   let list = try? JSONSerialization.jsonObject(with: valData) as? [[String: Any]] {
                    for item in list.prefix(100) {
                        let id = (item["composerId"] as? String) ?? UUID().uuidString
                        let name = (item["name"] as? String) ?? ""
                        let mode = item["unifiedMode"] as? String
                        let title = name.isEmpty ? (mode == "agent" ? "Agent Composer" : "Composer Session") : name
                        let createdMs = (item["createdAt"] as? NSNumber)?.int64Value ?? 0
                        let updatedMs = (item["lastUpdatedAt"] as? NSNumber)?.int64Value ?? 0
                        let createdDate = createdMs > 0 ? Date(timeIntervalSince1970: Double(createdMs) / 1000.0) : nil
                        let updatedDate = updatedMs > 0 ? Date(timeIntervalSince1970: Double(updatedMs) / 1000.0) : nil
                        results.append(AgentConversationSummary(
                            id: id,
                            title: title,
                            createdAt: createdDate,
                            updatedAt: updatedDate,
                            mode: mode,
                            messageCount: nil,
                            snippet: nil
                        ))
                    }
                }
            }
        }

        return results
    }

    /// Reads Trae chat and agent sessions from ItemTable in state.vscdb.
    public static func readTraeSessions(dbPath: String) -> [AgentConversationSummary] {
        guard isSQLiteFile(atPath: dbPath) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var results: [AgentConversationSummary] = []
        let query = "SELECT key, value FROM ItemTable WHERE key = 'memento/icube-ai-agent-storage' OR key = 'chat.ChatSessionStore.index' OR key LIKE '%ai-chat%session%' LIMIT 10;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let keyStr = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? ""
                let valStr = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? ""
                guard let data = valStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                if keyStr == "memento/icube-ai-agent-storage", let list = json["list"] as? [[String: Any]] {
                    for item in list {
                        let sId = item["sessionId"] as? String ?? UUID().uuidString
                        let msgs = item["messages"] as? [[String: Any]] ?? []
                        var title = "Agent Session"
                        if let firstMsg = msgs.first, let content = firstMsg["content"] as? String, !content.isEmpty {
                            title = String(content.prefix(60)).replacingOccurrences(of: "\n", with: " ")
                        }
                        results.append(AgentConversationSummary(
                            id: sId,
                            title: title,
                            createdAt: nil,
                            updatedAt: nil,
                            mode: "agent",
                            messageCount: msgs.count,
                            snippet: nil
                        ))
                    }
                } else if let entries = json["entries"] as? [String: [String: Any]] {
                    for (id, dict) in entries {
                        let title = dict["title"] as? String ?? "Chat Session"
                        results.append(AgentConversationSummary(
                            id: id,
                            title: title,
                            createdAt: nil,
                            updatedAt: nil,
                            mode: "chat",
                            messageCount: nil,
                            snippet: nil
                        ))
                    }
                }
            }
        }
        return results
    }

    /// Reads Trae AI Agent sessions from ModularData/ai-agent sandbox manifests and ~/.trae-cn session workdirs.
    public static func readTraeAgentDatabaseSessions(modularDir: String) -> [AgentConversationSummary] {
        var results: [AgentConversationSummary] = []
        let fm = FileManager.default

        // 1. Check sandbox/*.json
        let sandboxDir = (modularDir as NSString).appendingPathComponent("sandbox")
        if let files = try? fm.contentsOfDirectory(atPath: sandboxDir) {
            for file in files where file.hasSuffix(".json") && !file.hasSuffix("-hooks.json") {
                let filePath = (sandboxDir as NSString).appendingPathComponent(file)
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                let sId = json["name"] as? String ?? (file as NSString).deletingPathExtension
                var wsName = ""
                if let perms = json["permission"] as? [[String: Any]] {
                    for p in perms {
                        if let dirType = p["dir_type"] as? String, dirType == "workspace",
                           let wsPath = p["file_inherit_user"] as? String {
                            wsName = (wsPath as NSString).lastPathComponent
                            break
                        }
                    }
                }

                let mtime = (try? fm.attributesOfItem(atPath: filePath)[.modificationDate] as? Date) ?? Date()
                let title = wsName.isEmpty ? "Trae Session (\(sId.prefix(8)))" : "Trae: \(wsName)"
                results.append(AgentConversationSummary(
                    id: sId,
                    title: title,
                    createdAt: mtime,
                    updatedAt: mtime,
                    mode: "agent",
                    messageCount: nil,
                    snippet: wsName.isEmpty ? nil : "Workspace: \(wsName)"
                ))
            }
        }

        // 2. Also check ~/.trae-cn/session_work_dirs
        let home = NSHomeDirectory()
        for sessionBase in ["\(home)/.trae-cn/session_work_dirs", "\(home)/.trae/session_work_dirs"] {
            guard let dirs = try? fm.contentsOfDirectory(atPath: sessionBase) else { continue }
            for d in dirs where !d.hasPrefix(".") {
                let dPath = (sessionBase as NSString).appendingPathComponent(d)
                var wsName = ""
                let mountConfig = (dPath as NSString).appendingPathComponent("project.mount_config")
                if let mountStr = try? String(contentsOfFile: mountConfig, encoding: .utf8) {
                    let parts = mountStr.components(separatedBy: ":")
                    if let first = parts.first {
                        let clean = first.replacingOccurrences(of: "/mnt/host", with: "")
                        wsName = (clean as NSString).lastPathComponent
                    }
                }

                var title = wsName.isEmpty ? "Trae Session (\(d.prefix(8)))" : "Trae: \(wsName)"
                let origMd = (dPath as NSString).appendingPathComponent("original.md")
                if let mdContent = try? String(contentsOfFile: origMd, encoding: .utf8) {
                    for line in mdContent.components(separatedBy: "\n").prefix(10) {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "#", with: "")
                            .replacingOccurrences(of: "*", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && trimmed.count > 3 {
                            title = String(trimmed.prefix(50))
                            break
                        }
                    }
                }

                let mtime = (try? fm.attributesOfItem(atPath: dPath)[.modificationDate] as? Date) ?? Date()
                if !results.contains(where: { $0.id == d }) {
                    results.append(AgentConversationSummary(
                        id: d,
                        title: title,
                        createdAt: mtime,
                        updatedAt: mtime,
                        mode: "agent",
                        messageCount: nil,
                        snippet: wsName.isEmpty ? nil : "Workspace: \(wsName)"
                    ))
                }
            }
        }

        return results.sorted { ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast) }
    }

    /// Counts rows in ItemTable if present.
    public static func countItemTableRows(dbPath: String) -> Int {
        guard isSQLiteFile(atPath: dbPath) else { return 0 }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, "SELECT count(*) FROM ItemTable;", -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        return count
    }

    /// Reads Antigravity conversation sessions from conversation_summaries.db
    public static func readAntigravityConversations(dbPath: String) -> [AgentConversationSummary] {
        guard isSQLiteFile(atPath: dbPath) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var results: [AgentConversationSummary] = []
        let query = "SELECT conversation_id, title, preview, step_count, last_modified_time, workspace_uris FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 100;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idStr = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? UUID().uuidString
                let rawTitle = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? ""
                let preview = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
                let stepCount = Int(sqlite3_column_int(stmt, 3))
                let workspaceUris = sqlite3_column_text(stmt, 5).flatMap { String(cString: $0) }

                var date: Date? = nil
                let type = sqlite3_column_type(stmt, 4)
                if type == SQLITE_INTEGER || type == SQLITE_FLOAT {
                    let ts = sqlite3_column_double(stmt, 4)
                    if ts > 1_000_000_000_000 {
                        date = Date(timeIntervalSince1970: ts / 1000.0)
                    } else if ts > 0 {
                        date = Date(timeIntervalSince1970: ts)
                    }
                } else if type == SQLITE_TEXT {
                    if let text = sqlite3_column_text(stmt, 4).flatMap({ String(cString: $0) }) {
                        date = parseDate(text)
                    }
                }

                var snippet = preview
                if (snippet == nil || snippet?.isEmpty == true), let ws = workspaceUris, !ws.isEmpty {
                    snippet = ws.replacingOccurrences(of: "file://", with: "")
                }

                let finalTitle = rawTitle.isEmpty ? (snippet.map { String($0.prefix(50)) } ?? "Agent Conversation") : rawTitle

                results.append(AgentConversationSummary(
                    id: idStr,
                    title: finalTitle,
                    createdAt: date,
                    updatedAt: date,
                    mode: "agent",
                    messageCount: stepCount > 0 ? stepCount : nil,
                    snippet: snippet
                ))
            }
        }
        return results
    }

    /// Reads Qoder / QoderCN sessions from local.db
    public static func readQoderConversations(dbPath: String) -> [AgentConversationSummary] {
        guard isSQLiteFile(atPath: dbPath) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var results: [AgentConversationSummary] = []
        let query = "SELECT session_id, session_title, project_name, mode, gmt_create, gmt_modified FROM chat_session ORDER BY gmt_modified DESC LIMIT 100;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idStr = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? UUID().uuidString
                let rawTitle = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? ""
                let project = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
                let mode = sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) }
                let createdMs = sqlite3_column_int64(stmt, 4)
                let modifiedMs = sqlite3_column_int64(stmt, 5)

                let title = rawTitle.isEmpty ? (project.map { "\($0) Session" } ?? "Qoder Session") : rawTitle
                let createdDate = createdMs > 0 ? Date(timeIntervalSince1970: Double(createdMs) / 1000.0) : nil
                let modifiedDate = modifiedMs > 0 ? Date(timeIntervalSince1970: Double(modifiedMs) / 1000.0) : nil

                results.append(AgentConversationSummary(
                    id: idStr,
                    title: title,
                    createdAt: createdDate,
                    updatedAt: modifiedDate,
                    mode: mode ?? "agent",
                    messageCount: nil,
                    snippet: project
                ))
            }
        }
        return results
    }

    /// Reads Cherry Studio agent sessions from agents.db
    public static func readCherryStudioConversations(dbPath: String) -> [AgentConversationSummary] {
        guard isSQLiteFile(atPath: dbPath) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var results: [AgentConversationSummary] = []
        let query = "SELECT id, name, updated_at, created_at FROM sessions ORDER BY updated_at DESC LIMIT 100;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idStr = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? UUID().uuidString
                let name = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? "Cherry Session"
                let updatedStr = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
                let createdStr = sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) }

                let updatedDate = updatedStr.flatMap { parseDate($0) }
                let createdDate = createdStr.flatMap { parseDate($0) }

                results.append(AgentConversationSummary(
                    id: idStr,
                    title: name,
                    createdAt: createdDate,
                    updatedAt: updatedDate,
                    mode: "agent",
                    messageCount: nil,
                    snippet: nil
                ))
            }
        }
        return results
    }

    /// Reads CodeBuddy CN sessions from codebuddy-sessions.vscdb
    public static func readCodeBuddyConversations(dbPath: String) -> [AgentConversationSummary] {
        guard isSQLiteFile(atPath: dbPath) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var results: [AgentConversationSummary] = []
        let query = "SELECT key, value FROM ItemTable WHERE key LIKE 'session:%' LIMIT 100;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let valStr = sqlite3_column_text(stmt, 1).flatMap({ String(cString: $0) }),
                      let data = valStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }

                let cId = (json["conversationId"] as? String) ?? UUID().uuidString
                let title = (json["title"] as? String) ?? "CodeBuddy Session"
                let cwd = json["cwd"] as? String
                let createdMs = (json["createdAt"] as? NSNumber)?.int64Value ?? 0
                let updatedMs = (json["updatedAt"] as? NSNumber)?.int64Value ?? 0
                let createdDate = createdMs > 0 ? Date(timeIntervalSince1970: Double(createdMs) / 1000.0) : nil
                let updatedDate = updatedMs > 0 ? Date(timeIntervalSince1970: Double(updatedMs) / 1000.0) : nil

                results.append(AgentConversationSummary(
                    id: cId,
                    title: title,
                    createdAt: createdDate,
                    updatedAt: updatedDate,
                    mode: "agent",
                    messageCount: nil,
                    snippet: cwd
                ))
            }
        }
        return results
    }

    /// Reads VS Code GitHub Copilot Chat sessions from session-store.db
    public static func readCopilotConversations(dbPath: String) -> [AgentConversationSummary] {
        guard isSQLiteFile(atPath: dbPath) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var results: [AgentConversationSummary] = []
        let query = "SELECT id, summary, agent_name, cwd, created_at, updated_at FROM sessions ORDER BY updated_at DESC LIMIT 100;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idStr = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? UUID().uuidString
                let summary = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? "Copilot Chat"
                let agentName = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
                let cwd = sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) }
                let createdStr = sqlite3_column_text(stmt, 4).flatMap { String(cString: $0) }
                let updatedStr = sqlite3_column_text(stmt, 5).flatMap { String(cString: $0) }

                results.append(AgentConversationSummary(
                    id: idStr,
                    title: summary,
                    createdAt: createdStr.flatMap { parseDate($0) },
                    updatedAt: updatedStr.flatMap { parseDate($0) },
                    mode: agentName ?? "copilot",
                    messageCount: nil,
                    snippet: cwd
                ))
            }
        }
        return results
    }

    /// Reads OpenCode / MiniMax runtime sessions from opencode.db
    public static func readOpenCodeSessions(dbPath: String) -> [AgentConversationSummary] {
        guard isSQLiteFile(atPath: dbPath) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var results: [AgentConversationSummary] = []
        let query = "SELECT id, title, time_created, time_updated, directory FROM session ORDER BY time_updated DESC LIMIT 100;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idStr = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? UUID().uuidString
                let rawTitle = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? ""
                let createdMs = sqlite3_column_int64(stmt, 2)
                let updatedMs = sqlite3_column_int64(stmt, 3)
                let directory = sqlite3_column_text(stmt, 4).flatMap { String(cString: $0) }

                let title = rawTitle.isEmpty ? (directory.map { ($0 as NSString).lastPathComponent } ?? "Session") : rawTitle
                let createdDate = createdMs > 0 ? Date(timeIntervalSince1970: Double(createdMs) / 1000.0) : nil
                let updatedDate = updatedMs > 0 ? Date(timeIntervalSince1970: Double(updatedMs) / 1000.0) : nil

                results.append(AgentConversationSummary(
                    id: idStr,
                    title: title,
                    createdAt: createdDate,
                    updatedAt: updatedDate,
                    mode: "opencode",
                    messageCount: nil,
                    snippet: directory
                ))
            }
        }
        return results
    }

    /// Reads Tencent Marvis conversation records from data.db
    public static func readMarvisConversations(dbPath: String) -> [AgentConversationSummary] {
        guard isSQLiteFile(atPath: dbPath) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var results: [AgentConversationSummary] = []
        let query = "SELECT conversation_id, title, created_at, updated_at FROM conversations ORDER BY updated_at DESC LIMIT 100;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idStr = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? UUID().uuidString
                let rawTitle = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? "Marvis Conversation"
                let createdStr = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
                let updatedStr = sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) }

                results.append(AgentConversationSummary(
                    id: idStr,
                    title: rawTitle,
                    createdAt: createdStr.flatMap { parseDate($0) },
                    updatedAt: updatedStr.flatMap { parseDate($0) },
                    mode: "marvis",
                    messageCount: nil,
                    snippet: nil
                ))
            }
        }
        return results
    }

    /// Reads conversation records from generic SQLite databases by probing common schemas
    public static func readGenericConversations(dbPath: String) -> [AgentConversationSummary] {
        guard isSQLiteFile(atPath: dbPath) else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        // Find available table names
        var tables: Set<String> = []
        let tableQuery = "SELECT name FROM sqlite_master WHERE type='table';"
        var tableStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, tableQuery, -1, &tableStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(tableStmt) }
            while sqlite3_step(tableStmt) == SQLITE_ROW {
                if let name = sqlite3_column_text(tableStmt, 0).flatMap({ String(cString: $0) }) {
                    tables.insert(name)
                }
            }
        }

        // Table priority order
        let candidateTables = ["chats", "conversations", "chat_sessions", "chat_session", "sessions", "threads", "messages"]
        for targetTable in candidateTables {
            guard tables.contains(targetTable) else { continue }
            // Probe columns
            let colQuery = "PRAGMA table_info(\(targetTable));"
            var colStmt: OpaquePointer?
            var colNames: [String] = []
            if sqlite3_prepare_v2(db, colQuery, -1, &colStmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(colStmt) }
                while sqlite3_step(colStmt) == SQLITE_ROW {
                    if let colName = sqlite3_column_text(colStmt, 1).flatMap({ String(cString: $0) }) {
                        colNames.append(colName.lowercased())
                    }
                }
            }

            let idCol = colNames.first { ["id", "conversation_id", "session_id", "chat_id", "uuid"].contains($0) }
            let titleCol = colNames.first { ["title", "name", "session_title", "topic", "preview", "summary", "subject"].contains($0) }
            let createdCol = colNames.first { ["created_at", "createdat", "create_time", "gmt_create", "timestamp", "time"].contains($0) }
            let updatedCol = colNames.first { ["updated_at", "updatedat", "update_time", "last_updated", "gmt_modified", "last_modified"].contains($0) }

            guard idCol != nil || titleCol != nil else { continue }

            let selectId = idCol ?? "ROWID"
            let selectTitle = titleCol ?? "'Session'"
            let selectCreated = createdCol ?? "NULL"
            let selectUpdated = updatedCol ?? "NULL"
            let orderCol = updatedCol ?? createdCol ?? selectId

            let selectQuery = "SELECT \(selectId), \(selectTitle), \(selectCreated), \(selectUpdated) FROM \(targetTable) ORDER BY \(orderCol) DESC LIMIT 100;"
            var stmt: OpaquePointer?
            var list: [AgentConversationSummary] = []
            if sqlite3_prepare_v2(db, selectQuery, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let idStr = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? UUID().uuidString
                    let rawTitle = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) } ?? "Conversation"
                    let createdStr = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
                    let updatedStr = sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) }

                    let createdDate: Date? = {
                        guard let s = createdStr else { return nil }
                        if let ms = Double(s), ms > 1_000_000_000 {
                            return ms > 10_000_000_000 ? Date(timeIntervalSince1970: ms / 1000.0) : Date(timeIntervalSince1970: ms)
                        }
                        return parseDate(s)
                    }()

                    let updatedDate: Date? = {
                        guard let s = updatedStr else { return nil }
                        if let ms = Double(s), ms > 1_000_000_000 {
                            return ms > 10_000_000_000 ? Date(timeIntervalSince1970: ms / 1000.0) : Date(timeIntervalSince1970: ms)
                        }
                        return parseDate(s)
                    }()

                    list.append(AgentConversationSummary(
                        id: idStr,
                        title: rawTitle.isEmpty ? "Conversation" : rawTitle,
                        createdAt: createdDate,
                        updatedAt: updatedDate,
                        mode: targetTable,
                        messageCount: nil,
                        snippet: nil
                    ))
                }
            }
            if !list.isEmpty {
                return list
            }
        }

        // Try reading ItemTable if available
        if tables.contains("ItemTable") {
            let itemConvs = readCursorConversations(dbPath: dbPath)
            if !itemConvs.isEmpty { return itemConvs }
        }

        return []
    }

    /// Date parsing helper for SQLite date strings (ISO8601 or standard date formats)
    public static func parseDate(_ string: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFormatter.date(from: string) { return d }
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let d = isoFormatter.date(from: string) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-ddTHH:mm:ss", "yyyy-MM-dd"] {
            df.dateFormat = fmt
            if let d = df.date(from: string) { return d }
        }
        return nil
    }
}

