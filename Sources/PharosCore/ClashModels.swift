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
    case genericMihomo = "Mihomo Core"

    public var iconName: String {
        switch self {
        case .mihomoParty: return "party.popper.fill"
        case .clashVerge: return "shield.lefthalf.filled"
        case .clashNyanpasu: return "cat.fill"
        case .clashX: return "paperplane.fill"
        case .flclash: return "bolt.shield.fill"
        case .genericMihomo: return "network"
        }
    }
}

/// Proxy isolation strategy configured for a browser instance.
public enum BrowserProxyStrategy: Hashable, Sendable, Codable {
    case followSystem
    case direct
    case clashMixedPort(Int)
    case custom(String)

    public var isDirect: Bool {
        if case .direct = self { return true }
        return false
    }

    public var isClash: Bool {
        if case .clashMixedPort = self { return true }
        return false
    }

    public var badgeText: String {
        switch self {
        case .followSystem: return "System"
        case .direct: return "Direct"
        case .clashMixedPort(let port): return "Clash :\(port)"
        case .custom(let s): return s
        }
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
