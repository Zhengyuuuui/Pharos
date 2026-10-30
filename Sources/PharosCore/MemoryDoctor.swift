import Foundation

/// Categories of bloated user daemons.
public enum DaemonCategory: String, CaseIterable, Sendable {
    case mediaAI
    case desktopUI
    case indexing
}

/// Health evaluation for a daemon process or family.
public enum DaemonHealthStatus: String, CaseIterable, Sendable {
    case healthy
    case bloated
    case critical
}

/// Known macOS background daemons known to leak or bloat memory over time.
public enum KnownBloatedDaemon: String, CaseIterable, Identifiable, Sendable {
    case mediaAnalysis
    case photoAnalysis
    case wallpaper
    case spotlight
    case openAndSavePanel
    case quickLook
    case iconServices
    case intelligencePlatform
    case suggest

    public var id: String { rawValue }

    public var category: DaemonCategory {
        switch self {
        case .mediaAnalysis, .photoAnalysis, .intelligencePlatform, .suggest:
            return .mediaAI
        case .wallpaper, .openAndSavePanel, .quickLook, .iconServices:
            return .desktopUI
        case .spotlight:
            return .indexing
        }
    }

    /// Primary display name
    public var primaryName: String {
        switch self {
        case .mediaAnalysis: return "mediaanalysisd"
        case .photoAnalysis: return "photoanalysisd"
        case .wallpaper: return "WallpaperVideoExtension"
        case .spotlight: return "corespotlightd"
        case .openAndSavePanel: return "openAndSavePanelService"
        case .quickLook: return "QuickLookUIService"
        case .iconServices: return "iconservicesagent"
        case .intelligencePlatform: return "intelligenceplatformd"
        case .suggest: return "suggestd"
        }
    }

    /// Target process names or binary suffixes to match against `ProcessSnapshot`.
    public var targetNames: [String] {
        switch self {
        case .mediaAnalysis:
            return ["mediaanalysisd", "mediaanalysisd-access"]
        case .photoAnalysis:
            return ["photoanalysisd"]
        case .wallpaper:
            return ["WallpaperVideoExtension", "WallpaperAgent"]
        case .spotlight:
            return ["corespotlightd", "mdworker_shared"]
        case .openAndSavePanel:
            return ["com.apple.appkit.xpc.openAndSavePanelService", "openAndSavePanelService"]
        case .quickLook:
            return ["QuickLookUIService", "QuickLookSatellite"]
        case .iconServices:
            return ["iconservicesagent"]
        case .intelligencePlatform:
            return ["intelligenceplatformd", "BiomeAgent"]
        case .suggest:
            return ["suggestd", "parsecd"]
        }
    }

    /// Recommended memory bloat threshold in bytes. Above this is `.bloated`.
    public var thresholdBytes: UInt64 {
        switch self {
        case .mediaAnalysis: return 300 * 1024 * 1024        // 300 MB
        case .photoAnalysis: return 300 * 1024 * 1024        // 300 MB
        case .wallpaper: return 400 * 1024 * 1024            // 400 MB
        case .spotlight: return 400 * 1024 * 1024            // 400 MB
        case .openAndSavePanel: return 100 * 1024 * 1024     // 100 MB
        case .quickLook: return 200 * 1024 * 1024            // 200 MB
        case .iconServices: return 200 * 1024 * 1024         // 200 MB
        case .intelligencePlatform: return 300 * 1024 * 1024  // 300 MB
        case .suggest: return 250 * 1024 * 1024              // 250 MB
        }
    }

    /// Critical threshold in bytes (> 1 GB).
    public var criticalThresholdBytes: UInt64 {
        1024 * 1024 * 1024 // 1 GB
    }

    /// Corresponding launchd service names if supported.
    public var launchdServiceNames: [String] {
        switch self {
        case .mediaAnalysis:
            return ["com.apple.mediaanalysisd", "com.apple.mediaanalysisd-access"]
        case .photoAnalysis:
            return ["com.apple.photoanalysisd"]
        default:
            return []
        }
    }

    public var supportsLaunchdToggle: Bool {
        !launchdServiceNames.isEmpty
    }

