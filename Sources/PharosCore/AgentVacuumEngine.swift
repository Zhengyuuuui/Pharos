import Foundation
import SQLite3

/// Snapshot metadata of a pre-flight database backup.
public struct AgentBackupSnapshot: Identifiable, Sendable, Codable, Equatable {
    public var id: String { backupPath }
    public let backupPath: String
    public let originalDbPath: String
    public let fileSizeBytes: UInt64
    public let createdAt: Date
    public let hasWal: Bool

    public init(
        backupPath: String,
        originalDbPath: String,
        fileSizeBytes: UInt64,
        createdAt: Date,
        hasWal: Bool
    ) {
        self.backupPath = backupPath
        self.originalDbPath = originalDbPath
        self.fileSizeBytes = fileSizeBytes
        self.createdAt = createdAt
        self.hasWal = hasWal
    }
}

/// Errors occurring during process check, compaction, or vacuum.
public enum VacuumError: LocalizedError, Equatable {
    case editorRunning(editor: AgentEditorKind, pids: [Int32])
    case databaseNotFound(path: String)
    case sqliteError(message: String)
    case backupFailed(reason: String)
    case restoreFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .editorRunning(let editor, let pids):
            let pidsStr = pids.map(String.init).joined(separator: ", ")
            return "检测到 \(editor.displayName) 客户端正在运行 (PID: \(pidsStr))，为保证数据一致性与避免锁死，请先完全退出客户端。"
        case .databaseNotFound(let path):
            return "未找到目标数据库文件：\(path)"
        case .sqliteError(let msg):
            return "SQLite 执行异常：\(msg)"
        case .backupFailed(let reason):
            return "前置安全备份创建失败：\(reason)"
        case .restoreFailed(let reason):
            return "数据库还原失败：\(reason)"
        }
    }
}

/// Guard preventing write operations on SQLite databases while the host editor is running.
public enum ProcessExclusivityGuard {

    /// Checks whether the target editor is running among the given process snapshots.
    /// If `processes` is nil, scans currently running processes via `ProcessScanner`.
    public static func check(
        editor: AgentEditorKind,
        processes: [ProcessSnapshot]? = nil
    ) -> (isRunning: Bool, pids: [Int32]) {
        let procs = processes ?? ProcessScanner.scan()
        var runningPIDs: [Int32] = []

        let targetNames = Set(editor.appNames.map { ($0 as NSString).deletingPathExtension.lowercased() })
        let targetBundles = Set(editor.bundleIdentifiers.map { $0.lowercased() })

        for p in procs {
            let procNameLower = p.name.lowercased()
            let exeLower = (p.executablePath ?? "").lowercased()

            // Match by app name
            let nameMatch = targetNames.contains(where: {
                procNameLower == $0 || procNameLower.hasPrefix($0) || exeLower.contains("/\($0).app/")
            })

            // Match by bundle identifier in path
            let bundleMatch = targetBundles.contains(where: {
                exeLower.contains($0)
            })

            if nameMatch || bundleMatch {
                runningPIDs.append(p.pid)
            }
        }

        let deduped = Array(Set(runningPIDs)).sorted()
        return (!deduped.isEmpty, deduped)
    }
}

/// Engine executing pre-flight backup, WAL checkpoint, transactional delete, and VACUUM disk shrinkage.
public enum AgentVacuumEngine {

    // MARK: - Pre-flight Backup & Restore

    private static let backupDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    /// Creates a pre-flight backup named `<dbPath>.pharos_bak_<timestamp>.db`.
    /// Also copies companion `-wal` if it exists.
    @discardableResult
    public static func createPreflightBackup(for dbPath: String) throws -> String {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dbPath) else {
            throw VacuumError.databaseNotFound(path: dbPath)
        }

