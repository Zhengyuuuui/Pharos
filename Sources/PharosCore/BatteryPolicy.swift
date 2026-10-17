import Foundation

/// Safety rules and decision engine for battery charging control.
/// Kept pure with no IOKit or AppKit imports so it is 100% unit-testable.
public enum BatteryPolicy {
    /// No heartbeat from Pharos for this long → hand charging back to macOS.
    public static let heartbeatTimeout: TimeInterval = 15.0

    /// Default hysteresis margin (percentage points below limit before charging resumes).
    public static let defaultHysteresisMargin = 5

    /// Maximum safe battery cell temperature (°C) before forcing charging stop.
    public static let maxSafeTemperatureCelsius = 50.0

    /// Action the privileged daemon should take on hardware SMC registers.
    public enum Action: Equatable, Sendable {
        /// Return all control to macOS (charging enabled, adapter normal, default MagSafe).
        case release
        /// Inhibit battery charging (BMS in bypass, power Mac from adapter, Amperage = 0).
        case inhibitCharge
        /// Allow charging cells towards target.
        case allowCharge
    }

    /// Sleep policy recommendation based on current charging state.
    public enum SleepDirective: Equatable, Sendable {
        /// System can sleep normally (either charge limit reached, or on battery).
        case allowSleep
        /// System should stay awake until charge target is reached.
        case preventSleep
    }

    /// MagSafe LED colors Pharos may write to `ACLC`.
    /// 0x01 (LED off) is deliberately absent: macOS 15 keeps the LED amber while
    /// "Not Charging", and a dark connector reads as a lost adapter.
    public enum MagSafeColor: UInt8, Sendable, Codable, CaseIterable {
        case system = 0x00
        case green = 0x03
        case orange = 0x04
        case orangeSlowBlink = 0x06
    }

    public struct State: Equatable, Sendable {
        /// Whether we are currently in the "held at limit" (inhibit) state.
        public var isHolding: Bool = false
        /// Whether power adapter is currently bypassed.
        public var isAdapterBypassed: Bool = false

        public init(isHolding: Bool = false, isAdapterBypassed: Bool = false) {
            self.isHolding = isHolding
            self.isAdapterBypassed = isAdapterBypassed
        }
    }

    public struct Decision: Equatable, Sendable {
        public var action: Action
        public var sleepDirective: SleepDirective
        public var magSafeColor: MagSafeColor
        public var progress: ChargingProgress

        public init(
            action: Action,
            sleepDirective: SleepDirective,
            magSafeColor: MagSafeColor,
            progress: ChargingProgress
        ) {
            self.action = action
            self.sleepDirective = sleepDirective
            self.magSafeColor = magSafeColor
            self.progress = progress
        }
    }

