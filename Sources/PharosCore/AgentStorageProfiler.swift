import Foundation
import SQLite3

/// Detail of space occupied by an individual table inside an AI agent SQLite database.
public struct TableSpaceItem: Identifiable, Sendable, Codable, Equatable {
    public var id: String { name }
    public let name: String
    public let rowCount: Int64
    public let payloadBytes: UInt64
    public let percentage: Double
    public let isBloatCandidate: Bool
    public let descriptionText: String?

    public init(
        name: String,
        rowCount: Int64,
        payloadBytes: UInt64,
        percentage: Double,
        isBloatCandidate: Bool = false,
        descriptionText: String? = nil
    ) {
        self.name = name
        self.rowCount = rowCount
        self.payloadBytes = payloadBytes
        self.percentage = percentage
        self.isBloatCandidate = isBloatCandidate
        self.descriptionText = descriptionText
    }
}

/// Represents one of the heaviest conversation sessions in the database.
public struct TopSessionItem: Identifiable, Sendable, Codable, Equatable {
    public let id: String
    public let title: String
    public let messageCount: Int
    public let sizeBytes: UInt64
    public let updatedAt: Date?

    public init(
        id: String,
        title: String,
        messageCount: Int,
        sizeBytes: UInt64,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.messageCount = messageCount
        self.sizeBytes = sizeBytes
        self.updatedAt = updatedAt
    }
}

/// In-depth diagnostic profile of an AI agent SQLite database.
public struct AgentDatabaseProfile: Identifiable, Sendable, Codable, Equatable {
    public var id: String { dbPath }
    public let dbPath: String
    public let editor: AgentEditorKind
    public let fileSizeBytes: UInt64
    public let walSizeBytes: UInt64
    public let totalPhysicalBytes: UInt64
    public let pageSize: Int
    public let pageCount: Int64
    public let freelistCount: Int64
    public let freelistBytes: UInt64
    public let fragmentationRatio: Double
    public let tableBreakdown: [TableSpaceItem]
    public let topHeavySessions: [TopSessionItem]
    public let reclaimableBytes: UInt64
    public let healthScore: Int // 0 (worst) to 100 (best)
    public let scannedAt: Date

    public var isHeavilyBloated: Bool {
        healthScore < 60 || reclaimableBytes > 500 * 1024 * 1024
    }

    public init(
        dbPath: String,
        editor: AgentEditorKind,
        fileSizeBytes: UInt64,
        walSizeBytes: UInt64 = 0,
        pageSize: Int,
        pageCount: Int64,
        freelistCount: Int64,
        tableBreakdown: [TableSpaceItem],
        topHeavySessions: [TopSessionItem],
        reclaimableBytes: UInt64,
        healthScore: Int,
        scannedAt: Date = Date()
    ) {
        self.dbPath = dbPath
        self.editor = editor
        self.fileSizeBytes = fileSizeBytes
        self.walSizeBytes = walSizeBytes
        self.totalPhysicalBytes = fileSizeBytes + walSizeBytes
        self.pageSize = pageSize
        self.pageCount = pageCount
        self.freelistCount = freelistCount
        self.freelistBytes = UInt64(max(0, freelistCount)) * UInt64(max(0, pageSize))
        self.fragmentationRatio = pageCount > 0 ? (Double(freelistCount) / Double(pageCount) * 100.0) : 0.0
        self.tableBreakdown = tableBreakdown
        self.topHeavySessions = topHeavySessions
        self.reclaimableBytes = reclaimableBytes
        self.healthScore = max(0, min(100, healthScore))
        self.scannedAt = scannedAt
    }
}

/// Engine to inspect the internal tables, freelist holes, and heavy sessions of an AI agent SQLite database.
public enum AgentStorageProfiler {

