import Foundation
import SQLite3

/// An identified missing / moved project directory referenced by historic AI sessions.
public struct MissingProjectItem: Identifiable, Sendable, Codable, Equatable {
    public var id: String { originalDirectory }
    public let originalDirectory: String
    public let sessionCount: Int
    public let lastActiveDate: Date?

    public init(
        originalDirectory: String,
        sessionCount: Int,
        lastActiveDate: Date? = nil
    ) {
        self.originalDirectory = originalDirectory
        self.sessionCount = sessionCount
        self.lastActiveDate = lastActiveDate
    }
}

/// Engine to inspect and remap project directories when local repositories are moved or renamed.
public enum AgentRelocation {

    /// Scans the target database for sessions pointing to directories that no longer exist on disk.
    public static func findMissingProjects(
        dbPath: String,
        editor: AgentEditorKind
    ) -> [MissingProjectItem] {
        guard AgentSQLiteReader.isSQLiteFile(atPath: dbPath) else { return [] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        var results: [MissingProjectItem] = []
        let fm = FileManager.default

        switch editor {
        case .openCode, .miniMax:
            let sql = """
            SELECT directory, count(*), max(time_updated)
            FROM session
            WHERE directory IS NOT NULL AND directory != ''
            GROUP BY directory;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(stmt) }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    guard let dirC = sqlite3_column_text(stmt, 0) else { continue }
                    let dir = String(cString: dirC)
                    let count = Int(sqlite3_column_int(stmt, 1))
                    let updatedMs = sqlite3_column_int64(stmt, 2)
                    let date = updatedMs > 0 ? Date(timeIntervalSince1970: Double(updatedMs) / 1000.0) : nil

                    if !fm.fileExists(atPath: dir) {
                        results.append(MissingProjectItem(
                            originalDirectory: dir,
                            sessionCount: count,
                            lastActiveDate: date
                        ))
                    }
                }
            }
        default:
            break
        }

        return results.sorted { $0.sessionCount > $1.sessionCount }
    }

    /// Remaps all sessions and workspace records from `oldDirectory` to `newDirectory`.
    @discardableResult
    public static func relocateProject(
        dbPath: String,
        editor: AgentEditorKind,
        oldDirectory: String,
        newDirectory: String
    ) throws -> Int {
        let fm = FileManager.default
        guard fm.fileExists(atPath: newDirectory) else {
            throw VacuumError.sqliteError(message: "新目标目录在磁盘上不存在: \(newDirectory)")
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            throw VacuumError.sqliteError(message: "无法以读写模式打开数据库")
        }
        defer { sqlite3_close(db) }

        _ = sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil)
        var totalUpdated = 0

        switch editor {
        case .openCode, .miniMax:
            // 1. Update session table
            let sqlSession = "UPDATE session SET directory = ? WHERE directory = ?;"
            var stmt1: OpaquePointer?
            if sqlite3_prepare_v2(db, sqlSession, -1, &stmt1, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt1, 1, (newDirectory as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt1, 2, (oldDirectory as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt1) == SQLITE_DONE {
                    totalUpdated += Int(sqlite3_changes(db))
                }
                sqlite3_finalize(stmt1)
            }

            // 2. Update project_directory table if exists
            let sqlPD = "UPDATE project_directory SET directory = ? WHERE directory = ?;"
            var stmt2: OpaquePointer?
            if sqlite3_prepare_v2(db, sqlPD, -1, &stmt2, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt2, 1, (newDirectory as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt2, 2, (oldDirectory as NSString).utf8String, -1, nil)
                _ = sqlite3_step(stmt2)
                sqlite3_finalize(stmt2)
            }

        default:
            break
        }

        _ = sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        return totalUpdated
    }
}
