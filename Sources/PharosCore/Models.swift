import Foundation

public struct ListeningPort: Hashable, Sendable, Comparable {
    public let port: UInt16
    /// Bound only to 127.0.0.1 / ::1 — not reachable from the LAN.
    public let loopbackOnly: Bool

    public init(port: UInt16, loopbackOnly: Bool) {
        self.port = port
        self.loopbackOnly = loopbackOnly
    }

    public static func < (a: ListeningPort, b: ListeningPort) -> Bool { a.port < b.port }

    /// One entry per port number; a port counts as loopback-only only if every binding is.
    public static func merged(_ ports: [ListeningPort]) -> [ListeningPort] {
        var byPort: [UInt16: Bool] = [:]
        for p in ports {
            byPort[p.port] = (byPort[p.port] ?? true) && p.loopbackOnly
        }
        return byPort.map { ListeningPort(port: $0.key, loopbackOnly: $0.value) }.sorted()
    }
}

/// A single user-owned process. Path / cwd / arguments are only collected for
/// processes that listen on a port (they are the expensive lookups).
public struct ProcessSnapshot: Hashable, Sendable, Identifiable {
    public let pid: Int32
    public let ppid: Int32
    public let name: String
    public let executablePath: String?
    public let cwd: String?
    public let arguments: [String]
    public let memoryBytes: UInt64
    public let ports: [ListeningPort]

    public var id: Int32 { pid }

    public init(pid: Int32, ppid: Int32, name: String, executablePath: String? = nil,
                cwd: String? = nil, arguments: [String] = [], memoryBytes: UInt64,
                ports: [ListeningPort] = []) {
        self.pid = pid
        self.ppid = ppid
        self.name = name
        self.executablePath = executablePath
        self.cwd = cwd
        self.arguments = arguments
        self.memoryBytes = memoryBytes
        self.ports = ports
    }

    /// Short human-readable command, e.g. "node vite" or "python3 manage.py runserver".
    public var shortCommand: String {
        guard let first = arguments.first else { return name }
        var parts = [(first as NSString).lastPathComponent]
        for arg in arguments.dropFirst().prefix(3) {
            parts.append(arg.hasPrefix("/") ? (arg as NSString).lastPathComponent : arg)
        }
        return parts.joined(separator: " ")
    }
}

/// Processes grouped by working directory: one dev project = one row.
public struct Project: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let directory: String?
    /// Processes that own listening sockets.
    public let listeners: [ProcessSnapshot]
    /// Non-listening descendants (workers, bundlers) whose memory is attributed here.
    public let helpers: [ProcessSnapshot]
    public let ports: [ListeningPort]
    public let memoryBytes: UInt64

    public init(id: String, name: String, directory: String?, listeners: [ProcessSnapshot],
                helpers: [ProcessSnapshot], ports: [ListeningPort], memoryBytes: UInt64) {
        self.id = id
        self.name = name
        self.directory = directory
        self.listeners = listeners
        self.helpers = helpers
        self.ports = ports
        self.memoryBytes = memoryBytes
    }

    public var allPIDs: [Int32] { listeners.map(\.pid) + helpers.map(\.pid) }
    public var processCount: Int { listeners.count + helpers.count }
}