    /// Inspects the target database file and returns a detailed storage profile.
    public static func profile(dbPath: String, editor: AgentEditorKind) -> AgentDatabaseProfile? {
        guard AgentSQLiteReader.isSQLiteFile(atPath: dbPath) else { return nil }

        var st = stat()
        guard dbPath.withCString({ stat($0, &st) }) == 0 else { return nil }
        let mainSize = UInt64(st.st_size)

        var walSize: UInt64 = 0
        let walPath = dbPath + "-wal"
        var walSt = stat()
        if walPath.withCString({ stat($0, &walSt) }) == 0 {
            walSize = UInt64(walSt.st_size)
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let pageSize = queryInt(db, sql: "PRAGMA page_size;") ?? 4096
        let pageCount = queryInt64(db, sql: "PRAGMA page_count;") ?? Int64(mainSize / UInt64(max(1, pageSize)))
        let freelistCount = queryInt64(db, sql: "PRAGMA freelist_count;") ?? 0
        let freelistBytes = UInt64(max(0, freelistCount)) * UInt64(max(0, pageSize))

        var tables: [TableSpaceItem] = []
        var topSessions: [TopSessionItem] = []
        var reclaimable: UInt64 = freelistBytes

        switch editor {
        case .openCode, .miniMax:
            profileOpenCode(db: db, mainSize: mainSize, tables: &tables, topSessions: &topSessions, reclaimable: &reclaimable)
        case .cursor:
            profileCursor(db: db, mainSize: mainSize, tables: &tables, topSessions: &topSessions, reclaimable: &reclaimable)
        default:
            profileGeneric(db: db, mainSize: mainSize, tables: &tables, reclaimable: &reclaimable)
        }

        // Calculate health score:
        // Starts at 100.
        // If file > 500MB, subtract points for reclaimable ratio.
        var score = 100
        let totalBytes = mainSize + walSize
        if totalBytes > 100 * 1024 * 1024 { // > 100 MB
            let reclaimRatio = Double(reclaimable) / Double(max(1, totalBytes))
            if reclaimRatio > 0.8 {
                score -= 60
            } else if reclaimRatio > 0.5 {
                score -= 40
            } else if reclaimRatio > 0.25 {
                score -= 20
            }

            if totalBytes > 3 * 1024 * 1024 * 1024 { // > 3 GB
                score -= 25
            } else if totalBytes > 1024 * 1024 * 1024 { // > 1 GB
                score -= 15
            }
        }

        return AgentDatabaseProfile(
            dbPath: dbPath,
            editor: editor,
            fileSizeBytes: mainSize,
            walSizeBytes: walSize,
            pageSize: pageSize,
            pageCount: pageCount,
            freelistCount: freelistCount,
            tableBreakdown: tables,
            topHeavySessions: topSessions,
            reclaimableBytes: reclaimable,
            healthScore: max(10, score)
        )
    }

    // MARK: - Editor Specific Profiling

    private static func profileOpenCode(
        db: OpaquePointer?,
        mainSize: UInt64,
        tables: inout [TableSpaceItem],
        topSessions: inout [TopSessionItem],
        reclaimable: inout UInt64
    ) {
        // 1. Analyze `event` table (the primary bloat source in OpenCode)
        var eventCount: Int64 = 0
        var eventPayload: UInt64 = 0
        var streamBloatBytes: UInt64 = 0
        var streamBloatCount: Int64 = 0

        if tableExists(db, name: "event") {
            eventCount = queryInt64(db, sql: "SELECT count(*) FROM event;") ?? 0
            eventPayload = queryUInt64(db, sql: "SELECT coalesce(sum(length(data)), 0) FROM event;") ?? 0

            // Intermediate streaming events
            let streamSql = "SELECT count(*), coalesce(sum(length(data)), 0) FROM event WHERE type LIKE 'message.part.updated%' OR type LIKE 'message.updated%' OR type LIKE 'session.updated%';"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, streamSql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    streamBloatCount = sqlite3_column_int64(stmt, 0)
                    streamBloatBytes = UInt64(max(0, sqlite3_column_int64(stmt, 1)))
                }
                sqlite3_finalize(stmt)
            }
        }

        reclaimable += streamBloatBytes

        // 2. Analyze `part` table (actual message blocks)
        var partCount: Int64 = 0
        var partPayload: UInt64 = 0
        if tableExists(db, name: "part") {
            partCount = queryInt64(db, sql: "SELECT count(*) FROM part;") ?? 0
            partPayload = queryUInt64(db, sql: "SELECT coalesce(sum(length(data)), 0) FROM part;") ?? 0
        }

        // 3. Analyze `message` table
        var msgCount: Int64 = 0
        if tableExists(db, name: "message") {
            msgCount = queryInt64(db, sql: "SELECT count(*) FROM message;") ?? 0
        }

        // 4. Analyze `session` table
        var sessionCount: Int64 = 0
        if tableExists(db, name: "session") {
            sessionCount = queryInt64(db, sql: "SELECT count(*) FROM session;") ?? 0
        }

        let totalPayload = max(1, eventPayload + partPayload)
        if eventCount > 0 {
            let pct = Double(eventPayload) / Double(totalPayload) * 100.0
            tables.append(TableSpaceItem(
                name: "event (流式渲染与过程事件)",
                rowCount: eventCount,
                payloadBytes: eventPayload,
                percentage: pct,
                isBloatCandidate: streamBloatCount > 0,
                descriptionText: "包含 \(streamBloatCount) 条无损可剥离的前端打字机渲染增量事件"
            ))
        }

        if partCount > 0 {
            let pct = Double(partPayload) / Double(totalPayload) * 100.0
            tables.append(TableSpaceItem(
                name: "part (有效对话文本与代码)",
                rowCount: partCount,
                payloadBytes: partPayload,
                percentage: pct,
                isBloatCandidate: false,
                descriptionText: "核心对话结果与代码快照，瘦身时 100% 完整保留"
            ))
        }

        if msgCount > 0 {
            tables.append(TableSpaceItem(
                name: "message (会话消息元数据)",
                rowCount: msgCount,
                payloadBytes: UInt64(msgCount * 128),
                percentage: 1.0,
                isBloatCandidate: false
            ))
        }

        if sessionCount > 0 {
            tables.append(TableSpaceItem(
                name: "session (会话主题列表)",
                rowCount: sessionCount,
                payloadBytes: UInt64(sessionCount * 256),
                percentage: 0.5,
                isBloatCandidate: false
            ))
        }

