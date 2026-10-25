import Foundation

/// Line protocol between Pharos and `pharos-battd` over a 0600 Unix socket.
/// One request line in, one JSON response line out.
public enum BatteryProtocol {
    public static let socketPath = "/var/run/pharos-battd.sock"
    public static let version = 2
    /// Requests longer than this are rejected unread.
    public static let maxLineBytes = 256

    public enum Command: Equatable, Sendable {
        case status
        case heartbeat
        case setMode(BatteryMode)
        case syncMagSafe(Bool)
        case setPersistentGuard(Bool)
    }

    public static func encode(_ c: Command) -> String {
        switch c {
        case .status: return "status"
        case .heartbeat: return "ping"
        case .setMode(.system): return "system"
        case .setMode(.limit(let max)): return "limit \(max)"
        case .setMode(.full): return "full"
        case .setMode(.discharge): return "discharge"
        case .syncMagSafe(let on): return "magsafe \(on ? 1 : 0)"
        case .setPersistentGuard(let on): return "persistent \(on ? 1 : 0)"
        }
    }

    /// Strict line decoder: anything malformed is rejected.
    public static func decode(_ line: String) -> Command? {
        let parts = line.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard let first = parts.first else { return nil }
        switch first {
        case "status" where parts.count == 1: return .status
        case "ping" where parts.count == 1: return .heartbeat
        case "system" where parts.count == 1: return .setMode(.system)
        case "full" where parts.count == 1: return .setMode(.full)
        case "discharge" where parts.count == 1: return .setMode(.discharge)
        case "limit" where parts.count == 2:
            guard let limit = Int(parts[1]), (20...100).contains(limit) else { return nil }
            return .setMode(.limit(maxPercent: limit))
        case "magsafe" where parts.count == 2:
            guard let flag = Int(parts[1]), flag == 0 || flag == 1 else { return nil }
            return .syncMagSafe(flag == 1)
        case "persistent" where parts.count == 2:
            guard let flag = Int(parts[1]), flag == 0 || flag == 1 else { return nil }
            return .setPersistentGuard(flag == 1)
        default:
            return nil
        }
    }

    public struct Reply: Codable, Equatable, Sendable {
        public var version: Int
        public var ok: Bool
        public var error: String?
        public var mode: BatteryMode
        public var isHolding: Bool
        public var isAdapterBypassed: Bool
        public var magSafeSync: Bool
        public var persistentGuard: Bool
        public var unsupported: Bool

        public init(
            ok: Bool,
            error: String? = nil,
            mode: BatteryMode,
            isHolding: Bool = false,
            isAdapterBypassed: Bool = false,
            magSafeSync: Bool = true,
            persistentGuard: Bool = true,
            unsupported: Bool = false
        ) {
            self.version = BatteryProtocol.version
            self.ok = ok
            self.error = error
            self.mode = mode
            self.isHolding = isHolding
            self.isAdapterBypassed = isAdapterBypassed
            self.magSafeSync = magSafeSync
            self.persistentGuard = persistentGuard
            self.unsupported = unsupported
        }

        private enum CodingKeys: String, CodingKey {
            case version, ok, error, mode, isHolding, isAdapterBypassed, magSafeSync, persistentGuard, unsupported
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = try c.decode(Int.self, forKey: .version)
            ok = try c.decode(Bool.self, forKey: .ok)
            error = try c.decodeIfPresent(String.self, forKey: .error)
            mode = try c.decode(BatteryMode.self, forKey: .mode)
            isHolding = try c.decodeIfPresent(Bool.self, forKey: .isHolding) ?? false
            isAdapterBypassed = try c.decodeIfPresent(Bool.self, forKey: .isAdapterBypassed) ?? false
            magSafeSync = try c.decodeIfPresent(Bool.self, forKey: .magSafeSync) ?? true
            persistentGuard = try c.decodeIfPresent(Bool.self, forKey: .persistentGuard) ?? true
            unsupported = try c.decodeIfPresent(Bool.self, forKey: .unsupported) ?? false
        }
    }
}
