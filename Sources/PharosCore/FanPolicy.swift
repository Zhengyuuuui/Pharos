import Foundation

/// What the user asked the fan helper for.
public enum FanRequest: Equatable, Sendable, Codable {
    /// macOS controls the fans (default; also what every failure falls back to).
    case system
    /// Every fan held at this RPM (clamped to each fan's rated range).
    case fixed(rpm: Int)
    /// Every fan at its rated maximum.
    case max
}

/// The safety rules for manual fan control, kept pure so they're unit-tested.
/// The `pharos-fand` helper evaluates this every second and writes the result.
public enum FanPolicy {
    /// Any CPU/GPU sensor at or above this forces every fan to max.
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
        public init() {}
    }

    public static func decide(request: FanRequest, fans: [FanReading], chipCelsius: Double?,
                              lastHeartbeat: Date?, now: Date, state: inout State) -> Action {
        let peak = chipCelsius ?? 0
        if state.overheating {
            if peak < overheatReleaseCelsius { state.overheating = false }
        } else if peak >= overheatCelsius {
            state.overheating = true
        }
        // Too hot while something holds the fans: max, regardless of request or heartbeat.
        // When macOS is already in charge it ramps the fans itself; don't take over.
        if state.overheating, request != .system { return .hold(fans.map(\.maxRPM)) }

        // Pharos quit or crashed: never leave fans pinned by a dead app.
        guard let beat = lastHeartbeat, now.timeIntervalSince(beat) <= heartbeatTimeout else { return .release }

        switch request {
        case .system:
            return .release
        case .max:
            return .hold(fans.map(\.maxRPM))
        case .fixed(let rpm):
            return .hold(fans.map { clamp(rpm, $0) })
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
    public static let version = 1
    /// Requests longer than this are rejected unread.
    public static let maxLineBytes = 256

    public enum Command: Equatable, Sendable {
        case status
        case heartbeat
        case set(FanRequest)
    }

    public static func encode(_ c: Command) -> String {
        switch c {
        case .status: return "status"
        case .heartbeat: return "ping"
        case .set(.system): return "system"
        case .set(.max): return "max"
        case .set(.fixed(let rpm)): return "fixed \(rpm)"
        }
    }

    /// Strict: anything else is an error, so a stray client can't do more than these.
    public static func decode(_ line: String) -> Command? {
        let parts = line.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        switch parts.first {
        case "status" where parts.count == 1: return .status
        case "ping" where parts.count == 1: return .heartbeat
        case "system" where parts.count == 1: return .set(.system)
        case "max" where parts.count == 1: return .set(.max)
        case "fixed" where parts.count == 2:
            guard let rpm = Int(parts[1]), (0...20_000).contains(rpm) else { return nil }
            return .set(.fixed(rpm: rpm))
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

        public init(ok: Bool, error: String? = nil, request: FanRequest, overheating: Bool, unsupported: Bool) {
            version = FanProtocol.version
            self.ok = ok
            self.error = error
            self.request = request
            self.overheating = overheating
            self.unsupported = unsupported
        }
    }
}
