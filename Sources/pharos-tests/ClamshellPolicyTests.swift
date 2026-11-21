import Foundation
import PharosCore

func testClamshellPolicy() {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let offConfig = ClamshellConfig(enabled: false)
    let onConfig = ClamshellConfig(
        enabled: true,
        thermalAbortCelsius: 86.0,
        batteryFloorPercent: 20,
        proactiveFanControl: true
    )

    // 1. Disabled stays inactive and resets counters
    var state = ClamshellPolicy.State(consecutiveHighTempTicks: 2, consecutiveLowBatteryTicks: 2)
    expectEq(
        ClamshellPolicy.decide(
            config: offConfig,
            chipCelsius: 95.0,
            batteryPercent: 5,
            isOnACPower: false,
            lastHeartbeat: now,
            now: now,
            state: &state
        ),
        .inactive,
        "disabled config returns .inactive"
    )
    expectEq(state, ClamshellPolicy.State(), "disabled config resets tick counters")

    // 2. Heartbeat timeout restores normal sleep
    expectEq(
        ClamshellPolicy.decide(
            config: onConfig,
            chipCelsius: 55.0,
            batteryPercent: 80,
            isOnACPower: false,
            lastHeartbeat: now.addingTimeInterval(-16),
            now: now,
            state: &state
        ),
        .heartbeatRestore,
        "stale heartbeat restores normal sleep"
    )
    expectEq(
        ClamshellPolicy.decide(
            config: onConfig,
            chipCelsius: 55.0,
            batteryPercent: 80,
            isOnACPower: false,
            lastHeartbeat: nil,
            now: now,
            state: &state
        ),
        .heartbeatRestore,
        "nil heartbeat restores normal sleep"
    )

    // 3. Normal safe operating state
    expectEq(
        ClamshellPolicy.decide(
            config: onConfig,
            chipCelsius: 62.0,
            batteryPercent: 85,
            isOnACPower: false,
            lastHeartbeat: now,
            now: now,
            state: &state
        ),
        .active,
        "normal temp & battery stays active"
    )

    // 4. Thermal runaway debounce: requires 3 consecutive ticks >= 86°C
    var tempState = ClamshellPolicy.State()
    let t1 = ClamshellPolicy.decide(config: onConfig, chipCelsius: 86.0, batteryPercent: 80, isOnACPower: true, lastHeartbeat: now, now: now, state: &tempState)
    let t2 = ClamshellPolicy.decide(config: onConfig, chipCelsius: 87.0, batteryPercent: 80, isOnACPower: true, lastHeartbeat: now, now: now, state: &tempState)
    expectEq(t1, .active, "1st high temp tick debounced")
    expectEq(t2, .active, "2nd high temp tick debounced")

    // Drop below redline resets counter
    let cool = ClamshellPolicy.decide(config: onConfig, chipCelsius: 83.0, batteryPercent: 80, isOnACPower: true, lastHeartbeat: now, now: now, state: &tempState)
    expectEq(cool, .active, "temp dip resets counter")
    expectEq(tempState.consecutiveHighTempTicks, 0, "counter reset to 0 after cooling")

    // 3 sustained ticks abort
    _ = ClamshellPolicy.decide(config: onConfig, chipCelsius: 86.0, batteryPercent: 80, isOnACPower: true, lastHeartbeat: now, now: now, state: &tempState)
    _ = ClamshellPolicy.decide(config: onConfig, chipCelsius: 86.5, batteryPercent: 80, isOnACPower: true, lastHeartbeat: now, now: now, state: &tempState)
    let t3 = ClamshellPolicy.decide(config: onConfig, chipCelsius: 87.2, batteryPercent: 80, isOnACPower: true, lastHeartbeat: now, now: now, state: &tempState)
    expectEq(t3, .abort(reason: .thermalRunaway(celsius: 87.2)), "3 sustained ticks trigger thermal abort")

    // 5. Extreme thermal spike (>= abort + 4°C) aborts immediately on tick 1
    var extremeState = ClamshellPolicy.State()
    let extreme = ClamshellPolicy.decide(config: onConfig, chipCelsius: 90.0, batteryPercent: 90, isOnACPower: true, lastHeartbeat: now, now: now, state: &extremeState)
    expectEq(extreme, .abort(reason: .thermalRunaway(celsius: 90.0)), "extreme thermal spike aborts immediately")

    // 6. Battery floor safeguard only when unplugged
    var battState = ClamshellPolicy.State()
    let pluggedLow = ClamshellPolicy.decide(config: onConfig, chipCelsius: 50.0, batteryPercent: 10, isOnACPower: true, lastHeartbeat: now, now: now, state: &battState)
    expectEq(pluggedLow, .active, "AC power ignores low battery floor")
    _ = ClamshellPolicy.decide(config: onConfig, chipCelsius: 50.0, batteryPercent: 20, isOnACPower: false, lastHeartbeat: now, now: now, state: &battState)
    _ = ClamshellPolicy.decide(config: onConfig, chipCelsius: 50.0, batteryPercent: 19, isOnACPower: false, lastHeartbeat: now, now: now, state: &battState)
    let battAbort = ClamshellPolicy.decide(config: onConfig, chipCelsius: 50.0, batteryPercent: 19, isOnACPower: false, lastHeartbeat: now, now: now, state: &battState)
    expectEq(battAbort, .abort(reason: .lowBattery(percent: 19)), "unplugged low battery triggers abort")
}

