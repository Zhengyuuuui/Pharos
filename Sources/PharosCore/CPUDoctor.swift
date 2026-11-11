import Foundation
import Darwin

/// A process diagnosed as causing notable CPU load or thermal rise, or running as an orphaned background task.
public struct CPURunawayProcess: Identifiable, Hashable, Sendable, Codable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let ppid: Int32
    public let name: String
    public let cpuPercent: Double
    public let memoryBytes: UInt64
    public let elapsedTimeSeconds: Double
    public let fullCommand: String
    public let workingDirectory: String?
    public let isOrphan: Bool
    public let isCompilerOrBuild: Bool
    public let explanation: String
    public let isKillable: Bool

    public init(
        pid: Int32,
        ppid: Int32,
        name: String,
        cpuPercent: Double,
        memoryBytes: UInt64,
        elapsedTimeSeconds: Double,
        fullCommand: String,
        workingDirectory: String?,
        isOrphan: Bool,
        isCompilerOrBuild: Bool,
        explanation: String,
        isKillable: Bool = true
    ) {
        self.pid = pid
        self.ppid = ppid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.elapsedTimeSeconds = elapsedTimeSeconds
        self.fullCommand = fullCommand
        self.workingDirectory = workingDirectory
        self.isOrphan = isOrphan
        self.isCompilerOrBuild = isCompilerOrBuild
        self.explanation = explanation
        self.isKillable = isKillable
    }

    public var formattedElapsedTime: String {
        CPUDoctor.formatDuration(elapsedTimeSeconds)
    }
}

/// Diagnostic report containing identified runaway, high-load, or orphaned tasks.
public struct CPUDiagnosisReport: Sendable, Codable, Equatable {
    public let processes: [CPURunawayProcess]
    public let isNominal: Bool
    public let peakCpuPercent: Double

    public init(processes: [CPURunawayProcess]) {
        self.processes = processes
        self.isNominal = processes.isEmpty
        self.peakCpuPercent = processes.map(\.cpuPercent).max() ?? 0.0
    }

    public static let nominal = CPUDiagnosisReport(processes: [])
}

/// Thread-safe tracker computing differential CPU usage across sampling intervals.
public final class CPURateTracker: @unchecked Sendable {
    public static let shared = CPURateTracker()

    private let lock = NSLock()
    private var previousSamples: [Int32: (timestamp: TimeInterval, cpuTimeNs: UInt64)] = [:]

    public init() {}

    /// Calculates CPU% for a process given its cumulative CPU time (nanoseconds).
    /// Uses differential rate `Δcpu_time / Δwall_time * 100` when a previous sample exists;
    /// otherwise falls back to lifetime average `(cpu_time / elapsed_time) * 100`.
    public func sample(pid: Int32, cpuTimeNs: UInt64, startTime: Date?, now: Date = Date()) -> Double {
        lock.lock()
        defer { lock.unlock() }

        let nowSec = now.timeIntervalSince1970
        let prev = previousSamples[pid]
        previousSamples[pid] = (nowSec, cpuTimeNs)

        if let prev, (nowSec - prev.timestamp) >= 0.2 {
            let dt = nowSec - prev.timestamp
            let dCpuNs = cpuTimeNs >= prev.cpuTimeNs ? (cpuTimeNs - prev.cpuTimeNs) : 0
            let dCpuSec = Double(dCpuNs) / 1_000_000_000.0
            let pct = (dCpuSec / dt) * 100.0
            return max(0.0, pct)
        }

        // Fallback: lifetime average CPU%
        if let startTime {
            let elapsed = max(0.2, now.timeIntervalSince(startTime))
            let cpuSec = Double(cpuTimeNs) / 1_000_000_000.0
            let pct = (cpuSec / elapsed) * 100.0
            return max(0.0, pct)
        }

        return 0.0
    }

    /// Prunes stale entries for dead PIDs
    public func prune(activePIDs: Set<Int32>) {
        lock.lock()
        defer { lock.unlock() }
        previousSamples = previousSamples.filter { activePIDs.contains($0.key) }
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        previousSamples.removeAll()
    }
}

