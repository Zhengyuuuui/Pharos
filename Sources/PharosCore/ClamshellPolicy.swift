import Foundation

/// Reason why Pharos or `pharos-fand` automatically terminated clamshell keep-awake.
public enum ClamshellAbortReason: Equatable, Sendable, Codable {
    /// Chip temperature hit the thermal suffocation redline (e.g. trapped in a backpack).
    case thermalRunaway(celsius: Double)
    /// Unplugged battery dropped below the safe floor.
    case lowBattery(percent: Int)
    /// Pharos stopped sending heartbeats; normal sleep restored for safety.
    case heartbeatTimeout
}

/// Configuration for Clamshell Guard (lid-closed keep-awake with thermal & battery safety).
public struct ClamshellConfig: Equatable, Sendable, Codable {
    public var enabled: Bool
    /// Chip temperature (°C) triggering emergency sleep abort when sustained.
    public var thermalAbortCelsius: Double {
        didSet { thermalAbortCelsius = Self.clampThermalAbort(thermalAbortCelsius) }
    }
    /// Unplugged battery percentage (%) triggering safe sleep abort.
    public var batteryFloorPercent: Int {
        didSet { batteryFloorPercent = Self.clampBatteryFloor(batteryFloorPercent) }
    }
    /// Automatically run an aggressive proactive fan curve while lid-closed mode is active.
    public var proactiveFanControl: Bool

    public init(
        enabled: Bool = false,
        thermalAbortCelsius: Double = ClamshellPolicy.defaultThermalAbortCelsius,
        batteryFloorPercent: Int = ClamshellPolicy.defaultBatteryFloorPercent,
        proactiveFanControl: Bool = true
    ) {
        self.enabled = enabled
        self.thermalAbortCelsius = Self.clampThermalAbort(thermalAbortCelsius)
        self.batteryFloorPercent = Self.clampBatteryFloor(batteryFloorPercent)
        self.proactiveFanControl = proactiveFanControl
    }

    public static func clampThermalAbort(_ value: Double) -> Double {
        min(max(value, ClamshellPolicy.minThermalAbortCelsius), ClamshellPolicy.maxThermalAbortCelsius)
    }

    public static func clampBatteryFloor(_ value: Int) -> Int {
        min(max(value, ClamshellPolicy.minBatteryFloorPercent), ClamshellPolicy.maxBatteryFloorPercent)
    }
}

/// Pure safety policy for lid-closed keep-awake operation, evaluated every second inside `pharos-fand`.
public enum ClamshellPolicy {
    public static let defaultThermalAbortCelsius: Double = 86.0
    public static let minThermalAbortCelsius: Double = 75.0
    public static let maxThermalAbortCelsius: Double = 94.0

    public static let defaultBatteryFloorPercent: Int = 20
    public static let minBatteryFloorPercent: Int = 5
    public static let maxBatteryFloorPercent: Int = 50

    /// Consecutive 1-second ticks at or above `thermalAbortCelsius` required to trigger abort (debounces brief spikes).
    public static let requiredHighTempTicks: Int = 3
    /// Immediate abort margin above `thermalAbortCelsius` (no debounce wait if extreme).
    public static let immediateAbortMarginCelsius: Double = 4.0
    /// Consecutive 1-second ticks at or below `batteryFloorPercent` on battery required to trigger abort.
    public static let requiredLowBatteryTicks: Int = 3

    public struct State: Equatable, Sendable {
        public var consecutiveHighTempTicks: Int
        public var consecutiveLowBatteryTicks: Int

        public init(consecutiveHighTempTicks: Int = 0, consecutiveLowBatteryTicks: Int = 0) {
            self.consecutiveHighTempTicks = consecutiveHighTempTicks
            self.consecutiveLowBatteryTicks = consecutiveLowBatteryTicks
        }
    }

    public enum Action: Equatable, Sendable {
        /// Clamshell mode is off; macOS sleep should be enabled (`disablesleep 0`).
        case inactive
        /// Clamshell mode is actively holding sleep off (`disablesleep 1`).
        case active
        /// Heartbeat from Pharos timed out; restore normal sleep (`disablesleep 0`) without forcing sleepnow.
        case heartbeatRestore
        /// Safety redline breached (thermal runaway / low battery); restore sleep AND force `sleepnow`.
        case abort(reason: ClamshellAbortReason)
    }

    public static func decide(
        config: ClamshellConfig,
        chipCelsius: Double?,
        batteryPercent: Int?,
        isOnACPower: Bool,
        lastHeartbeat: Date?,
        now: Date,
        state: inout State
    ) -> Action {
        guard config.enabled else {
            state.consecutiveHighTempTicks = 0
            state.consecutiveLowBatteryTicks = 0
            return .inactive
        }

        // Fail-safe: if Pharos exits or freezes for > 15s, hand sleep control right back to macOS.
        guard let beat = lastHeartbeat, now.timeIntervalSince(beat) <= FanPolicy.heartbeatTimeout else {
            state.consecutiveHighTempTicks = 0
            state.consecutiveLowBatteryTicks = 0
            return .heartbeatRestore
        }

        // 1. Thermal runaway / suffocation circuit breaker (e.g. trapped in a closed bag).
        if let temp = chipCelsius {
            if temp >= config.thermalAbortCelsius + immediateAbortMarginCelsius {
                state.consecutiveHighTempTicks = 0
                state.consecutiveLowBatteryTicks = 0
                return .abort(reason: .thermalRunaway(celsius: temp))
            }
            if temp >= config.thermalAbortCelsius {
                state.consecutiveHighTempTicks += 1
                if state.consecutiveHighTempTicks >= requiredHighTempTicks {
                    state.consecutiveHighTempTicks = 0
                    state.consecutiveLowBatteryTicks = 0
                    return .abort(reason: .thermalRunaway(celsius: temp))
                }
            } else {
                state.consecutiveHighTempTicks = 0
            }
        }

        // 2. Unplugged low-battery floor safeguard.
        if !isOnACPower, let pct = batteryPercent {
            if pct <= config.batteryFloorPercent {
                state.consecutiveLowBatteryTicks += 1
                if state.consecutiveLowBatteryTicks >= requiredLowBatteryTicks {
                    state.consecutiveHighTempTicks = 0
                    state.consecutiveLowBatteryTicks = 0
                    return .abort(reason: .lowBattery(percent: pct))
                }
            } else {
                state.consecutiveLowBatteryTicks = 0
            }
        } else {
            state.consecutiveLowBatteryTicks = 0
        }

        return .active
    }
}
