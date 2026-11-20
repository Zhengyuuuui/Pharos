import Foundation

/// What the user asked the fan helper for.
public enum FanRequest: Equatable, Sendable, Codable {
    /// macOS controls the fans (default; also what every failure falls back to).
    case system
    /// Intelligent dynamic curve adapting smoothly to chip temperature (gradual ramp up & gentle glide down).
    case curve
    /// Every fan held at this RPM (clamped to each fan's rated range).
    case fixed(rpm: Int)
    /// Every fan at its rated maximum.
    case max
}

/// The safety rules for manual fan control, kept pure so they're unit-tested.
/// The `pharos-fand` helper evaluates this every second and writes the result.
public enum FanPolicy {
    /// In curve mode, any CPU/GPU sensor at or above this forces every fan to max.
    public static let overheatCelsius = 95.0
    /// …and the override is released only after dropping below this.
    public static let overheatReleaseCelsius = 88.0
    /// No heartbeat from Pharos for this long → hand fans back to macOS.
    public static let heartbeatTimeout: TimeInterval = 15

    public enum Action: Equatable, Sendable {
        /// Return control to macOS (mode 0 + clear the unlock flag).
        case release
        /// Hold each fan at the given RPM (index-aligned with the fans).
        case hold([Int])
    }

    public struct State: Equatable, Sendable {
        public var overheating = false
        /// Command history used for inertial damping (smooth acceleration & deceleration).
        public var lastTargets: [Int] = []
        public init(overheating: Bool = false, lastTargets: [Int] = []) {
            self.overheating = overheating
            self.lastTargets = lastTargets
        }
    }

    public static func decide(request: FanRequest, fans: [FanReading], chipCelsius: Double?,
                              lastHeartbeat: Date?, now: Date, state: inout State,
                              clamshellProactive: Bool = false) -> Action {
        let peak = chipCelsius ?? 0

        // Pharos quit or crashed: never leave fans pinned by a dead app.
        guard let beat = lastHeartbeat, now.timeIntervalSince(beat) <= heartbeatTimeout else {
            state.overheating = false
            state.lastTargets = []
            return .release
        }

        // Clamshell proactive mode engages active cooling even when user left fans on `.system`.
        let effectiveRequest: FanRequest = (clamshellProactive && request == .system) ? .curve : request

        switch effectiveRequest {
        case .system:
            state.overheating = false
            state.lastTargets = []
            return .release

        case .fixed(let rpm):
            // Fixed RPM is strictly fixed, unless clamshell proactive guard intervenes above 80°C.
            if clamshellProactive && peak >= 80.0 {
                state.overheating = peak >= overheatCelsius
                return .hold(fans.map { max(clamp(rpm, $0), $0.maxRPM) })
            }
            state.overheating = false
            state.lastTargets = []
            return .hold(fans.map { clamp(rpm, $0) })

        case .max:
            state.overheating = false
            state.lastTargets = []
            return .hold(fans.map(\.maxRPM))

        case .curve:
            // Dynamic Curve mode: evaluate overheat latch
            if state.overheating {
                if peak < overheatReleaseCelsius { state.overheating = false }
            } else if peak >= overheatCelsius {
                state.overheating = true
            }

            var idealTargets: [Int] = []
            for fan in fans {
                let minR = Double(fan.minRPM)
                let maxR = Double(fan.maxRPM)
                guard maxR > minR else {
                    idealTargets.append(fan.minRPM)
                    continue
                }

                let target: Double
                if state.overheating {
                    target = maxR
                } else if clamshellProactive {
                    // Clamshell proactive curve: engages earlier (42°C) and hits 100% by 80°C
                    // so trapped heat is expelled well before hitting the thermal abort redline.
                    if peak <= 42.0 {
                        target = minR
                    } else if peak <= 62.0 {
                        let fraction = (peak - 42.0) / (62.0 - 42.0)
                        target = minR + (maxR - minR) * 0.45 * fraction
                    } else if peak < 80.0 {
                        let fraction = (peak - 62.0) / (80.0 - 62.0)
                        target = minR + (maxR - minR) * (0.45 + 0.55 * fraction)
                    } else {
                        target = maxR
                    }
                } else if peak <= 48.0 {
                    target = minR
                } else if peak <= 85.0 {
                    let fraction = (peak - 48.0) / (85.0 - 48.0)
                    target = minR + (maxR - minR) * 0.70 * fraction
                } else {
                    let fraction = min(1.0, (peak - 85.0) / (95.0 - 85.0))
                    target = minR + (maxR - minR) * (0.70 + 0.30 * fraction)
                }
                idealTargets.append(clamp(Int(target), fan))
            }

            // Apply smooth slew-rate limiting:
            // Proactive clamshell ramps faster (+300 RPM/sec) to counter closed-hinge thermal lag.
            let accelStep = clamshellProactive ? 300 : 150
            let decelStep = 80
            var smoothed: [Int] = []
            for (i, ideal) in idealTargets.enumerated() {
                let current = (i < state.lastTargets.count && state.lastTargets[i] > 0)
                    ? state.lastTargets[i]
                    : (fans[i].targetRPM > 0 ? fans[i].targetRPM : fans[i].minRPM)

                let next: Int
                if ideal > current {
                    next = min(ideal, current + accelStep)
                } else if ideal < current {
                    next = max(ideal, current - decelStep)
                } else {
                    next = ideal
                }
                smoothed.append(clamp(next, fans[i]))
            }

            state.lastTargets = smoothed
            return .hold(smoothed)
        }
    }

