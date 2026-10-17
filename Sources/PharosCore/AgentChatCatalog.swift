import Foundation

/// Per-editor rollup of detected databases, computed once per scan instead of on every render.
public struct AgentEditorSummary: Identifiable, Equatable {
    public let editor: AgentEditorKind
    public let totalBytes: UInt64
    public let databaseCount: Int
    public let conversationCount: Int
    public let workspaceBytes: UInt64
    public let globalBytes: UInt64
    public let cacheBytes: UInt64
    public let orphanedCount: Int
    public let lastModified: Date?

    public var id: String { editor.rawValue }
}

/// A conversation together with the database it was read from, so merged lists can say where each row lives.
public struct AgentConversationRef: Identifiable, Equatable {
    public let conversation: AgentConversationSummary
    public let entryId: String
    public let databaseName: String
    public let databasePath: String
    public let scope: AgentDatabaseScope

    public init(conversation: AgentConversationSummary, entryId: String, databaseName: String, databasePath: String, scope: AgentDatabaseScope) {
        self.conversation = conversation
        self.entryId = entryId
        self.databaseName = databaseName
        self.databasePath = databasePath
        self.scope = scope
    }

    public var id: String { "\(entryId)#\(conversation.id)" }
    public var sortDate: Date? { conversation.updatedAt ?? conversation.createdAt }
}

public enum AgentChatSortOrder: String, CaseIterable, Identifiable, Sendable {
    case sizeDesc
    case mtimeDesc
    case nameAsc
    public var id: String { rawValue }
}

public enum AgentChatCatalog {
    /// Readers cap each database at this many sessions (`LIMIT 100` in AgentSQLiteReader).
    public static let readerConversationCap = 100

    public static func summarize(_ entries: [AgentDatabaseEntry]) -> [AgentEditorSummary] {
        var groups: [AgentEditorKind: [AgentDatabaseEntry]] = [:]
        for e in entries { groups[e.editor, default: []].append(e) }
        return groups.map { editor, list in
            var total: UInt64 = 0, ws: UInt64 = 0, glob: UInt64 = 0, cache: UInt64 = 0
            var convs = 0, orphaned = 0
            var latest: Date?
            for e in list {
                total += e.fileSizeBytes
                switch e.scope {
                case .workspace: ws += e.fileSizeBytes
                case .global: glob += e.fileSizeBytes
                case .vectorCache: cache += e.fileSizeBytes
                }
                convs += e.conversationCount
                if e.isOrphaned { orphaned += 1 }
                if latest.map({ e.lastModified > $0 }) ?? true { latest = e.lastModified }
            }
            return AgentEditorSummary(
                editor: editor, totalBytes: total, databaseCount: list.count, conversationCount: convs,
                workspaceBytes: ws, globalBytes: glob, cacheBytes: cache, orphanedCount: orphaned, lastModified: latest
            )
        }
        .sorted { $0.totalBytes != $1.totalBytes ? $0.totalBytes > $1.totalBytes : $0.editor.rawValue < $1.editor.rawValue }
    }

    public static func matches(_ entry: AgentDatabaseEntry, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        if entry.workspaceName.lowercased().contains(q) { return true }
        if entry.workspacePath?.lowercased().contains(q) ?? false { return true }
        if entry.filePath.lowercased().contains(q) { return true }
        return entry.conversations.contains { matches($0, query: q) }
    }

    public static func matches(_ conversation: AgentConversationSummary, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return conversation.title.lowercased().contains(q) || (conversation.snippet?.lowercased().contains(q) ?? false)
    }

    public static func sorted(_ entries: [AgentDatabaseEntry], by order: AgentChatSortOrder) -> [AgentDatabaseEntry] {
        entries.sorted { a, b in
            switch order {
            case .sizeDesc: return a.fileSizeBytes != b.fileSizeBytes ? a.fileSizeBytes > b.fileSizeBytes : a.id < b.id
            case .mtimeDesc: return a.lastModified != b.lastModified ? a.lastModified > b.lastModified : a.id < b.id
            case .nameAsc:
                let r = a.workspaceName.localizedCaseInsensitiveCompare(b.workspaceName)
                return r != .orderedSame ? r == .orderedAscending : a.id < b.id
            }
        }
    }

    /// Conversations of one editor across all its databases, newest first; undated rows go last.
    public static func conversations(for editor: AgentEditorKind, in entries: [AgentDatabaseEntry], query: String = "") -> [AgentConversationRef] {
        entries.filter { $0.editor == editor }
            .flatMap { e in
                e.conversations.filter { matches($0, query: query) }.map {
                    AgentConversationRef(conversation: $0, entryId: e.id, databaseName: e.workspaceName,
                                         databasePath: e.filePath, scope: e.scope)
                }
            }
            .sorted { a, b in
                switch (a.sortDate, b.sortDate) {
                case let (x?, y?): return x != y ? x > y : a.id < b.id
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return a.id < b.id
                }
            }
    }

    /// Whether some database returned exactly the reader cap, i.e. older sessions were not loaded.
    public static func isTruncated(_ entries: [AgentDatabaseEntry]) -> Bool {
        entries.contains { $0.conversations.count >= readerConversationCap }
    }
}

/// Decides whether Pharos may delete a detected database. Kept pure so every rule is unit-tested.
///
/// - Global databases hold an editor's settings and every session — never deleted, only backed up.
/// - The target must sit strictly inside one of the editor's known storage directories
///   (or be exactly a known file path); copies elsewhere (forensics folders, other apps) are left alone.
/// - An orphaned workspace removes its whole folder, but only a direct child of a known workspace root.
/// - Non-orphaned databases are only deletable while the editor is not running (live SQLite files).
public enum AgentDeletePolicy {
    public enum Verdict: Equatable {
        case allowed(target: String, isDirectory: Bool)
        case globalDatabase
        case outsideKnownPaths
        case appRunning
    }

    public static func evaluate(_ entry: AgentDatabaseEntry, knownPaths: [AgentKnownPath], appRunning: Bool) -> Verdict {
        if entry.scope == .global && !entry.isOrphaned { return .globalDatabase }

        let dirRoots = knownPaths.filter(\.isDirectory).map { normalize($0.fullPath) }
        let fileRoots = Set(knownPaths.filter { !$0.isDirectory }.map { normalize($0.fullPath) })

        if entry.isOrphaned && entry.scope == .workspace {
            let dir = normalize(entry.storageDirectory)
            let parent = (dir as NSString).deletingLastPathComponent
            let wsRoots = knownPaths.filter { $0.isDirectory && $0.scope == .workspace }.map { normalize($0.fullPath) }
            guard wsRoots.contains(parent), isStrictlyInside(normalize(entry.filePath), dir) else { return .outsideKnownPaths }
            return .allowed(target: dir, isDirectory: true)
        }

        let file = normalize(entry.filePath)
        let inside = fileRoots.contains(file) || dirRoots.contains { isStrictlyInside(file, $0) }
        guard inside else { return .outsideKnownPaths }
        if entry.scope == .global { return .globalDatabase }
        if appRunning { return .appRunning }
        return .allowed(target: file, isDirectory: false)
    }

    static func normalize(_ path: String) -> String {
        let std = (path as NSString).standardizingPath
        return std.count > 1 && std.hasSuffix("/") ? String(std.dropLast()) : std
    }

    static func isStrictlyInside(_ path: String, _ root: String) -> Bool {
        path != root && path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }
}
