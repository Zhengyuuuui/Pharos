import Foundation
import PharosCore

func testBatteryPolicyHysteresis() {
    var state = BatteryPolicy.State()
    let now = Date()

    // 1. Starting below target (70%): should allow charge, prevent sleep
    let d1 = BatteryPolicy.decide(
        mode: .limit(maxPercent: 80),
        currentPercent: 70,
        isACConnected: true,
        lastHeartbeat: now,
        now: now,
        state: &state
    )
    expectEq(d1.action, .allowCharge, "70% should allow charge")
    expectEq(d1.sleepDirective, .preventSleep, "charging should prevent sleep until target")
    expectEq(d1.progress, .charging(target: 80), "progress charging to 80")
    expectEq(state.isHolding, false, "not holding yet")

    // 2. Rising to 79%: still allowing charge
    let d2 = BatteryPolicy.decide(
        mode: .limit(maxPercent: 80),
        currentPercent: 79,
        isACConnected: true,
        lastHeartbeat: now,
        now: now,
        state: &state
    )
    expectEq(d2.action, .allowCharge, "79% still allows charge")
    expectEq(state.isHolding, false, "still not holding")

    // 3. Reaching target 80%: must inhibit charge, allow sleep, enter holding state
    let d3 = BatteryPolicy.decide(
        mode: .limit(maxPercent: 80),
        currentPercent: 80,
        isACConnected: true,
        lastHeartbeat: now,
        now: now,
        state: &state
    )
    expectEq(d3.action, .inhibitCharge, "80% reaches target, inhibit charge")
    expectEq(d3.sleepDirective, .allowSleep, "charge target reached, sleep is allowed")
    expectEq(d3.progress, .holding(limit: 80), "progress holding at 80 (native plug state)")
    expectEq(state.isHolding, true, "holding state activated")

    // 4. Minor fluctuation down to 79%: hysteresis holds the inhibit state!
    let d4 = BatteryPolicy.decide(
        mode: .limit(maxPercent: 80),
        currentPercent: 79,
        isACConnected: true,
        lastHeartbeat: now,
        now: now,
        state: &state
    )
    expectEq(d4.action, .inhibitCharge, "79% after holding stays inhibited via hysteresis")
    expectEq(state.isHolding, true, "still holding")

    // 5. Minor fluctuation down to 76%: hysteresis still holds
    let d5 = BatteryPolicy.decide(
        mode: .limit(maxPercent: 80),
        currentPercent: 76,
        isACConnected: true,
        lastHeartbeat: now,
        now: now,
        state: &state
    )
    expectEq(d5.action, .inhibitCharge, "76% stays inhibited")
    expectEq(state.isHolding, true, "still holding")

    // 6. Drops to 75% (80 - 5 hysteresis margin): charge resumes!
    let d6 = BatteryPolicy.decide(
        mode: .limit(maxPercent: 80),
        currentPercent: 75,
        isACConnected: true,
        lastHeartbeat: now,
        now: now,
        state: &state
    )
    expectEq(d6.action, .allowCharge, "75% reaches lower threshold, charge resumes")
    expectEq(d6.sleepDirective, .preventSleep, "prevent sleep while recharging to 80")
    expectEq(state.isHolding, false, "holding reset")
}

func testBatteryPolicyHeartbeatTimeout() {
    var state = BatteryPolicy.State(isHolding: true, isAdapterBypassed: false)
    let now = Date()
    let staleHeartbeat = now.addingTimeInterval(-20) // 20s ago (> 15s timeout)

    let d = BatteryPolicy.decide(
        mode: .limit(maxPercent: 80),
        currentPercent: 80,
        isACConnected: true,
        lastHeartbeat: staleHeartbeat,
        now: now,
        state: &state
    )
    expectEq(d.action, .release, "timeout returns charging control to macOS")
    expectEq(state.isHolding, false, "holding state cleared on timeout")
}