    public static func clamp(_ rpm: Int, _ fan: FanReading) -> Int {
        guard fan.maxRPM > 0 else { return rpm }
        return Swift.min(Swift.max(rpm, fan.minRPM), fan.maxRPM)
    }
}

/// Line protocol between Pharos and `pharos-fand` over a Unix socket.
/// One request line in, one JSON response line out.
public enum FanProtocol {
    public static let socketPath = "/var/run/pharos-fand.sock"
    public static let version = 4
    /// Requests longer than this are rejected unread.
    public static let maxLineBytes = 256

    public enum Command: Equatable, Sendable {
        case status
        case heartbeat
        case set(FanRequest)
        case setClamshell(ClamshellConfig)
        case clearClamshellAbort
    }

    public static func encode(_ c: Command) -> String {
        switch c {
        case .status: return "status"
        case .heartbeat: return "ping"
        case .set(.system): return "system"
        case .set(.curve): return "curve"
        case .set(.max): return "max"
        case .set(.fixed(let rpm)): return "fixed \(rpm)"
        case .setClamshell(let cfg):
            if !cfg.enabled { return "clamshell off" }
            let abortC = Int(ClamshellConfig.clampThermalAbort(cfg.thermalAbortCelsius).rounded())
            let batt = ClamshellConfig.clampBatteryFloor(cfg.batteryFloorPercent)
            let pro = cfg.proactiveFanControl ? 1 : 0
            return "clamshell on \(abortC) \(batt) \(pro)"
        case .clearClamshellAbort:
            return "clamshell clear"
        }
    }

    /// Strict: anything else is an error, so a stray client can't do more than these.
    public static func decode(_ line: String) -> Command? {
        let parts = line.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        switch parts.first {
        case "status" where parts.count == 1: return .status
        case "ping" where parts.count == 1: return .heartbeat
        case "system" where parts.count == 1: return .set(.system)
        case "curve" where parts.count == 1: return .set(.curve)
        case "max" where parts.count == 1: return .set(.max)
        case "fixed" where parts.count == 2:
            guard let rpm = Int(parts[1]), (0...20_000).contains(rpm) else { return nil }
            return .set(.fixed(rpm: rpm))
        case "clamshell" where parts.count == 2 && parts[1] == "off":
            return .setClamshell(ClamshellConfig(enabled: false))
        case "clamshell" where parts.count == 2 && parts[1] == "clear":
            return .clearClamshellAbort
        case "clamshell" where parts.count == 5 && parts[1] == "on":
            let abortRange = Int(ClamshellPolicy.minThermalAbortCelsius)...Int(ClamshellPolicy.maxThermalAbortCelsius)
            let battRange = ClamshellPolicy.minBatteryFloorPercent...ClamshellPolicy.maxBatteryFloorPercent
            guard let abortC = Int(parts[2]), abortRange.contains(abortC),
                  let batt = Int(parts[3]), battRange.contains(batt),
                  let pro = Int(parts[4]), (0...1).contains(pro) else {
                return nil
            }
            return .setClamshell(ClamshellConfig(
                enabled: true,
                thermalAbortCelsius: Double(abortC),
                batteryFloorPercent: batt,
                proactiveFanControl: pro == 1
            ))
        default: return nil
        }
    }

    public struct Reply: Codable, Equatable, Sendable {
        public var version: Int
        public var ok: Bool
        public var error: String?
        public var request: FanRequest
        public var overheating: Bool
        /// The helper couldn't take manual control (unlock rejected); fans stay with macOS.
        public var unsupported: Bool
        public var clamshellEnabled: Bool
        public var sleepDisabledApplied: Bool
        public var clamshellAbort: ClamshellAbortReason?

        public init(
            ok: Bool,
            error: String? = nil,
            request: FanRequest,
            overheating: Bool,
            unsupported: Bool,
            clamshellEnabled: Bool = false,
            sleepDisabledApplied: Bool = false,
            clamshellAbort: ClamshellAbortReason? = nil
        ) {
            version = FanProtocol.version
            self.ok = ok
            self.error = error
            self.request = request
            self.overheating = overheating
            self.unsupported = unsupported
            self.clamshellEnabled = clamshellEnabled
            self.sleepDisabledApplied = sleepDisabledApplied
            self.clamshellAbort = clamshellAbort
        }

        private enum CodingKeys: String, CodingKey {
            case version, ok, error, request, overheating, unsupported
            case clamshellEnabled, sleepDisabledApplied, clamshellAbort
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = try c.decode(Int.self, forKey: .version)
            ok = try c.decode(Bool.self, forKey: .ok)
            error = try c.decodeIfPresent(String.self, forKey: .error)
            request = try c.decode(FanRequest.self, forKey: .request)
            overheating = try c.decode(Bool.self, forKey: .overheating)
            unsupported = try c.decode(Bool.self, forKey: .unsupported)
            clamshellEnabled = try c.decodeIfPresent(Bool.self, forKey: .clamshellEnabled) ?? false
            sleepDisabledApplied = try c.decodeIfPresent(Bool.self, forKey: .sleepDisabledApplied) ?? false
            clamshellAbort = try c.decodeIfPresent(ClamshellAbortReason.self, forKey: .clamshellAbort)
        }
    }
}
