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

/// A single user-owned process. Path / cwd / arguments are collected for
/// listening sockets, developer scripts/tools, or high-activity tasks.
public struct ProcessSnapshot: Hashable, Sendable, Identifiable {
    public let pid: Int32
    public let ppid: Int32
    public let name: String
    public let executablePath: String?
    public let cwd: String?
    public let arguments: [String]
    public let memoryBytes: UInt64
    public let ports: [ListeningPort]
    public let cpuTimeNs: UInt64
    public let startTime: Date?
    public let cpuPercent: Double?

    public var id: Int32 { pid }

    public init(pid: Int32, ppid: Int32, name: String, executablePath: String? = nil,
                cwd: String? = nil, arguments: [String] = [], memoryBytes: UInt64,
                ports: [ListeningPort] = [], cpuTimeNs: UInt64 = 0, startTime: Date? = nil,
                cpuPercent: Double? = nil) {
        self.pid = pid
        self.ppid = ppid
        self.name = name
        self.executablePath = executablePath
        self.cwd = cwd
        self.arguments = arguments
        self.memoryBytes = memoryBytes
        self.ports = ports
        self.cpuTimeNs = cpuTimeNs
        self.startTime = startTime
        self.cpuPercent = cpuPercent
    }

    /// Whether this process was orphaned (parent is launchd, ppid == 1).
    public var isOrphan: Bool { ppid == 1 }

    /// Wall-clock uptime elapsed since process launch.
    public var elapsedTime: TimeInterval? {
        guard let startTime else { return nil }
        return max(0, Date().timeIntervalSince(startTime))
    }

    /// Full executed command string (or fallback to executable path/name).
    public var fullCommand: String {
        if arguments.isEmpty {
            return executablePath ?? name
        }
        return arguments.joined(separator: " ")
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

    /// A clean, highly portable start command recognized for this project (e.g. "pnpm run dev",
    /// "cargo run", "go run .", "uv run main.py"), optimized for sharing and reuse across machines.
    /// Falls back to the listening process's shortCommand if no project manifest is matched.
    public var startCommand: String {
        if let dir = directory, let listener = listeners.first {
            if let cmd = LaunchDetector.command(forRunning: listener.arguments, in: dir) {
                return cmd
            }
        }
        return listeners.first?.shortCommand ?? name
    }
}
