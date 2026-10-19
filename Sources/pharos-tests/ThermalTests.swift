import Foundation
import PharosCore

func testSMCCodec() {
    expectEq(SMCCodec.fourCC("FNum"), 0x464E_756D, "fourCC")
    expectEq(SMCCodec.string(0x464E_756D), "FNum", "fourCC back to string")
    expectEq(SMCCodec.float([0x00, 0x00, 0x48, 0x42]), 50, "flt little-endian 50.0")
    expectEq(SMCCodec.bytes(2317), [0x00, 0xD0, 0x10, 0x45], "float → bytes")
    expectEq(SMCCodec.float(SMCCodec.bytes(6800)), 6800, "float round-trip")
    expectEq(SMCCodec.ioft([0x00, 0x80, 0x2D, 0x00, 0, 0, 0, 0]), 45.5, "ioft 16.16")
    expectEq(SMCCodec.float([1, 2, 3]), nil, "wrong size → nil")
}

func testThermalGrouping() {
    // Keys and values seen on this M3 Pro, plus junk the SMC also returns.
    let raw: [String: Float] = [
        "Tp05": 55.2, "Tp0E": 62.4, "Te06": 56, "TCMz": 73.1,
        "Tg05": 47.7, "Tg0D": 46,
        "TRDX": 44, "TH0x": 32, "TB0T": 30.6, "TPD0": 41, "TaLP": 36.9,
        "Ta05": -3, "Tz11": 0, "TVHC": 7, "Tf16": 80,
    ]
    let g = ThermalSnapshot.groupTemperatures(raw)
    expectEq(g[.cpu], 73.1, "CPU = hottest of TC/Tp/Te")
    expectEq(g[.gpu], 47.7, "GPU")
    expectEq(g[.memory], 44, "memory")
    expectEq(g[.ssd], 32, "SSD")
    expectEq(g[.battery], 30.6, "battery")
    expectEq(g[.power], 41, "power (TP, not Tp)")
    expectEq(g[.ambient], 36.9, "ambient; negative Ta05 dropped")
    expectEq(SensorGroup.group(for: "Tz11"), nil, "unknown prefixes aren't guessed")
    expectEq(SensorGroup.group(for: "Tf16"), nil, "Tf isn't a known group")

    let snap = ThermalSnapshot(fans: [], groups: g)
    expectEq(snap.peakChipTemperature, 73.1, "peak chip temperature = max(CPU, GPU)")

    let fan = FanReading(index: 0, actualRPM: 3400, targetRPM: 3400, minRPM: 2317, maxRPM: 6800, mode: .system)
    expectEq(fan.fraction, 0.5, "fraction of max")
    expectEq(FanReading.mode(3), .system, "mode 3 = system")
    expectEq(FanReading.mode(1), .manual, "mode 1 = manual")
}

func testThermalsLive() {
    // Read-only; skipped silently on machines without an SMC (CI VMs).
    guard let snap = Thermals.read() else { return }
    expect(snap.fans.allSatisfy { $0.maxRPM >= $0.minRPM }, "live: fan ranges are sane")
    expect((snap.peakChipTemperature ?? 50) > 5, "live: chip temperature is plausible")
}

func testFanGaugeScale() {
    let scale = FanGaugeScale(minRPM: 2317, maxRPM: 6800)
    expectEq(scale.maxScale, 7000, "6800 rounded to next 1000 = 7000")
    expectEq(scale.redlineRPM, 5700, "85% of 6800 = 5780 rounded to 5700")
    expectEq(scale.startAngle, 135.0, "startAngle default 135")
    expectEq(scale.sweepAngle, 270.0, "sweepAngle default 270")

    // Progress fractions
    expectEq(scale.fraction(for: 0), 0.0, "fraction 0 RPM = 0")
    expectEq(scale.fraction(for: 3500), 0.5, "fraction 3500 RPM on 7000 = 0.5")
    expectEq(scale.fraction(for: 7000), 1.0, "fraction 7000 RPM = 1.0")
    expectEq(scale.fraction(for: 8000), 1.0, "fraction over maxScale clamped to 1.0")

    // Angles
    expectEq(scale.angle(for: 0), 135.0, "angle at 0 RPM = 135 deg")
    expectEq(scale.angle(for: 3500), 270.0, "angle at 3500 RPM = 270 deg (top dead center)")
    expectEq(scale.angle(for: 7000), 405.0, "angle at 7000 RPM = 405 deg")

    // Redline checking
    expect(!scale.isRedline(rpm: 3000), "3000 RPM not redline")
    expect(!scale.isRedline(rpm: 5699), "5699 RPM not redline")
    expect(scale.isRedline(rpm: 5700), "5700 RPM is redline")
    expect(scale.isRedline(rpm: 6800), "6800 RPM is redline")

    // Ticks
    expectEq(scale.majorTicks.count, 8, "8 major ticks: 0k to 7k")
    expectEq(scale.majorTicks.first, 0, "first major tick is 0")
    expectEq(scale.majorTicks.last, 7000, "last major tick is 7000")
    expectEq(scale.mediumTicks.count, 7, "7 medium ticks: 500 to 6500")
    expectEq(scale.minorTicksCount, 70, "70 minor ticks at 100-rpm increments")
    expectEq(scale.minorTickRPM(at: 10), 1000, "minor tick index 10 is 1000 RPM")
}

