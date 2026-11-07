import Foundation

/// Proxy routing mode supported by Clash / Mihomo.
public enum ClashRoutingMode: String, CaseIterable, Sendable, Codable {
    case rule = "rule"
    case direct = "direct"
    case global = "global"
    case script = "script"

    public var localizedKey: String {
        switch self {
        case .rule: return "clashModeRule"
        case .direct: return "clashModeDirect"
        case .global: return "clashModeGlobal"
        case .script: return "clashModeScript"
        }
    }
}

/// Known Clash / Mihomo client variant on macOS.
public enum ClashClientKind: String, Sendable, CaseIterable, Codable {
    case mihomoParty = "Mihomo Party"
    case clashVerge = "Clash Verge Rev"
    case clashNyanpasu = "Clash Nyanpasu"
    case clashX = "ClashX.Meta"
    case flclash = "Flclash"
    case singBox = "Sing-Box"
    case genericMihomo = "Mihomo Core"
    case custom = "Custom"

    public var iconName: String {
        switch self {
        case .mihomoParty: return "party.popper.fill"
        case .clashVerge: return "shield.lefthalf.filled"
        case .clashNyanpasu: return "cat.fill"
        case .clashX: return "paperplane.fill"
        case .flclash: return "bolt.shield.fill"
        case .singBox: return "cube.box.fill"
        case .genericMihomo: return "network"
        case .custom: return "slider.horizontal.3"
        }
    }
}

/// Proxy isolation strategy configured for a browser instance.
public enum BrowserProxyStrategy: Hashable, Sendable {
    case followSystem
    case direct
    case node(name: String, port: Int)
    case clashMixedPort(Int)
    case custom(String)

    public var isDirect: Bool {
        switch self {
        case .direct: return true
        case .node(let name, _): return name.uppercased() == "DIRECT"
        default: return false
        }
    }

    public var isClash: Bool {
        switch self {
        case .node, .clashMixedPort: return true
        default: return false
        }
    }

    public var nodeName: String? {
        if case .node(let name, _) = self { return name }
        return nil
    }

    public var badgeText: String {
        switch self {
        case .followSystem: return "System"
        case .direct: return "Direct"
        case .node(let name, let port): return "\(name) (:\(port))"
        case .clashMixedPort(let port): return "Clash :\(port)"
        case .custom(let s): return s
        }
    }
}

extension BrowserProxyStrategy: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, name, port, value
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let kind = (try? container.decode(String.self, forKey: .kind)) ?? ""
            switch kind {
            case "followSystem":
                self = .followSystem
                return
            case "direct":
                self = .direct
                return
            case "node":
                let name = (try? container.decode(String.self, forKey: .name)) ?? ""
                let port = (try? container.decode(Int.self, forKey: .port)) ?? 7890
                self = .node(name: name, port: port)
                return
            case "clashMixedPort":
                let port = (try? container.decode(Int.self, forKey: .port)) ?? 7890
                self = .clashMixedPort(port)
                return
            case "custom":
                let val = (try? container.decode(String.self, forKey: .value)) ?? ""
                self = .custom(val)
                return
            default:
                break
            }
        }

        let raw = try? decoder.singleValueContainer()
        if let str = try? raw?.decode(String.self) {
            switch str {
            case "followSystem": self = .followSystem
            case "direct": self = .direct
            default: self = .custom(str)
            }
            return
        }
        self = .followSystem
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .followSystem:
            try container.encode("followSystem", forKey: .kind)
        case .direct:
            try container.encode("direct", forKey: .kind)
        case .node(let name, let port):
            try container.encode("node", forKey: .kind)
            try container.encode(name, forKey: .name)
            try container.encode(port, forKey: .port)
        case .clashMixedPort(let port):
            try container.encode("clashMixedPort", forKey: .kind)
            try container.encode(port, forKey: .port)
        case .custom(let s):
            try container.encode("custom", forKey: .kind)
            try container.encode(s, forKey: .value)
        }
    }
}

/// An outbound proxy leaf node retrieved from Mihomo / Clash.
public struct MihomoProxyNode: Identifiable, Hashable, Sendable, Codable {
    public var id: String { name }
    public let name: String
    public let type: String
    public let delay: Int?
    public let alive: Bool

    public init(name: String, type: String, delay: Int? = nil, alive: Bool = true) {
        self.name = name
        self.type = type
        self.delay = delay
        self.alive = alive
    }

    public var isLeaf: Bool {
        let t = type.lowercased()
        let nonLeaf = ["selector", "urltest", "fallback", "loadbalance", "relay", "compatible", "reject", "rejectdrop", "pass"]
        return !nonLeaf.contains(t)
    }