        let timestamp = backupDateFormatter.string(from: Date())
        var backupPath = "\(dbPath).pharos_bak_\(timestamp).db"
        if fm.fileExists(atPath: backupPath) {
            let nano = DispatchTime.now().uptimeNanoseconds % 1_000_000
            backupPath = "\(dbPath).pharos_bak_\(timestamp)_\(nano).db"
        }

        do {
            if fm.fileExists(atPath: backupPath) {
                try? fm.removeItem(atPath: backupPath)
            }
            try fm.copyItem(atPath: dbPath, toPath: backupPath)
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: backupPath)
            let walPath = dbPath + "-wal"
            let backupWal = "\(backupPath)-wal"
            if fm.fileExists(atPath: backupWal) {
                try? fm.removeItem(atPath: backupWal)
            }
            if fm.fileExists(atPath: walPath) {
                try? fm.copyItem(atPath: walPath, toPath: backupWal)
                try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: backupWal)
            }
        } catch {
            throw VacuumError.backupFailed(reason: error.localizedDescription)
        }

        // Clean older backups, keeping only the latest 1 snapshot to minimize disk footprint
        pruneOldBackups(for: dbPath, keepCount: 1)

        return backupPath
    }

    /// Lists all available `.pharos_bak` backups for a given database.
    public static func listBackups(for dbPath: String) -> [AgentBackupSnapshot] {
        let fm = FileManager.default
        let dir = (dbPath as NSString).deletingLastPathComponent
        let dbFileName = (dbPath as NSString).lastPathComponent

        guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        var result: [AgentBackupSnapshot] = []

        let prefix = "\(dbFileName).pharos_bak_"
        for f in files where f.hasPrefix(prefix) && f.hasSuffix(".db") && !f.hasSuffix("-wal") && !f.hasSuffix("-shm") {
            let fullPath = "\(dir)/\(f)"
            var st = stat()
            guard fullPath.withCString({ stat($0, &st) }) == 0 else { continue }
            let size = UInt64(st.st_size)
            let mtimeSec = TimeInterval(st.st_mtimespec.tv_sec) + TimeInterval(st.st_mtimespec.tv_nsec) / 1_000_000_000.0
            let date = Date(timeIntervalSince1970: mtimeSec)
            let hasWal = fm.fileExists(atPath: fullPath + "-wal")

            result.append(AgentBackupSnapshot(
                backupPath: fullPath,
                originalDbPath: dbPath,
                fileSizeBytes: size,
                createdAt: date,
                hasWal: hasWal
            ))
        }

        return result.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.backupPath > $1.backupPath
        }
    }

    /// Prunes older backup snapshots beyond the specified keep limit (defaults to 1 latest backup).
    public static func pruneOldBackups(for dbPath: String, keepCount: Int = 1) {
        let backups = listBackups(for: dbPath)
        guard backups.count > keepCount else { return }

        let fm = FileManager.default
        let toRemove = backups.suffix(from: keepCount)
        for b in toRemove {
            try? fm.removeItem(atPath: b.backupPath)
            try? fm.removeItem(atPath: b.backupPath + "-wal")
            try? fm.removeItem(atPath: b.backupPath + "-shm")
        }
    }

    /// Safely restores the database from a specified backup file.
    public static func restoreBackup(from backupPath: String, to dbPath: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupPath) else {
            throw VacuumError.restoreFailed(reason: "备份文件不存在: \(backupPath)")
        }

        do {
            if fm.fileExists(atPath: dbPath) {
                try fm.removeItem(atPath: dbPath)
            }
            try fm.copyItem(atPath: backupPath, toPath: dbPath)

            let dbWal = dbPath + "-wal"
            let dbShm = dbPath + "-shm"
            if fm.fileExists(atPath: dbWal) { try? fm.removeItem(atPath: dbWal) }
            if fm.fileExists(atPath: dbShm) { try? fm.removeItem(atPath: dbShm) }

            let backupWal = backupPath + "-wal"
            if fm.fileExists(atPath: backupWal) {
                try? fm.copyItem(atPath: backupWal, toPath: dbWal)
            }
        } catch {
            throw VacuumError.restoreFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Full Compaction & Vacuum Pipeline

    /// Executes the full safe compaction lifecycle:
    /// 1. Exclusivity check
    /// 2. Pre-flight backup
    /// 3. WAL Checkpoint
    /// 4. Transactional deletion
    /// 5. VACUUM physical disk reclaim
    public static func compactAndVacuum(
        dbPath: String,
        editor: AgentEditorKind,
        options: CompactionOptions,
        processes: [ProcessSnapshot]? = nil
    ) throws -> CompactionResult {
        let startTime = Date()

        // 1. Process exclusivity check
        let (isRunning, pids) = ProcessExclusivityGuard.check(editor: editor, processes: processes)
        if isRunning {
            throw VacuumError.editorRunning(editor: editor, pids: pids)
        }

        // Measure initial physical size
        let initialSize = measurePhysicalSize(dbPath: dbPath)

        // 2. Pre-flight backup
        var backupPath: String? = nil
        if options.autoBackup {
            backupPath = try createPreflightBackup(for: dbPath)
        }

        // 3. Open DB in Read-Write mode
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            let errMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "无法以读写模式打开数据库"
            throw VacuumError.sqliteError(message: errMsg)
        }
        defer { sqlite3_close(db) }

        // 4. WAL Checkpoint (TRUNCATE)
        _ = execSQL(db, sql: "PRAGMA wal_checkpoint(TRUNCATE);")

        // 5. Transactional Deletion
        let sqls = AgentCompactor.deletionSQL(for: editor, options: options)
        var totalDeleted: Int64 = 0

        if !sqls.isEmpty {
            _ = execSQL(db, sql: "BEGIN IMMEDIATE;")
            for sql in sqls {
                var errPtr: UnsafeMutablePointer<CChar>?
                if sqlite3_exec(db, (sql as NSString).utf8String, nil, nil, &errPtr) != SQLITE_OK {
                    let err = errPtr.flatMap { String(cString: $0) } ?? "SQL执行失败"
                    sqlite3_free(errPtr)
                    _ = execSQL(db, sql: "ROLLBACK;")
                    throw VacuumError.sqliteError(message: err)
                }
                totalDeleted += Int64(sqlite3_changes(db))
            }
            _ = execSQL(db, sql: "COMMIT;")
        }

        // 6. Native VACUUM
        if options.vacuumAfter {
            var errPtr: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, "VACUUM;", nil, nil, &errPtr) != SQLITE_OK {
                let err = errPtr.flatMap { String(cString: $0) } ?? "VACUUM执行失败"
                sqlite3_free(errPtr)
                throw VacuumError.sqliteError(message: err)
            }
            _ = execSQL(db, sql: "PRAGMA wal_checkpoint(TRUNCATE);")
        }

        // Measure final physical size
        sqlite3_close(db)
        db = nil // defer closed guard

        let finalSize = measurePhysicalSize(dbPath: dbPath)
        let duration = Date().timeIntervalSince(startTime)

        return CompactionResult(
            dbPath: dbPath,
            initialSizeBytes: initialSize,
            finalSizeBytes: finalSize,
            deletedCount: totalDeleted,
            backupPath: backupPath,
            duration: duration
        )
    }

    private static func measurePhysicalSize(dbPath: String) -> UInt64 {
        var total: UInt64 = 0
        var st = stat()
        if dbPath.withCString({ stat($0, &st) }) == 0 {
            total += UInt64(st.st_size)
        }
        let walPath = dbPath + "-wal"
        var walSt = stat()
        if walPath.withCString({ stat($0, &walSt) }) == 0 {
            total += UInt64(walSt.st_size)
        }
        return total
    }

    @discardableResult
    private static func execSQL(_ db: OpaquePointer?, sql: String) -> Bool {
        sqlite3_exec(db, (sql as NSString).utf8String, nil, nil, nil) == SQLITE_OK
    }
}