    public func matches(process: ProcessSnapshot) -> Bool {
        let name = process.name
        let exeLast = (process.executablePath as NSString?)?.lastPathComponent ?? ""
        let exePath = process.executablePath ?? ""
        for t in targetNames {
            if name == t || exeLast == t { return true }
            if exePath.hasSuffix("/" + t) { return true }
            if name.hasSuffix("." + t) || t.hasSuffix("." + name) { return true }
        }
        return false
    }
}

/// Diagnostic item for one daemon family.
public struct DaemonDiagnosisItem: Identifiable, Sendable, Hashable {
    public let daemon: KnownBloatedDaemon
    public let pids: [Int32]
    public let memoryBytes: UInt64
    public let status: DaemonHealthStatus
    public let isLaunchdDisabled: Bool
    public let processCount: Int

    public var id: String { daemon.rawValue }
    public var isRunning: Bool { !pids.isEmpty }
    public var isBloated: Bool { status == .bloated || status == .critical }

    public init(daemon: KnownBloatedDaemon, pids: [Int32], memoryBytes: UInt64,
                status: DaemonHealthStatus, isLaunchdDisabled: Bool = false, processCount: Int = 0) {
        self.daemon = daemon
        self.pids = pids
        self.memoryBytes = memoryBytes
        self.status = status
        self.isLaunchdDisabled = isLaunchdDisabled
        self.processCount = processCount > 0 ? processCount : pids.count
    }
}

/// Comprehensive report of bloated system daemons and memory diagnostics.
public struct MemoryDiagnosisReport: Sendable, Hashable {
    public let items: [DaemonDiagnosisItem]
    public let reclaimableBytes: UInt64
    public let scannedAt: Date

    public var runningItems: [DaemonDiagnosisItem] {
        items.filter(\.isRunning)
    }

    public var bloatedItems: [DaemonDiagnosisItem] {
        items.filter(\.isBloated)
    }

    public var hasBloat: Bool {
        !bloatedItems.isEmpty
    }

    public var bloatedCount: Int {
        bloatedItems.count
    }

    public var criticalCount: Int {
        items.filter { $0.status == .critical }.count
    }

    public var totalMonitoredBytes: UInt64 {
        items.reduce(0) { $0 + $1.memoryBytes }
    }

    public init(items: [DaemonDiagnosisItem], reclaimableBytes: UInt64, scannedAt: Date = Date()) {
        self.items = items
        self.reclaimableBytes = reclaimableBytes
        self.scannedAt = scannedAt
    }
}

/// Pure engine for inspecting bloated system daemons and safely reclaiming memory.
public enum MemoryDoctor {
    /// Pure diagnostic function evaluating process snapshots against known bloat signatures.
    public static func diagnose(
        processes: [ProcessSnapshot],
        disabledDaemons: Set<KnownBloatedDaemon> = []
    ) -> MemoryDiagnosisReport {
        var items: [DaemonDiagnosisItem] = []
        var totalReclaimable: UInt64 = 0

        for daemon in KnownBloatedDaemon.allCases {
            let matched = processes.filter { daemon.matches(process: $0) }
            let pids = matched.map(\.pid).sorted()
            let totalMem = matched.reduce(UInt64(0)) { $0 + $1.memoryBytes }
            let isDisabled = disabledDaemons.contains(daemon)

            let status: DaemonHealthStatus
            if totalMem >= daemon.criticalThresholdBytes {
                status = .critical
            } else if totalMem >= daemon.thresholdBytes {
                status = .bloated
            } else {
                status = .healthy
            }

            if status == .bloated || status == .critical {
                totalReclaimable += totalMem
            }

            items.append(DaemonDiagnosisItem(
                daemon: daemon,
                pids: pids,
                memoryBytes: totalMem,
                status: status,
                isLaunchdDisabled: isDisabled,
                processCount: matched.count
            ))
        }

        // Sort items: critical first, then bloated, then by memory descending
        items.sort { a, b in
            if a.status != b.status {
                return rank(a.status) < rank(b.status)
            }
            if a.memoryBytes != b.memoryBytes {
                return a.memoryBytes > b.memoryBytes
            }
            if a.isRunning != b.isRunning {
                return a.isRunning && !b.isRunning
            }
            return a.daemon.primaryName < b.daemon.primaryName
        }

        return MemoryDiagnosisReport(items: items, reclaimableBytes: totalReclaimable)
    }

