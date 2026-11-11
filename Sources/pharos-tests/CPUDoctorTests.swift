import Foundation
import PharosCore

func testCPUDoctorNominal() {
    let procs = [
        ProcessSnapshot(pid: 200, ppid: 100, name: "TextEdit", memoryBytes: 50 * 1024 * 1024, cpuTimeNs: 10_000_000, cpuPercent: 0.5),
        ProcessSnapshot(pid: 201, ppid: 100, name: "Calculator", memoryBytes: 30 * 1024 * 1024, cpuTimeNs: 5_000_000, cpuPercent: 0.1)
    ]

    let report = CPUDoctor.diagnose(processes: procs, chipTemperature: 50.0)

    expectEq(report.isNominal, true, "nominal state when cpu load is low")
    expectEq(report.processes.isEmpty, true, "no culprits in nominal state")
}

func testCPUDoctorHighCPURunaway() {
    let procs = [
        ProcessSnapshot(
            pid: 5001,
            ppid: 100,
            name: "stress",
            executablePath: "/usr/local/bin/stress",
            arguments: ["stress", "--cpu", "4"],
            memoryBytes: 120 * 1024 * 1024,
            cpuTimeNs: 50_000_000_000,
            cpuPercent: 99.0
        )
    ]

    let report = CPUDoctor.diagnose(processes: procs, chipTemperature: 85.0)

    expectEq(report.isNominal, false, "not nominal when high CPU process exists")
    expectEq(report.processes.count, 1, "found 1 runaway process")
    let p = report.processes.first!
    expectEq(p.pid, 5001, "pid matches")
    expectEq(p.name, "stress", "name matches")
    expectEq(p.cpuPercent, 99.0, "cpu% matches")
    expect(p.explanation.contains("持续高负载运行"), "explanation notes sustained high cpu")
}

func testCPUDoctorOrphanScript() {
    let procs = [
        ProcessSnapshot(
            pid: 6002,
            ppid: 1, // orphaned!
            name: "python3",
            executablePath: "/opt/homebrew/bin/python3",
            cwd: "/Users/dev/train",
            arguments: ["python3", "worker.py", "--concurrency", "4"],
            memoryBytes: 350 * 1024 * 1024,
            cpuTimeNs: 12_000_000_000,
            cpuPercent: 28.0
        )
    ]

    let report = CPUDoctor.diagnose(processes: procs, chipTemperature: 65.0)

    expectEq(report.processes.count, 1, "found orphaned python worker")
    let p = report.processes.first!
    expectEq(p.pid, 6002, "pid matches")
    expectEq(p.isOrphan, true, "isOrphan is true")
    expect(p.fullCommand.contains("worker.py"), "fullCommand contains args")
    expectEq(p.workingDirectory, "/Users/dev/train", "cwd matches")
    expect(p.explanation.contains("孤儿脚本"), "explanation notes orphaned script")
}

func testCPUDoctorSafeExclusions() {
    let procs = [
        ProcessSnapshot(pid: 1, ppid: 0, name: "launchd", memoryBytes: 10 * 1024 * 1024, cpuPercent: 80.0),
        ProcessSnapshot(pid: 88, ppid: 1, name: "WindowServer", memoryBytes: 200 * 1024 * 1024, cpuPercent: 95.0),
        ProcessSnapshot(pid: getpid(), ppid: 1, name: "Pharos", memoryBytes: 50 * 1024 * 1024, cpuPercent: 85.0)
    ]

    let report = CPUDoctor.diagnose(processes: procs, chipTemperature: 90.0)

    expectEq(report.isNominal, true, "system critical processes and self are safely excluded")
    expectEq(report.processes.isEmpty, true, "no culprits returned for excluded processes")
}

func testCPURateTrackerDifferential() {
    let tracker = CPURateTracker()
    let t0 = Date(timeIntervalSince1970: 1000.0)
    let t1 = Date(timeIntervalSince1970: 1001.0) // +1.0s

    // First sample (fallback average)
    let r0 = tracker.sample(pid: 999, cpuTimeNs: 1_000_000_000, startTime: t0, now: t0)
    expect(r0 >= 0, "first sample non-negative")

    // Second sample at +1s with +0.8s CPU burned -> 80%
    let r1 = tracker.sample(pid: 999, cpuTimeNs: 1_800_000_000, startTime: t0, now: t1)
    expect(abs(r1 - 80.0) < 0.1, "differential rate calculation matches 80%")
}

func testCPUDoctorDurationFormatting() {
    expectEq(CPUDoctor.formatDuration(45), "45s", "under 1m formatted as seconds")
    expectEq(CPUDoctor.formatDuration(125), "2m 5s", "minutes and seconds")
    expectEq(CPUDoctor.formatDuration(3665), "1h 1m", "hours and minutes")
}