func testBatteryPolicyModes() {
    var state = BatteryPolicy.State()
    let now = Date()

    // .system mode
    let sys = BatteryPolicy.decide(mode: .system, currentPercent: 70, isACConnected: true, lastHeartbeat: now, now: now, state: &state)
    expectEq(sys.action, .release, "system mode hands all control to macOS")

    // .full mode below 100
    let fullCharging = BatteryPolicy.decide(mode: .full, currentPercent: 95, isACConnected: true, lastHeartbeat: now, now: now, state: &state)
    expectEq(fullCharging.action, .allowCharge, "full mode allows charging")
    expectEq(fullCharging.sleepDirective, .preventSleep, "full mode charging prevents sleep")

    // .full mode at 100
    let fullDone = BatteryPolicy.decide(mode: .full, currentPercent: 100, isACConnected: true, lastHeartbeat: now, now: now, state: &state)
    expectEq(fullDone.action, .inhibitCharge, "full mode at 100 inhibits")
    expectEq(fullDone.sleepDirective, .allowSleep, "full mode at 100 allows sleep")

    // .discharge mode (safe fallback: never cut adapter, inhibit on AC)
    let dis = BatteryPolicy.decide(mode: .discharge, currentPercent: 90, isACConnected: true, lastHeartbeat: now, now: now, state: &state)
    expectEq(dis.action, .inhibitCharge, "discharge mode safely inhibits charge on AC")
    expectEq(dis.progress, .holding(limit: 80), "discharge mode progress is holding at limit")
    expectEq(state.isAdapterBypassed, false, "adapter is never cut off")

    // .limit(80) when currentPercent is 100% (already above limit):
    // immediately inhibits charge, allows sleep, never cuts adapter!
    var stateAbove = BatteryPolicy.State()
    let dAbove = BatteryPolicy.decide(
        mode: .limit(maxPercent: 80),
        currentPercent: 100,
        isACConnected: true,
        lastHeartbeat: now,
        now: now,
        state: &stateAbove
    )
    expectEq(dAbove.action, .inhibitCharge, "100% with limit 80 immediately inhibits charge")
    expectEq(dAbove.progress, .holding(limit: 80), "progress holding at 80")
    expectEq(stateAbove.isHolding, true, "holding state is true")
    expectEq(stateAbove.isAdapterBypassed, false, "adapter is never cut off")

    // Thermal limit override
    let hot = BatteryPolicy.decide(
        mode: .full,
        currentPercent: 70,
        isACConnected: true,
        temperatureCelsius: 52.0,
        lastHeartbeat: now,
        now: now,
        state: &state
    )
    expectEq(hot.action, .inhibitCharge, "overheat forces inhibit")
    expectEq(hot.magSafeColor, .orangeSlowBlink, "overheat blinks MagSafe LED")

    // Unplugged from AC
    let unplugged = BatteryPolicy.decide(mode: .limit(maxPercent: 80), currentPercent: 70, isACConnected: false, lastHeartbeat: now, now: now, state: &state)
    expectEq(unplugged.action, .release, "unplugged releases hardware overrides")
    expectEq(unplugged.progress, .onBattery, "unplugged progress is onBattery")
}

func testBatteryMagSafeAndSafeWrites() {
    let now = Date()
    var state = BatteryPolicy.State()
    let held = BatteryPolicy.decide(mode: .limit(maxPercent: 80), currentPercent: 100, isACConnected: true, lastHeartbeat: now, now: now, state: &state)
    expectEq(held.action, .inhibitCharge, "100% with 80% limit inhibits immediately")
    expectEq(held.magSafeColor, .orange, "holding uses macOS 15 amber LED")
    var noSync = BatteryPolicy.State()
    let heldNoSync = BatteryPolicy.decide(mode: .limit(maxPercent: 80), currentPercent: 90, isACConnected: true, syncMagSafe: false, lastHeartbeat: now, now: now, state: &noSync)
    expectEq(heldNoSync.magSafeColor, .system, "without sync the firmware drives the LED")

    // Exhaustive: no decision ever turns the LED off or bypasses the adapter.
    let modes: [BatteryMode] = [.system, .full, .discharge, .limit(maxPercent: 50), .limit(maxPercent: 80), .limit(maxPercent: 100)]
    for mode in modes {
        for pct in stride(from: 0, through: 100, by: 5) {
            for ac in [true, false] {
                for temp in [25.0, 55.0] {
                    for sync in [true, false] {
                        var st = BatteryPolicy.State()
                        let d = BatteryPolicy.decide(mode: mode, currentPercent: pct, isACConnected: ac, temperatureCelsius: temp, syncMagSafe: sync, lastHeartbeat: now, now: now, state: &st)
                        if d.magSafeColor.rawValue == 0x01 || st.isAdapterBypassed {
                            expect(false, "unsafe decision for \(mode) \(pct)% ac=\(ac)")
                        }
                    }
                }
            }
        }
    }
    expect(!BatteryPolicy.MagSafeColor.allCases.contains { $0.rawValue == 0x01 }, "LED-off color does not exist")

    expect(BatteryPolicy.isSafeWrite(key: "CHTE", bytes: [1, 0, 0, 0]), "CHTE inhibit allowed")
    expect(BatteryPolicy.isSafeWrite(key: "CHTE", bytes: [0, 0, 0, 0]), "CHTE release allowed")
    expect(BatteryPolicy.isSafeWrite(key: "CHIE", bytes: [0]), "CHIE reset to 0 allowed")
    expect(!BatteryPolicy.isSafeWrite(key: "CHIE", bytes: [0x08]), "CHIE adapter cut rejected")
    expect(!BatteryPolicy.isSafeWrite(key: "CH0J", bytes: [0x01]), "CH0J adapter cut rejected")
    expect(!BatteryPolicy.isSafeWrite(key: "ACLC", bytes: [0x01]), "ACLC LED off rejected")
    expect(BatteryPolicy.isSafeWrite(key: "ACLC", bytes: [0x04]), "ACLC amber allowed")
    expect(!BatteryPolicy.isSafeWrite(key: "BCLM", bytes: [80]), "unknown keys rejected")
    expect(!BatteryPolicy.isSafeWrite(key: "CHTE", bytes: [2, 0, 0, 0]), "odd CHTE value rejected")
}

