import Foundation
import PharosCore

func testThermalDoctorCool() {
    let thermals = ThermalSnapshot(
        fans: [FanReading(index: 0, actualRPM: 1800, targetRPM: 1800, minRPM: 1200, maxRPM: 5500, mode: .system)],
        groups: [.cpu: 48.0, .gpu: 44.0, .battery: 31.0]
    )
    let processes = [
        ProcessSnapshot(pid: 200, ppid: 1, name: "Finder", memoryBytes: 80 * 1024 * 1024)
    ]
    let battery = BatteryReading(currentPercent: 85, isCharging: false, powerSource: .battery)

    let report = ThermalDoctor.diagnose(
        thermals: thermals,
        thermalState: .nominal,
        processes: processes,
        battery: battery
    )

    expect(report.level == .cool, "overall status is cool")
    expectEq(report.culprits.isEmpty, true, "no culprits in cool idle state")
    expect(report.reasons.contains { $0.severity == ThermalSeverityLevel.cool }, "has optimal thermal condition reason")
}

func testThermalDoctorFastCharging() {
    let thermals = ThermalSnapshot(
        fans: [FanReading(index: 0, actualRPM: 0, targetRPM: 0, minRPM: 0, maxRPM: 5500, mode: .system)],
        groups: [.cpu: 62.0, .battery: 36.5, .power: 58.0]
    )
    let battery = BatteryReading(
        currentPercent: 45,
        temperatureCelsius: 37.0,
        watts: 85.0,
        isCharging: true,
        powerSource: .acPower,
        adapterWatts: 96
    )

    let report = ThermalDoctor.diagnose(
        thermals: thermals,
        thermalState: .fair,
        processes: [],
        battery: battery
    )

    expect(report.level == .warm, "fast charging elevates to warm")
    expectEq(report.isChargingHeat, true, "isChargingHeat is true")
    expect(report.reasons.contains { $0.icon == "bolt.fill" }, "has fast charging reason")
}

func testThermalDoctorSilentFanLag() {
    let thermals = ThermalSnapshot(
        fans: [FanReading(index: 0, actualRPM: 0, targetRPM: 0, minRPM: 1200, maxRPM: 5500, mode: .system)],
        groups: [.cpu: 78.5, .gpu: 76.0]
    )
    let processes = [
        ProcessSnapshot(pid: 501, ppid: 1, name: "node", memoryBytes: 300 * 1024 * 1024)
    ]

    let report = ThermalDoctor.diagnose(
        thermals: thermals,
        thermalState: .fair,
        processes: processes,
        battery: nil
    )

    expectEq(report.isFanLagging, true, "silent fan lag detected when chip is 78C and fans at 0 RPM")
    expect(report.reasons.contains { $0.icon == "fanblades.slash" }, "silent fan delay reason present")
    expect(report.suggestions.contains { $0.actionKind == .maxFans }, "suggests ramping up fans")
}

func testThermalDoctorCompilerAndMediaCulprits() {
    let thermals = ThermalSnapshot(
        fans: [FanReading(index: 0, actualRPM: 3800, targetRPM: 3800, minRPM: 1200, maxRPM: 5500, mode: .system)],
        groups: [.cpu: 84.0, .gpu: 65.0]
    )
    let processes = [
        ProcessSnapshot(pid: 1024, ppid: 1, name: "swift-frontend", memoryBytes: 950 * 1024 * 1024),
        ProcessSnapshot(pid: 1025, ppid: 1, name: "mediaanalysisd", memoryBytes: 420 * 1024 * 1024),
        ProcessSnapshot(pid: 1026, ppid: 1, name: "mdworker_shared", memoryBytes: 150 * 1024 * 1024)
    ]

    let report = ThermalDoctor.diagnose(
        thermals: thermals,
        thermalState: .serious,
        processes: processes,
        battery: nil
    )

    expect(report.level == .hot, "elevated to hot")
    expect(report.culprits.contains { $0.name == "swift-frontend" && $0.category == .compiler }, "swift-frontend classified as compiler")
    expect(report.culprits.contains { $0.name == "mediaanalysisd" && $0.category == .mediaIndexing }, "mediaanalysisd classified as mediaIndexing")
    expect(report.culprits.contains { $0.name == "mdworker_shared" && $0.category == .systemIndexing }, "mdworker classified as systemIndexing")
    expect(report.reasons.contains { $0.icon == "hammer.fill" }, "compiler reason present")
    expect(report.reasons.contains { $0.icon == "photo.stack.fill" }, "media analysis reason present")
}

func testThermalDoctorThrottling() {
    let thermals = ThermalSnapshot(
        fans: [FanReading(index: 0, actualRPM: 5200, targetRPM: 5200, minRPM: 1200, maxRPM: 5500, mode: .system)],
        groups: [.cpu: 96.0, .gpu: 92.0]
    )

    let report = ThermalDoctor.diagnose(
        thermals: thermals,
        thermalState: .critical,
        processes: [],
        battery: nil
    )

    expect(report.level == .critical, "critical severity")
    expect(report.reasons.contains { $0.icon == "exclamationmark.triangle.fill" }, "throttling reason present")
    expect(report.suggestions.contains { $0.actionKind == .openEnergySettings }, "suggests low energy mode")
}
