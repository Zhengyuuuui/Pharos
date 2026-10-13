import Foundation

/// One fan as the SMC reports it.
public struct FanReading: Identifiable, Hashable, Sendable, Codable {
    public enum Mode: String, Sendable, Codable {
        /// macOS (thermalmonitord) is in charge — the normal state.
        case system
        case auto
        case manual
        case unknown
    }

    public let index: Int
    public let actualRPM: Int
    public let targetRPM: Int
    public let minRPM: Int
    public let maxRPM: Int
    public let mode: Mode

    public init(index: Int, actualRPM: Int, targetRPM: Int, minRPM: Int, maxRPM: Int, mode: Mode) {
        self.index = index
        self.actualRPM = actualRPM
        self.targetRPM = targetRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.mode = mode
    }

    public var id: Int { index }
    /// Share of the fan's rated range, 0 when stopped.
    public var fraction: Double {
        guard maxRPM > 0, actualRPM > 0 else { return 0 }
        return min(1, Double(actualRPM) / Double(maxRPM))
    }

    public static func mode(_ raw: UInt8?) -> Mode {
        switch raw {
        case 0: return .auto
        case 1: return .manual
        case 3: return .system
        default: return .unknown
        }
    }
}

/// Temperature sensors grouped the way people think about them. SMC key names
/// differ between chip generations, so grouping is by prefix and a group shows
/// the hottest of its sensors.
public enum SensorGroup: String, CaseIterable, Sendable, Codable {
    case cpu, gpu, memory, ssd, battery, power, ambient

    /// Prefixes observed across M1–M5 (ThermalForge, Asahi Linux docs, and this
    /// machine's own key list). Case matters: `Tp` is CPU, `TP` is power.
    static let prefixes: [(String, SensorGroup)] = [
        ("TC", .cpu), ("Tp", .cpu), ("Te", .cpu),
        ("TG", .gpu), ("Tg", .gpu),
        ("Tm", .memory), ("TRD", .memory), ("TMVR", .memory),
        ("TH0", .ssd),
        ("TB", .battery),
        ("TPD", .power),
        ("TA", .ambient), ("TaL", .ambient), ("TaR", .ambient), ("TS0P", .ambient),
    ]

    public static func group(for key: String) -> SensorGroup? {
        prefixes.first { key.hasPrefix($0.0) }?.1
    }

    /// The groups that drive the overheat safety rule.
    public var isSafetyCritical: Bool { self == .cpu || self == .gpu }
}

public struct ThermalSnapshot: Hashable, Sendable, Codable {
    public let fans: [FanReading]
    /// Hottest sensor per group, °C.
    public let groups: [SensorGroup: Double]
    /// Whether `Ftst` (diagnostic unlock) is currently set — i.e. something holds manual control.
    public let unlockEngaged: Bool

    public init(fans: [FanReading], groups: [SensorGroup: Double], unlockEngaged: Bool = false) {
        self.fans = fans
        self.groups = groups
        self.unlockEngaged = unlockEngaged
    }

    /// Hottest CPU/GPU reading, the value the safety rule watches.
    public var peakChipTemperature: Double? {
        groups.filter { $0.key.isSafetyCritical }.values.max()
    }

    public var isSystemControlled: Bool { fans.allSatisfy { $0.mode == .system || $0.mode == .auto } && !unlockEngaged }

    /// Keeps only plausible readings and reduces them to one value per group.
    /// Some keys report 0, negatives or sentinel values; those aren't real temperatures.
    public static func groupTemperatures(_ raw: [String: Float]) -> [SensorGroup: Double] {
        var out: [SensorGroup: Double] = [:]
        for (key, value) in raw where value > 5 && value < 130 {
            guard let g = SensorGroup.group(for: key) else { continue }
            out[g] = max(out[g] ?? 0, (Double(value) * 10).rounded() / 10)
        }
        return out
    }
}

/// Read-only access to fans and temperatures. Safe for any user.
public enum Thermals {
    /// Discovered once per process: enumerating all ~2300 keys takes ~300 ms,
    /// re-reading the temperature subset afterwards ~50 ms.
    private static let cache = KeyCache()

    public static func read(using smc: SMCClient? = SMCClient()) -> ThermalSnapshot? {
        guard let smc, let count = smc.readUInt8("FNum") else { return nil }
        let modeTemplate = smc.exists("F0md") ? "F%dmd" : "F%dMd"
        let fans = (0..<Int(count)).map { i -> FanReading in
            func rpm(_ suffix: String) -> Int { Int(smc.readFloat("F\(i)\(suffix)") ?? 0) }
            return FanReading(index: i, actualRPM: rpm("Ac"), targetRPM: rpm("Tg"),
                              minRPM: rpm("Mn"), maxRPM: rpm("Mx"),
                              mode: FanReading.mode(smc.readUInt8(String(format: modeTemplate, i))))
        }
        var raw: [String: Float] = [:]
        for key in cache.temperatureKeys(smc) {
            if let v = smc.read(key), let f = SMCCodec.float(v) { raw[key] = f }
        }
        return ThermalSnapshot(fans: fans, groups: ThermalSnapshot.groupTemperatures(raw),
                               unlockEngaged: (smc.readUInt8("Ftst") ?? 0) != 0)
    }

    private final class KeyCache: @unchecked Sendable {
        private let lock = NSLock()
        private var keys: [String]?

        func temperatureKeys(_ smc: SMCClient) -> [String] {
            lock.lock()
            defer { lock.unlock() }
            if let keys { return keys }
            let found = (0..<smc.keyCount()).compactMap { smc.key(at: $0) }
                .filter { SensorGroup.group(for: $0) != nil }
            keys = found
            return found
        }
    }
}