    public var region: ProxyNodeRegion {
        ProxyNodeRegion.detect(from: name)
    }

    /// True if the node is alive and has a positive latency measurement (> 0 ms).
    public var isHealthy: Bool {
        alive && (delay ?? 0) > 0
    }

    /// Latency in milliseconds if healthy, or nil if timed out, failed, or untested.
    public var validDelay: Int? {
        guard isHealthy, let d = delay, d > 0 else { return nil }
        return d
    }

    /// Status rank for UI sorting:
    /// 0 = healthy with valid delay
    /// 1 = untested (delay == nil, alive == true)
    /// 2 = timeout or failed (delay == 0 or alive == false)
    public var statusRank: Int {
        if isHealthy { return 0 }
        if alive && delay == nil { return 1 }
        return 2
    }
}

/// Geographic region classification for proxy nodes.
public enum ProxyNodeRegion: String, CaseIterable, Identifiable, Sendable {
    case all
    case hongKong
    case japan
    case singapore
    case unitedStates
    case taiwan
    case korea
    case europe
    case other

    public var id: String { rawValue }

    public var code: String {
        switch self {
        case .all: return "ALL"
        case .hongKong: return "HK"
        case .japan: return "JP"
        case .singapore: return "SG"
        case .unitedStates: return "US"
        case .taiwan: return "TW"
        case .korea: return "KR"
        case .europe: return "EU"
        case .other: return "GL"
        }
    }

    public static func detect(from name: String) -> ProxyNodeRegion {
        let n = name.uppercased()
        if n.contains("香港") || n.contains("HK") || n.contains("HONG KONG") || n.contains("HONGKONG") {
            return .hongKong
        }
        if n.contains("日本") || n.contains("JP") || n.contains("JAPAN") || n.contains("TOKYO") || n.contains("OSAKA") {
            return .japan
        }
        if n.contains("新加坡") || n.contains("SG") || n.contains("SINGAPORE") || n.contains("狮城") {
            return .singapore
        }
        if n.contains("美国") || n.contains("US") || n.contains("USA") || n.contains("UNITED STATES") || n.contains("洛杉矶") || n.contains("圣何塞") || n.contains("西雅图") || n.contains("硅谷") {
            return .unitedStates
        }
        if n.contains("台湾") || n.contains("TW") || n.contains("TAIWAN") || n.contains("台北") {
            return .taiwan
        }
        if n.contains("韩国") || n.contains("KR") || n.contains("KOREA") || n.contains("首尔") {
            return .korea
        }
        if n.contains("英国") || n.contains("UK") || n.contains("德国") || n.contains("DE") || n.contains("法国") || n.contains("FR") || n.contains("欧洲") || n.contains("EU") {
            return .europe
        }
        return .other
    }
}

/// Real-time status snapshot of the local Clash/Mihomo daemon.
public struct ClashStatusSnapshot: Sendable, Equatable {
    public let isRunning: Bool
    public let clientKind: ClashClientKind?
    public let mode: ClashRoutingMode
    public let mixedPort: Int
    public let socksPort: Int
    public let httpPort: Int
    public let isTunEnabled: Bool
    public let uploadBytesPerSec: UInt64
    public let downloadBytesPerSec: UInt64
    public let totalUploadBytes: UInt64
    public let totalDownloadBytes: UInt64
    public let activeConnectionCount: Int
    public let controllerEndpoint: String

    public init(
        isRunning: Bool = false,
        clientKind: ClashClientKind? = nil,
        mode: ClashRoutingMode = .rule,
        mixedPort: Int = 7890,
        socksPort: Int = 7891,
        httpPort: Int = 0,
        isTunEnabled: Bool = false,
        uploadBytesPerSec: UInt64 = 0,
        downloadBytesPerSec: UInt64 = 0,
        totalUploadBytes: UInt64 = 0,
        totalDownloadBytes: UInt64 = 0,
        activeConnectionCount: Int = 0,
        controllerEndpoint: String = ""
    ) {
        self.isRunning = isRunning
        self.clientKind = clientKind
        self.mode = mode
        self.mixedPort = mixedPort
        self.socksPort = socksPort
        self.httpPort = httpPort
        self.isTunEnabled = isTunEnabled
        self.uploadBytesPerSec = uploadBytesPerSec
        self.downloadBytesPerSec = downloadBytesPerSec
        self.totalUploadBytes = totalUploadBytes
        self.totalDownloadBytes = totalDownloadBytes
        self.activeConnectionCount = activeConnectionCount
        self.controllerEndpoint = controllerEndpoint
    }
}