/// Pure-logic engine diagnosing runaway high-load tasks and orphaned background scripts.
public enum CPUDoctor {
    public static func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(max(0, s))s" }
        let m = s / 60
        let remS = s % 60
        if m < 60 { return "\(m)m \(remS)s" }
        let h = m / 60
        let remM = m % 60
        return "\(h)h \(remM)m"
    }

    public static func diagnose(
        processes: [ProcessSnapshot],
        chipTemperature: Double? = nil,
        now: Date = Date(),
        rateTracker: CPURateTracker = CPURateTracker.shared
    ) -> CPUDiagnosisReport {
        let me = getpid()
        var culprits: [CPURunawayProcess] = []

        let excludedNames: Set<String> = [
            "launchd", "windowserver", "loginwindow", "coreaudiod",
            "kernel_task", "pharos", "systemuiserver", "dock", "finder"
        ]

        let activePIDs = Set(processes.map(\.pid))
        rateTracker.prune(activePIDs: activePIDs)

        for p in processes {
            guard p.pid > 1 && p.pid != me else { continue }
            let lowerName = p.name.lowercased()
            guard !excludedNames.contains(lowerName) else { continue }

            let cpuPct = p.cpuPercent ?? rateTracker.sample(
                pid: p.pid,
                cpuTimeNs: p.cpuTimeNs,
                startTime: p.startTime,
                now: now
            )

            let elapsed = p.elapsedTime ?? (p.startTime.map { max(0, now.timeIntervalSince($0)) } ?? 0)

            let isDevOrScript = lowerName.contains("python") || lowerName.contains("node") ||
                lowerName.contains("ruby") || lowerName.contains("bun") || lowerName.contains("deno") ||
                lowerName.contains("ffmpeg") || lowerName.contains("ffprobe") || lowerName.contains("java") ||
                lowerName.contains("go") || lowerName.contains("ollama") || lowerName.contains("whisper") ||
                lowerName.contains("llama") || lowerName.contains("pytest") || lowerName.contains("vite") ||
                lowerName.contains("webpack") || lowerName.contains("esbuild")

            let isCompiler = lowerName.contains("swift-frontend") || lowerName.contains("clang") ||
                lowerName.contains("rustc") || lowerName == "cargo" || lowerName == "xcodebuild"

            let isOrphan = p.ppid == 1

            var isCulprit = false
            var reason = ""

            // 1. High sustained CPU load (>= 70%)
            if cpuPct >= 70.0 {
                isCulprit = true
                reason = "持续高负载运行，是当前芯片升温的主要原因"
            }
            // 2. Orphaned dev/media script (ppid == 1) with active CPU or significant uptime
            else if isOrphan && isDevOrScript && (cpuPct >= 15.0 || p.cpuTimeNs >= 2_000_000_000 || elapsed >= 60.0) {
                isCulprit = true
                reason = "脱离父终端的孤儿脚本，持续占用系统后台算力"
            }
            // 3. Parallel compilation task
            else if isCompiler && (cpuPct >= 30.0 || p.cpuTimeNs >= 5_000_000_000) {
                isCulprit = true
                reason = "多核并发编译构建进程，密集调用 CPU 性能核心释放峰值功耗"
            }
            // 4. Elevated CPU load (>= 40%) when machine is already hot (>= 75°C)
            else if (chipTemperature ?? 0) >= 75.0 && cpuPct >= 40.0 {
                isCulprit = true
                reason = "机身处于高热状态，该进程高算力消耗加剧机身积热"
            }

            if isCulprit {
                var fullCmd = p.fullCommand
                if fullCmd == p.name {
                    let liveArgs = ProcessScanner.arguments(p.pid)
                    if !liveArgs.isEmpty {
                        fullCmd = liveArgs.joined(separator: " ")
                    }
                }
                let cwd = p.cwd ?? ProcessScanner.currentDirectory(p.pid)

                culprits.append(CPURunawayProcess(
                    pid: p.pid,
                    ppid: p.ppid,
                    name: p.name,
                    cpuPercent: cpuPct,
                    memoryBytes: p.memoryBytes,
                    elapsedTimeSeconds: elapsed,
                    fullCommand: fullCmd,
                    workingDirectory: cwd,
                    isOrphan: isOrphan,
                    isCompilerOrBuild: isCompiler,
                    explanation: reason,
                    isKillable: true
                ))
            }
        }

        // Sort: highest CPU% first, then memory footprint
        culprits.sort {
            if abs($0.cpuPercent - $1.cpuPercent) > 1.0 {
                return $0.cpuPercent > $1.cpuPercent
            }
            return $0.memoryBytes > $1.memoryBytes
        }

        return CPUDiagnosisReport(processes: Array(culprits.prefix(10)))
    }
}
