import Foundation
import Darwin

/// Category of process or workload diagnosed as generating notable heat or running abnormally.
public enum CPUCulpritCategory: String, Codable, Sendable {
    case runawayOrphan        // Detached orphan script without listening ports eating CPU
    case highWorkload         // Sustained high load (>= 70%) on an active task or server
    case compiler             // Parallel compiler / build tools
    case thermalInducement    // Non-trivial load maintaining high thermal state when machine is hot
}

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
    public let category: CPUCulpritCategory
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
        category: CPUCulpritCategory = .highWorkload,
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
        self.category = category
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

/// Thread-safe tracker computing differential CPU usage across sampling intervals with rate smoothing.
public final class CPURateTracker: @unchecked Sendable {
    public static let shared = CPURateTracker()

    private struct SampleState {
        var timestamp: TimeInterval
        var cpuTimeNs: UInt64
        var smoothedCpuPercent: Double
        var highCpuStreak: Int
    }

    private let lock = NSLock()
    private var previousSamples: [Int32: SampleState] = [:]

    public init() {}

    /// Calculates smoothed CPU% for a process given its cumulative CPU time (nanoseconds).
    /// Uses differential rate `Δcpu_time / Δwall_time * 100` when a previous sample exists;
    /// for newly observed existing processes, starts baseline at 0.0% to avoid historical noise.
    public func sample(pid: Int32, cpuTimeNs: UInt64, startTime: Date?, now: Date = Date()) -> Double {
        lock.lock()
        defer { lock.unlock() }

        let nowSec = now.timeIntervalSince1970
        let prev = previousSamples[pid]

        if let prev, (nowSec - prev.timestamp) >= 0.2 {
            let dt = nowSec - prev.timestamp
            let dCpuNs = cpuTimeNs >= prev.cpuTimeNs ? (cpuTimeNs - prev.cpuTimeNs) : 0
            let dCpuSec = Double(dCpuNs) / 1_000_000_000.0
            let instantPct = max(0.0, (dCpuSec / dt) * 100.0)

            // Exponential Moving Average (EMA) smoothing to eliminate single-tick flutter
            let smoothed = prev.smoothedCpuPercent > 0
                ? (prev.smoothedCpuPercent * 0.35 + instantPct * 0.65)
                : instantPct

            let streak = instantPct >= 40.0 ? (prev.highCpuStreak + 1) : 0
            previousSamples[pid] = SampleState(
                timestamp: nowSec,
                cpuTimeNs: cpuTimeNs,
                smoothedCpuPercent: smoothed,
                highCpuStreak: streak
            )
            return smoothed
        }

        // If process just launched (< 2.0s ago), compute its initial average
        if let startTime {
            let elapsed = max(0.1, now.timeIntervalSince(startTime))
            if elapsed <= 2.0 {
                let cpuSec = Double(cpuTimeNs) / 1_000_000_000.0
                let initialAvg = max(0.0, (cpuSec / elapsed) * 100.0)
                previousSamples[pid] = SampleState(
                    timestamp: nowSec,
                    cpuTimeNs: cpuTimeNs,
                    smoothedCpuPercent: initialAvg,
                    highCpuStreak: initialAvg >= 40.0 ? 1 : 0
                )
                return initialAvg
            }
        }

        // First observation baseline for already-running processes: 0.0% until next tick
        previousSamples[pid] = SampleState(
            timestamp: nowSec,
            cpuTimeNs: cpuTimeNs,
            smoothedCpuPercent: 0.0,
            highCpuStreak: 0
        )
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

        // Thermal-Coupled Dynamic Thresholds
        let temp = chipTemperature ?? 50.0
        let highCpuThreshold: Double = {
            if temp >= 85.0 { return 40.0 }
            if temp >= 75.0 { return 50.0 }
            if temp >= 65.0 { return 60.0 }
            return 70.0
        }()

        let orphanCpuThreshold: Double = {
            if temp >= 85.0 { return 30.0 }
            if temp >= 75.0 { return 40.0 }
            return 50.0
        }()

        let compilerCpuThreshold: Double = {
            if temp >= 85.0 { return 35.0 }
            if temp >= 75.0 { return 45.0 }
            return 55.0
        }()

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
            let hasPorts = !p.ports.isEmpty

            // 1. Port Immunity: Listening servers (APIs, databases, web servers) are intentional services.
            // Unless they breach true runaway high-load redline, they are 100% exempt from the heat culprit list!
            if hasPorts && cpuPct < highCpuThreshold {
                continue
            }

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
            var category: CPUCulpritCategory = .highWorkload
            var reason = ""

            // Rule 1: True Runaway Orphan (ppid == 1, no listening ports, dev/script with actual high CPU)
            if isOrphan && !hasPorts && isDevOrScript && cpuPct >= orphanCpuThreshold {
                isCulprit = true
                category = .runawayOrphan
                reason = "脱离终端且无网络监听的孤儿脚本，持续占用高额算力"
            }
            // Rule 2: Active Heavy Compiler / Build Tool
            else if isCompiler && cpuPct >= compilerCpuThreshold {
                isCulprit = true
                category = .compiler
                reason = "多核并发编译构建进程，密集调用 CPU 性能核心释放峰值功耗"
            }
            // Rule 3: Heavy Ongoing Workload / Runaway Task (>= highCpuThreshold)
            else if cpuPct >= highCpuThreshold {
                isCulprit = true
                if temp >= 75.0 && cpuPct < 70.0 {
                    category = .thermalInducement
                    reason = "机身处于高热状态，该进程高算力消耗加剧机身积热"
                } else {
                    category = .highWorkload
                    reason = "持续高负载运行，是当前芯片升温的主要原因"
                }
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
                    category: category,
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