    /// Evaluates the current inputs against the policy and produces the hardware decision.
    public static func decide(
        mode: BatteryMode,
        currentPercent: Int,
        isACConnected: Bool,
        temperatureCelsius: Double = 25.0,
        syncMagSafe: Bool = true,
        lastHeartbeat: Date?,
        now: Date,
        state: inout State
    ) -> Decision {
        // 1. Safety check: Pharos quit or crashed. Never leave charging locked or adapter disabled.
        if mode != .system {
            guard let beat = lastHeartbeat, now.timeIntervalSince(beat) <= heartbeatTimeout else {
                state.isHolding = false
                state.isAdapterBypassed = false
                return Decision(
                    action: .release,
                    sleepDirective: .allowSleep,
                    magSafeColor: .system,
                    progress: isACConnected ? (currentPercent >= 100 ? .fullyCharged : .charging(target: 100)) : .onBattery
                )
            }
        }

        // 2. Not connected to AC power: running on battery.
        guard isACConnected else {
            state.isHolding = false
            state.isAdapterBypassed = false
            return Decision(
                action: .release,
                sleepDirective: .allowSleep,
                magSafeColor: .system,
                progress: .onBattery
            )
        }

        // 3. Thermal protection: if battery is dangerously hot, inhibit charge immediately.
        if temperatureCelsius >= maxSafeTemperatureCelsius {
            state.isHolding = true
            state.isAdapterBypassed = false
            return Decision(
                action: .inhibitCharge,
                sleepDirective: .allowSleep,
                magSafeColor: syncMagSafe ? .orangeSlowBlink : .system,
                progress: .holding(limit: currentPercent)
            )
        }

        // 4. Mode evaluation
        switch mode {
        case .system:
            state.isHolding = false
            state.isAdapterBypassed = false
            let isFull = currentPercent >= 100
            return Decision(
                action: .release,
                sleepDirective: .allowSleep,
                magSafeColor: .system,
                progress: isFull ? .fullyCharged : .charging(target: 100)
            )

        case .full:
            state.isAdapterBypassed = false
            if currentPercent >= 100 {
                state.isHolding = true
                return Decision(
                    action: .inhibitCharge,
                    sleepDirective: .allowSleep,
                    magSafeColor: syncMagSafe ? .green : .system,
                    progress: .fullyCharged
                )
            } else {
                state.isHolding = false
                return Decision(
                    action: .allowCharge,
                    sleepDirective: .preventSleep,
                    magSafeColor: syncMagSafe ? .orange : .system,
                    progress: .charging(target: 100)
                )
            }

        case .discharge:
            // Safe fallback: never cut the AC adapter to prevent screen flickering or battery damage.
            // Safely inhibit charge at 80% with continuous direct adapter power.
            state.isHolding = true
            state.isAdapterBypassed = false
            return Decision(
                action: .inhibitCharge,
                sleepDirective: .allowSleep,
                magSafeColor: syncMagSafe ? .orange : .system,
                progress: .holding(limit: 80)
            )

        case .limit(let rawLimit):
            let limit = clampLimit(rawLimit)
            let lowerThreshold = Swift.max(20, limit - defaultHysteresisMargin)
            state.isAdapterBypassed = false

            if currentPercent >= limit {
                // Reached or exceeded upper limit: inhibit charge.
                state.isHolding = true
            } else if currentPercent <= lowerThreshold {
                // Fallen to or below lower hysteresis threshold: resume charge.
                state.isHolding = false
            }
            // If currentPercent is between lowerThreshold and limit, maintain state.isHolding.

            if state.isHolding {
                // Matches macOS 15's own "Not Charging" plug state: amber LED, adapter stays on.
                return Decision(
                    action: .inhibitCharge,
                    sleepDirective: .allowSleep,
                    magSafeColor: syncMagSafe ? .orange : .system,
                    progress: .holding(limit: limit)
                )
            } else {
                return Decision(
                    action: .allowCharge,
                    sleepDirective: .preventSleep,
                    magSafeColor: syncMagSafe ? .orange : .system,
                    progress: .charging(target: limit)
                )
            }
        }
    }

    /// Final gate before any SMC write in `pharos-battd`. Only the charge-inhibit keys
    /// may be toggled; the adapter-bypass keys may only ever be written back to 0
    /// (writing CHIE=0x08 cuts the adapter → screen flicker and battery cycling),
    /// and ACLC may never be switched off.
    public static func isSafeWrite(key: String, bytes: [UInt8]) -> Bool {
        switch key {
        case "CHTE": return bytes == [0, 0, 0, 0] || bytes == [1, 0, 0, 0]
        case "CH0C": return bytes == [0] || bytes == [1]
        case "CHIE", "CH0J": return bytes == [0]
        case "ACLC":
            guard bytes.count == 1 else { return false }
            return MagSafeColor(rawValue: bytes[0]) != nil
        default: return false
        }
    }

    /// Clamps user limit between 50% and 100%.
    public static func clampLimit(_ limit: Int) -> Int {
        Swift.min(Swift.max(limit, 50), 100)
    }
}
