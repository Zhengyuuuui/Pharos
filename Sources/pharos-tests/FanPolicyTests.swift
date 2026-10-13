import Foundation
import PharosCore

func testFanPolicy() {
    let fans = [
        FanReading(index: 0, actualRPM: 0, targetRPM: 2317, minRPM: 2317, maxRPM: 6800, mode: .system),
        FanReading(index: 1, actualRPM: 0, targetRPM: 2317, minRPM: 2317, maxRPM: 6800, mode: .system),
    ]
    let now = Date(timeIntervalSince1970: 1_000_000)
    var s = FanPolicy.State()
    func run(_ r: FanRequest, _ t: Double, beat: Date? = now) -> FanPolicy.Action {
        FanPolicy.decide(request: r, fans: fans, chipCelsius: t, lastHeartbeat: beat, now: now, state: &s)
    }

    expectEq(run(.system, 60), .release, "system → release")
    expectEq(run(.max, 60), .hold([6800, 6800]), "max → each fan's max")
    expectEq(run(.fixed(rpm: 4000), 60), .hold([4000, 4000]), "fixed in range")
    expectEq(run(.fixed(rpm: 500), 60), .hold([2317, 2317]), "fixed clamped up to min")
    expectEq(run(.fixed(rpm: 99_999), 60), .hold([6800, 6800]), "fixed clamped down to max")

    expectEq(run(.fixed(rpm: 3000), 60, beat: now.addingTimeInterval(-16)), .release,
             "no heartbeat for >15 s → hand back to macOS")
    expectEq(run(.fixed(rpm: 3000), 60, beat: nil), .release, "never pinged → release")

    expectEq(run(.fixed(rpm: 3000), 96), .hold([6800, 6800]), "≥95 °C → max even on a low fixed RPM")
    expect(s.overheating, "overheat latched")
    expectEq(run(.fixed(rpm: 3000), 90), .hold([6800, 6800]), "90 °C is still above release (88) → stay max")
    expectEq(run(.fixed(rpm: 3000), 96, beat: nil), .hold([6800, 6800]), "overheat wins over a missing heartbeat")
    expectEq(run(.fixed(rpm: 3000), 85), .hold([3000, 3000]), "below 88 °C → back to request")
    expect(!s.overheating, "overheat released")
    _ = run(.system, 97)
    expectEq(run(.system, 97), .release, "system control while hot: leave it to macOS")
}

func testFanProtocol() {
    for c: FanProtocol.Command in [.status, .heartbeat, .set(.system), .set(.max), .set(.fixed(rpm: 4200))] {
        expectEq(FanProtocol.decode(FanProtocol.encode(c)), c, "round-trip \(FanProtocol.encode(c))")
    }
    expectEq(FanProtocol.decode("fixed"), nil, "missing RPM rejected")
    expectEq(FanProtocol.decode("fixed -5"), nil, "negative RPM rejected")
    expectEq(FanProtocol.decode("fixed 4000 now"), nil, "extra words rejected")
    expectEq(FanProtocol.decode("write F0Md 1"), nil, "arbitrary SMC writes impossible")
    expectEq(FanProtocol.decode(""), nil, "empty rejected")
}