func testBatteryPowerFlow() {
    expectEq(BatteryPowerFlow.classify(BatteryReading(amperage: 0, powerSource: .acPower)), .passthrough, "0 mA on AC is passthrough")
    expectEq(BatteryPowerFlow.classify(BatteryReading(amperage: -8, powerSource: .acPower)), .passthrough, "sensor noise is passthrough")
    expectEq(BatteryPowerFlow.classify(BatteryReading(amperage: 2500, powerSource: .acPower)), .charging, "positive current is charging")
    expectEq(BatteryPowerFlow.classify(BatteryReading(amperage: -900, powerSource: .acPower)), .supplementing, "negative current on AC supplements")
    expectEq(BatteryPowerFlow.classify(BatteryReading(amperage: 0, powerSource: .battery)), .onBattery, "battery source")
}

func testBatteryProtocolEncodeDecode() {
    let commands: [(BatteryProtocol.Command, String)] = [
        (.status, "status"),
        (.heartbeat, "ping"),
        (.setMode(.system), "system"),
        (.setMode(.limit(maxPercent: 80)), "limit 80"),
        (.setMode(.full), "full"),
        (.setMode(.discharge), "discharge"),
        (.syncMagSafe(true), "magsafe 1"),
        (.syncMagSafe(false), "magsafe 0"),
    ]

    for (cmd, str) in commands {
        expectEq(BatteryProtocol.encode(cmd), str, "encode \(cmd)")
        expectEq(BatteryProtocol.decode(str), cmd, "decode \(str)")
    }

    // Malformed commands
    expectEq(BatteryProtocol.decode(""), nil, "empty string rejected")
    expectEq(BatteryProtocol.decode("unknown cmd"), nil, "unknown rejected")
    expectEq(BatteryProtocol.decode("limit 10"), nil, "limit below 20 rejected")
    expectEq(BatteryProtocol.decode("limit 120"), nil, "limit above 100 rejected")
    expectEq(BatteryProtocol.decode("limit abc"), nil, "non-integer limit rejected")

    // Reply JSON round-trip
    let reply = BatteryProtocol.Reply(
        ok: true,
        mode: .limit(maxPercent: 80),
        isHolding: true,
        isAdapterBypassed: false,
        magSafeSync: true,
        unsupported: false
    )
    let data = try? JSONEncoder().encode(reply)
    let decoded = data.flatMap { try? JSONDecoder().decode(BatteryProtocol.Reply.self, from: $0) }
    expectEq(decoded, reply, "reply JSON round-trips")
}

func testBatteryHelperInstall() {
    expectEq(BatteryHelperInstall.label, "local.pharos.battd", "helper label")
    let plist = BatteryHelperInstall.plist(uid: 501)
    expect(plist.contains("<string>local.pharos.battd</string>"), "plist has label")
    expect(plist.contains("<string>501</string>"), "plist has uid")
    expect(plist.contains("/Library/PrivilegedHelperTools/local.pharos.battd"), "plist has binary path")

    let installScript = BatteryHelperInstall.installScript(helperSource: "/tmp/battd", plistSource: "/tmp/plist")
    expect(installScript.contains("bootstrap system"), "install boots up helper")
    expect(installScript.contains("install -o root"), "installs binary")

    let uninstallScript = BatteryHelperInstall.uninstallScript
    expect(uninstallScript.contains("bootout system"), "uninstall boots out helper")
    expect(uninstallScript.contains("rm -f"), "uninstall removes files")
}

func testBatteryScannerLive() {
    let caps = BatteryScanner.probeCapabilities()
    // On Apple Silicon M3 Pro, CHTE and CH0C exist
    expect(caps.isSupported, "hardware charging control supported on this machine")
    expect(caps.hasCHTE, "CHTE register present")

    guard let reading = BatteryScanner.read() else {
        expect(false, "BatteryScanner.read() returned nil")
        return
    }
    expect(reading.currentPercent >= 0 && reading.currentPercent <= 100, "valid percent: \(reading.currentPercent)")
    expect(reading.designCapacity > 0, "valid design capacity: \(reading.designCapacity)")
    expect(reading.maxCapacity > 0, "valid max capacity: \(reading.maxCapacity)")
    expect(reading.voltage > 5.0 && reading.voltage < 25.0, "valid voltage: \(reading.voltage) V")
    expect(reading.temperatureCelsius > 0.0 && reading.temperatureCelsius < 80.0, "valid temp: \(reading.temperatureCelsius) °C")
}
