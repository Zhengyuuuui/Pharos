import Foundation

/// General health reported by AppleSmartBattery / IOPS.
public enum BatteryHealth: String, Codable, Sendable {
    case normal
    case replaceSoon
    case replaceNow
    case serviceBattery
    case unknown

    public static func from(raw: String) -> BatteryHealth {
        let lower = raw.lowercased()
        if lower.contains("normal") || lower.contains("good") { return .normal }
        if lower.contains("replacesoon") || lower.contains("replace soon") { return .replaceSoon }
        if lower.contains("replacenow") || lower.contains("replace now") { return .replaceNow }
        if lower.contains("service") || lower.contains("check battery") { return .serviceBattery }
        return .unknown
    }
}

/// Power source state (AC adapter, battery, or UPS).
public enum PowerSourceState: String, Codable, Sendable {
    case battery
    case acPower
    case ups
    case unknown

    public static func from(raw: String) -> PowerSourceState {
        let lower = raw.lowercased()
        if lower.contains("ac") || lower.contains("charger") || lower.contains("adapter") { return .acPower }
        if lower.contains("battery") { return .battery }
        if lower.contains("ups") { return .ups }
        return .unknown
    }
}

/// Hardware SMC capabilities detected on this Mac.
public struct BatteryHardwareCapabilities: Equatable, Sendable, Codable {
    /// Apple Silicon primary charge inhibit key (`CHTE`, ui32).
    public var hasCHTE: Bool
    /// Fallback charge inhibit key (`CH0C`, hex_).
    public var hasCH0C: Bool
    /// External power adapter bypass key (`CHIE`, hex_).
    public var hasCHIE: Bool
    /// Secondary external power adapter key (`CH0J`, ui8).
    public var hasCH0J: Bool
    /// MagSafe LED color control key (`ACLC`, ui8).
    public var hasACLC: Bool

    public init(hasCHTE: Bool = false, hasCH0C: Bool = false, hasCHIE: Bool = false, hasCH0J: Bool = false, hasACLC: Bool = false) {
        self.hasCHTE = hasCHTE
        self.hasCH0C = hasCH0C
        self.hasCHIE = hasCHIE
        self.hasCH0J = hasCH0J
        self.hasACLC = hasACLC
    }

    /// Whether this Mac supports hardware-level battery charging inhibition.
    public var isSupported: Bool { hasCHTE || hasCH0C }

    /// Whether this Mac supports forced discharge / adapter bypass.
    public var supportsAdapterBypass: Bool { hasCHIE || hasCH0J }
}

/// Snapshot of the battery state gathered from IOKit and AppleSmartBattery.
public struct BatteryReading: Equatable, Sendable, Codable {
    /// Current State of Charge (0 ... 100).
    public var currentPercent: Int
    /// Remaining capacity in mAh.
    public var remainingCapacity: Int
    /// Maximum capacity at full charge in mAh.
    public var maxCapacity: Int
    /// Original factory design capacity in mAh.
    public var designCapacity: Int
    /// Cycle count.
    public var cycleCount: Int
    /// Temperature in degrees Celsius.
    public var temperatureCelsius: Double
    /// Instantaneous amperage in mA (positive = charging, negative = discharging, 0 = idle).
    public var amperage: Int
    /// Voltage in Volts.
    public var voltage: Double
    /// Instantaneous power in Watts (|amperage * voltage / 1000|).
    public var watts: Double
    /// Whether current is flowing to charge the cells.
    public var isCharging: Bool
    /// Whether battery has reached 100% capacity.
    public var isCharged: Bool
    /// Current power source.
    public var powerSource: PowerSourceState
    /// Connected adapter rated wattage (e.g. 70W, 96W, 140W).
    public var adapterWatts: Int?
    /// Connected adapter descriptive name (e.g. "70W USB-C Power Adapter").
    public var adapterName: String?
    /// Estimated minutes remaining (-1 or nil if calculating / not applicable).
    public var timeRemainingMinutes: Int?
    /// Battery health assessment.
    public var health: BatteryHealth
    /// Health condition percent (maxCapacity * 100 / designCapacity, clamped 0 ... 100).
    public var healthPercent: Int
    /// Whether Apple's Optimized Battery Charging is currently reported as engaged.
    public var optimizedChargingEngaged: Bool

    public init(
        currentPercent: Int = 100,
        remainingCapacity: Int = 0,
        maxCapacity: Int = 0,
        designCapacity: Int = 0,
        cycleCount: Int = 0,
        temperatureCelsius: Double = 25.0,
        amperage: Int = 0,
        voltage: Double = 0.0,
        watts: Double = 0.0,
        isCharging: Bool = false,
        isCharged: Bool = true,
        powerSource: PowerSourceState = .acPower,
        adapterWatts: Int? = nil,
        adapterName: String? = nil,
        timeRemainingMinutes: Int? = nil,
        health: BatteryHealth = .normal,
        healthPercent: Int = 100,
        optimizedChargingEngaged: Bool = false
    ) {
        self.currentPercent = currentPercent
        self.remainingCapacity = remainingCapacity
        self.maxCapacity = maxCapacity
        self.designCapacity = designCapacity
        self.cycleCount = cycleCount
        self.temperatureCelsius = temperatureCelsius
        self.amperage = amperage
        self.voltage = voltage
        self.watts = watts
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.powerSource = powerSource
        self.adapterWatts = adapterWatts
        self.adapterName = adapterName
        self.timeRemainingMinutes = timeRemainingMinutes
        self.health = health
        self.healthPercent = healthPercent
        self.optimizedChargingEngaged = optimizedChargingEngaged
    }

    /// Whether an internal battery is installed on this Mac (e.g. MacBook Pro / Air).
    public var hasBattery: Bool { designCapacity > 0 || maxCapacity > 0 }
}

/// User's requested charging mode.
public enum BatteryMode: Equatable, Sendable, Codable {
    /// macOS manages charging automatically (default 100%).
    case system
    /// Hold battery charge at maximum percentage (e.g. 80%) with hysteresis.
    case limit(maxPercent: Int)
    /// Temporary manual override: charge to 100% full now.
    case full
    /// Run on battery power even while connected to adapter (force discharge).
    case discharge
}

/// Visual progress representation matching macOS 15 style.
public enum ChargingProgress: Equatable, Sendable, Codable {
    /// Operating on battery power.
    case onBattery
    /// Connected to adapter and charging towards target percentage.
    case charging(target: Int)
    /// Connected to adapter, battery held at limit, not charging (Native "小插头").
    case holding(limit: Int)
    /// Connected to adapter, battery 100% full, not charging.
    case fullyCharged
}