func testClamshellProactiveFanAndProtocol() {
    let fans = [
        FanReading(index: 0, actualRPM: 0, targetRPM: 2000, minRPM: 2000, maxRPM: 6000, mode: .system),
    ]
    let now = Date(timeIntervalSince1970: 2_000_000)
    var fanState = FanPolicy.State()

    // Even when FanRequest is `.system`, clamshellProactive engages cooling and ramps faster (+300 RPM/tick)
    let tick1 = FanPolicy.decide(
        request: .system,
        fans: fans,
        chipCelsius: 80.0,
        lastHeartbeat: now,
        now: now,
        state: &fanState,
        clamshellProactive: true
    )
    expectEq(tick1, .hold([2300]), "clamshellProactive overrides .system and accelerates +300 RPM")

    // Protocol round-trips
    let cfgOn = ClamshellConfig(enabled: true, thermalAbortCelsius: 86, batteryFloorPercent: 20, proactiveFanControl: true)
    let cfgOff = ClamshellConfig(enabled: false)
    for cmd: FanProtocol.Command in [.setClamshell(cfgOn), .setClamshell(cfgOff), .clearClamshellAbort] {
        expectEq(FanProtocol.decode(FanProtocol.encode(cmd)), cmd, "round-trip \(FanProtocol.encode(cmd))")
    }

    expectEq(FanProtocol.decode("clamshell on 200 20 1"), nil, "out-of-range thermal abort rejected")
    expectEq(FanProtocol.decode("clamshell on 86 1 1"), nil, "out-of-range battery floor rejected")
    expectEq(FanProtocol.decode("clamshell bogus"), nil, "unknown clamshell subcommand rejected")

    // Backward-compatible Reply decoding from v3 helper (without clamshell fields)
    let v3Json = #"{"version":3,"ok":true,"request":{"system":{}},"overheating":false,"unsupported":false}"#
    let decoded = try? JSONDecoder().decode(FanProtocol.Reply.self, from: Data(v3Json.utf8))
    expectEq(decoded?.version, 3, "v3 reply decodes version cleanly")
    expectEq(decoded?.clamshellEnabled, false, "v3 reply defaults clamshellEnabled to false")
    expectEq(decoded?.clamshellAbort, nil, "v3 reply defaults clamshellAbort to nil")
}