        // 5. Query Top Heavy Sessions
        let topSql = """
        SELECT s.id, s.title, s.time_updated, count(p.id) as part_count, coalesce(sum(length(p.data)), 0) as size
        FROM session s
        LEFT JOIN part p ON p.session_id = s.id
        GROUP BY s.id
        ORDER BY size DESC
        LIMIT 10;
        """
        var topStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, topSql, -1, &topStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(topStmt) }
            while sqlite3_step(topStmt) == SQLITE_ROW {
                let idStr = sqlite3_column_text(topStmt, 0).flatMap { String(cString: $0) } ?? ""
                let rawTitle = sqlite3_column_text(topStmt, 1).flatMap { String(cString: $0) } ?? "Untitled Session"
                let updatedMs = sqlite3_column_int64(topStmt, 2)
                let partCount = Int(sqlite3_column_int(topStmt, 3))
                let sizeBytes = UInt64(max(0, sqlite3_column_int64(topStmt, 4)))

                let date = updatedMs > 0 ? Date(timeIntervalSince1970: Double(updatedMs) / 1000.0) : nil
                topSessions.append(TopSessionItem(
                    id: idStr,
                    title: rawTitle.isEmpty ? "Session" : rawTitle,
                    messageCount: partCount,
                    sizeBytes: sizeBytes,
                    updatedAt: date
                ))
            }
        }
    }

    private static func profileCursor(
        db: OpaquePointer?,
        mainSize: UInt64,
        tables: inout [TableSpaceItem],
        topSessions: inout [TopSessionItem],
        reclaimable: inout UInt64
    ) {
        if tableExists(db, name: "cursorDiskKV") {
            let sql = "SELECT substr(key, 1, instr(key || ':', ':')) as prefix, count(*), coalesce(sum(length(value)), 0) FROM cursorDiskKV GROUP BY prefix ORDER BY sum(length(value)) DESC;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let prefix = sqlite3_column_text(stmt, 0).flatMap { String(cString: $0) } ?? "other"
                    let count = sqlite3_column_int64(stmt, 1)
                    let bytes = UInt64(max(0, sqlite3_column_int64(stmt, 2)))

                    let isCandidate = prefix.hasPrefix("checkpointId") || prefix.hasPrefix("agentKv")
                    if isCandidate {
                        reclaimable += bytes
                    }

                    let pct = mainSize > 0 ? Double(bytes) / Double(mainSize) * 100.0 : 0
                    let desc = isCandidate ? "影子代码 Diff 与临时检查点（可安全裁剪）" : "活跃 Composer 对话或配置数据"
                    tables.append(TableSpaceItem(
                        name: "cursorDiskKV [\(prefix)]",
                        rowCount: count,
                        payloadBytes: bytes,
                        percentage: pct,
                        isBloatCandidate: isCandidate,
                        descriptionText: desc
                    ))
                }
            }
        }

        if tableExists(db, name: "composerHeaders") {
            let count = queryInt64(db, sql: "SELECT count(*) FROM composerHeaders;") ?? 0
            tables.append(TableSpaceItem(
                name: "composerHeaders (Composer 对话头)",
                rowCount: count,
                payloadBytes: UInt64(count * 512),
                percentage: 1.0,
                isBloatCandidate: false
            ))
        }

        if tableExists(db, name: "ItemTable") {
            let count = queryInt64(db, sql: "SELECT count(*) FROM ItemTable;") ?? 0
            let bytes = queryUInt64(db, sql: "SELECT coalesce(sum(length(value)), 0) FROM ItemTable;") ?? 0
            let pct = mainSize > 0 ? Double(bytes) / Double(mainSize) * 100.0 : 0
            tables.append(TableSpaceItem(
                name: "ItemTable (配置与历史项)",
                rowCount: count,
                payloadBytes: bytes,
                percentage: pct,
                isBloatCandidate: false
            ))
        }
    }

    private static func profileGeneric(
        db: OpaquePointer?,
        mainSize: UInt64,
        tables: inout [TableSpaceItem],
        reclaimable: inout UInt64
    ) {
        let sql = "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name ASC;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let nameC = sqlite3_column_text(stmt, 0) {
                    let tableName = String(cString: nameC)
                    let count = queryInt64(db, sql: "SELECT count(*) FROM `\(tableName)`;") ?? 0
                    tables.append(TableSpaceItem(
                        name: tableName,
                        rowCount: count,
                        payloadBytes: 0,
                        percentage: 0.0,
                        isBloatCandidate: false
                    ))
                }
            }
        }
    }

    // MARK: - SQLite Helpers

    private static func tableExists(_ db: OpaquePointer?, name: String) -> Bool {
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private static func queryInt(_ db: OpaquePointer?, sql: String) -> Int? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : nil
    }

    private static func queryInt64(_ db: OpaquePointer?, sql: String) -> Int64? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? sqlite3_column_int64(stmt, 0) : nil
    }

    private static func queryUInt64(_ db: OpaquePointer?, sql: String) -> UInt64? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? UInt64(max(0, sqlite3_column_int64(stmt, 0))) : nil
    }
}
