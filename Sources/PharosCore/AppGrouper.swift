import Foundation

/// Memory per application: Chrome's dozens of helper processes count as one "Google Chrome".
public struct AppUsage: Hashable, Sendable, Identifiable {
    public let name: String
    public let memoryBytes: UInt64
    public let processCount: Int
    public var id: String { name }

    public init(name: String, memoryBytes: UInt64, processCount: Int) {
        self.name = name
        self.memoryBytes = memoryBytes
        self.processCount = processCount
    }
}

public enum AppGrouper {
    /// Outermost `.app` bundle in the path, so nested helper apps roll up to their parent.
    public static func appName(path: String?, fallback: String) -> String {
        guard let path else { return fallback }
        for component in path.split(separator: "/") where component.hasSuffix(".app") {
            return String(component.dropLast(4))
        }
        return fallback
    }

    public static func group(_ processes: [ProcessSnapshot]) -> [AppUsage] {
        var bytes: [String: UInt64] = [:]
        var counts: [String: Int] = [:]
        for p in processes {
            let name = appName(path: p.executablePath, fallback: p.name)
            bytes[name, default: 0] += p.memoryBytes
            counts[name, default: 0] += 1
        }
        return bytes.map { AppUsage(name: $0.key, memoryBytes: $0.value, processCount: counts[$0.key] ?? 0) }
            .sorted { $0.memoryBytes != $1.memoryBytes ? $0.memoryBytes > $1.memoryBytes : $0.name < $1.name }
    }
}
