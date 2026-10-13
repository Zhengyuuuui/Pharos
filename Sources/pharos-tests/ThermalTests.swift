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
