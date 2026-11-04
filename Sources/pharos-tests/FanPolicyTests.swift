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

    // Heartbeat timeout
    expectEq(run(.fixed(rpm: 3000), 60, beat: now.addingTimeInterval(-16)), .release,
             "no heartbeat for >15 s → hand back to macOS")
    expectEq(run(.fixed(rpm: 3000), 60, beat: nil), .release, "never pinged → release")

    // Fixed RPM is strictly fixed — no automatic curve acceleration or overheat override
    expectEq(run(.fixed(rpm: 3000), 96), .hold([3000, 3000]), "fixed RPM strictly holds chosen RPM even at 96°C")
    expect(!s.overheating, "fixed mode does not latch overheating")

    // Curve mode: cool temperature (<48°C) stays at minRPM
    var curveState = FanPolicy.State()
    let coolAction = FanPolicy.decide(request: .curve, fans: fans, chipCelsius: 45.0, lastHeartbeat: now, now: now, state: &curveState)
    expectEq(coolAction, .hold([2317, 2317]), "curve mode at 45°C starts at minRPM")

    // Curve mode: sudden high temperature accelerates smoothly (+150 RPM step limit)
    let warmAction1 = FanPolicy.decide(request: .curve, fans: fans, chipCelsius: 90.0, lastHeartbeat: now, now: now, state: &curveState)
    expectEq(warmAction1, .hold([2317 + 150, 2317 + 150]), "curve mode accelerates gradually (+150 RPM per tick)")

    let warmAction2 = FanPolicy.decide(request: .curve, fans: fans, chipCelsius: 90.0, lastHeartbeat: now, now: now, state: &curveState)
    expectEq(warmAction2, .hold([2317 + 300, 2317 + 300]), "curve mode second tick continues smooth acceleration (+150 RPM)")

    // Curve mode: sudden cool down decelerates gently (-80 RPM step limit)
    let coolDownAction = FanPolicy.decide(request: .curve, fans: fans, chipCelsius: 40.0, lastHeartbeat: now, now: now, state: &curveState)
    expectEq(coolDownAction, .hold([2317 + 300 - 80, 2317 + 300 - 80]), "curve mode decelerates gently (-80 RPM per tick)")

    // Curve mode: overheat latch at >= 95°C
    var overheatCurveState = FanPolicy.State()
    _ = FanPolicy.decide(request: .curve, fans: fans, chipCelsius: 96.0, lastHeartbeat: now, now: now, state: &overheatCurveState)
    expect(overheatCurveState.overheating, "curve mode latches overheat at >= 95°C")

    // Once below 88°C, overheat unlatches
    _ = FanPolicy.decide(request: .curve, fans: fans, chipCelsius: 85.0, lastHeartbeat: now, now: now, state: &overheatCurveState)
    expect(!overheatCurveState.overheating, "curve mode unlatches overheat below 88°C")
}

func testFanProtocol() {
    for c: FanProtocol.Command in [.status, .heartbeat, .set(.system), .set(.curve), .set(.max), .set(.fixed(rpm: 4200))] {
        expectEq(FanProtocol.decode(FanProtocol.encode(c)), c, "round-trip \(FanProtocol.encode(c))")
    }
    expectEq(FanProtocol.decode("curve extra"), nil, "extra words rejected")
    expectEq(FanProtocol.decode("fixed"), nil, "missing RPM rejected")
    expectEq(FanProtocol.decode("fixed -5"), nil, "negative RPM rejected")
    expectEq(FanProtocol.decode("fixed 4000 now"), nil, "extra words rejected")
    expectEq(FanProtocol.decode("write F0Md 1"), nil, "arbitrary SMC writes impossible")
    expectEq(FanProtocol.decode(""), nil, "empty rejected")
}
