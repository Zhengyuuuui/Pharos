import Foundation
import SQLite3

/// Three-tier compaction level according to user safety appetite and data retention needs.
public enum CompactionLevel: Int, CaseIterable, Sendable, Codable {
    /// Level 1: Lossless Stream Compaction (Recommended)
    /// Strips transient streaming incremental ticks & typewriter events.
    /// Preserves 100% of session metadata, user prompts, assistant answers, and code blocks.
    case level1StreamEvents = 1

    /// Level 2: Shadow & Checkpoints Pruning
    /// Strips Level 1 events plus legacy shadow diff snapshots and KV checkpoints.
    case level2Checkpoints = 2

    /// Level 3: Orphaned Workspace & Deep Archive
    /// Level 2 plus cleans ghost sessions whose local project directories have been physically deleted.
    case level3OrphanedAndArchive = 3

    public var title: String {
        switch self {
        case .level1StreamEvents: return "Level 1: 无损流式事件剥离 (推荐)"
        case .level2Checkpoints: return "Level 2: 影子快照与检查点清理"
        case .level3OrphanedAndArchive: return "Level 3: 幽灵项目清理与深度归档"
        }
    }

    public var subtitle: String {
        switch self {
        case .level1StreamEvents:
            return "仅剔除打字机渲染增量与过程状态，完整保留所有问答文本与生成代码，界面打开完全如初。"
        case .level2Checkpoints:
            return "在 Level 1 基础上，进一步清理过期的代码影子 Diff 与 KV 缓存检查点。"
        case .level3OrphanedAndArchive:
            return "在 Level 2 基础上，清理已被物理删除项目的残留历史会话数据。"
        }
    }
}

/// User configurable options for executing database compaction.
public struct CompactionOptions: Sendable, Codable, Equatable {
    public var level: CompactionLevel
    public var autoBackup: Bool
    public var vacuumAfter: Bool
    public var daysOld: Int?

    public init(
        level: CompactionLevel = .level1StreamEvents,
        autoBackup: Bool = true,
        vacuumAfter: Bool = true,
        daysOld: Int? = nil
    ) {
        self.level = level
        self.autoBackup = autoBackup
        self.vacuumAfter = vacuumAfter
        self.daysOld = daysOld
    }
}

/// Result of an executed database compaction and vacuum operation.
public struct CompactionResult: Sendable, Codable, Equatable {
    public let dbPath: String
    public let initialSizeBytes: UInt64
    public let finalSizeBytes: UInt64
    public let bytesReclaimed: UInt64
    public let deletedCount: Int64
    public let backupPath: String?
    public let duration: TimeInterval
    public let timestamp: Date

    public var reclaimedPercentage: Double {
        initialSizeBytes > 0 ? (Double(bytesReclaimed) / Double(initialSizeBytes) * 100.0) : 0.0
    }

    public init(
        dbPath: String,
        initialSizeBytes: UInt64,
        finalSizeBytes: UInt64,
        deletedCount: Int64,
        backupPath: String? = nil,
        duration: TimeInterval = 0,
        timestamp: Date = Date()
    ) {
        self.dbPath = dbPath
        self.initialSizeBytes = initialSizeBytes
        self.finalSizeBytes = finalSizeBytes
        self.bytesReclaimed = initialSizeBytes > finalSizeBytes ? (initialSizeBytes - finalSizeBytes) : 0
        self.deletedCount = deletedCount
        self.backupPath = backupPath
        self.duration = duration
        self.timestamp = timestamp
    }
}

/// Pure engine generating and executing targeted compaction SQL for AI agent databases.
public enum AgentCompactor {

    /// Generates targeted SQL delete statements for the given editor and compaction level.
    public static func deletionSQL(for editor: AgentEditorKind, options: CompactionOptions) -> [String] {
        switch editor {
        case .openCode, .miniMax:
            var statements: [String] = []
            switch options.level {
            case .level1StreamEvents:
                statements.append("""
                DELETE FROM event
                WHERE type LIKE 'message.part.updated%'
                   OR type LIKE 'message.updated%'
                   OR type LIKE 'session.updated%';
                """)
            case .level2Checkpoints:
                statements.append("""
                DELETE FROM event
                WHERE type LIKE 'message.part.updated%'
                   OR type LIKE 'message.updated%'
                   OR type LIKE 'session.updated%'
                   OR type LIKE 'message.removed%';
                """)
                if let days = options.daysOld, days > 0 {
                    let cutoffMs = Int64((Date().timeIntervalSince1970 - Double(days * 86400)) * 1000.0)
                    statements.append("""
                    DELETE FROM event
                    WHERE time_created < \(cutoffMs);
                    """)
                }
            case .level3OrphanedAndArchive:
                statements.append("""
                DELETE FROM event
                WHERE type LIKE 'message.part.updated%'
                   OR type LIKE 'message.updated%'
                   OR type LIKE 'session.updated%'
                   OR type LIKE 'message.removed%';
                """)
            }
            return statements

        case .cursor:
            var statements: [String] = []
            switch options.level {
            case .level1StreamEvents:
                statements.append("""
                DELETE FROM cursorDiskKV
                WHERE key LIKE 'agentKv:%';
                """)
            case .level2Checkpoints, .level3OrphanedAndArchive:
                statements.append("""
                DELETE FROM cursorDiskKV
                WHERE key LIKE 'agentKv:%'
                   OR key LIKE 'checkpointId:%'
                   OR key LIKE 'codeBlockPartialInlineDiffFates:%';
                """)
            }
            return statements

        default:
            return []
        }
    }
}