    private static func rank(_ s: DaemonHealthStatus) -> Int {
        switch s {
        case .critical: return 0
        case .bloated: return 1
        case .healthy: return 2
        }
    }

    // MARK: - Safe Reclamation

    /// Reclaims memory by terminating the specified PIDs (SIGTERM, waits 800ms, then SIGKILL if alive).
    /// Strictly verifies: pid > 1, pid != current PID, and belongs to current user.
    @discardableResult
    public static func reclaim(pids: [Int32]) async -> Int {
        let myUID = getuid()
        let myPID = getpid()
        let validPIDs = pids.filter { pid in
            guard pid > 1, pid != myPID else { return false }
            if let info = ProcessScanner.bsdInfo(pid) {
                return info.pbi_uid == myUID
            }
            return false
        }
        guard !validPIDs.isEmpty else { return 0 }

        ProcessControl.send(.terminate, to: validPIDs)
        try? await Task.sleep(nanoseconds: 800_000_000)

        let stillAlive = validPIDs.filter { ProcessControl.isAlive($0) }
        if !stillAlive.isEmpty {
            ProcessControl.send(.kill, to: stillAlive)
        }
        return validPIDs.count
    }

    /// Reclaims all bloated and critical daemons in the diagnosis report.
    @discardableResult
    public static func reclaimAllBloated(in report: MemoryDiagnosisReport) async -> Int {
        let pidsToKill = report.bloatedItems.flatMap(\.pids)
        return await reclaim(pids: pidsToKill)
    }

    // MARK: - launchctl Service Control

    /// Queries disabled services for the given user via `/bin/launchctl print-disabled gui/<uid>`.
    public static func queryDisabledServices(uid: uid_t = getuid()) -> Set<String> {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["print-disabled", "gui/\(uid)"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(decoding: data, as: UTF8.self)
            var disabled = Set<String>()
            for line in text.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.contains("=> disabled") || trimmed.contains("=> true") else { continue }
                if let firstQuote = trimmed.firstIndex(of: "\""),
                   let secondQuote = trimmed[trimmed.index(after: firstQuote)...].firstIndex(of: "\"") {
                    let service = String(trimmed[trimmed.index(after: firstQuote)..<secondQuote])
                    disabled.insert(service)
                }
            }
            return disabled
        } catch {
            return []
        }
    }

    /// Queries whether any known daemon is disabled in launchd.
    public static func queryDisabledDaemons(uid: uid_t = getuid()) -> Set<KnownBloatedDaemon> {
        let disabledServices = queryDisabledServices(uid: uid)
        var result = Set<KnownBloatedDaemon>()
        for daemon in KnownBloatedDaemon.allCases where daemon.supportsLaunchdToggle {
            if daemon.launchdServiceNames.allSatisfy({ disabledServices.contains($0) }) {
                result.insert(daemon)
            }
        }
        return result
    }

    public static func isDaemonDisabled(_ daemon: KnownBloatedDaemon, uid: uid_t = getuid()) -> Bool {
        guard daemon.supportsLaunchdToggle else { return false }
        let disabledServices = queryDisabledServices(uid: uid)
        return daemon.launchdServiceNames.allSatisfy { disabledServices.contains($0) }
    }

    public static func setDaemonDisabled(_ disabled: Bool, daemon: KnownBloatedDaemon, uid: uid_t = getuid()) {
        guard daemon.supportsLaunchdToggle else { return }
        for service in daemon.launchdServiceNames {
            setServiceDisabled(disabled, service: service, uid: uid)
        }
    }

    public static func setServiceDisabled(_ disabled: Bool, service: String, uid: uid_t = getuid()) {
        if disabled {
            let p1 = Process()
            p1.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            p1.arguments = ["disable", "gui/\(uid)/\(service)"]
            try? p1.run()
            p1.waitUntilExit()

            let p2 = Process()
            p2.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            p2.arguments = ["bootout", "gui/\(uid)/\(service)"]
            try? p2.run()
            p2.waitUntilExit()
        } else {
            let p1 = Process()
            p1.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            p1.arguments = ["enable", "gui/\(uid)/\(service)"]
            try? p1.run()
            p1.waitUntilExit()
        }
    }
}
