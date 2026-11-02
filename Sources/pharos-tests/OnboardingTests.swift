import Foundation
import PharosCore

func testOnboarding() {
    testOnboardingLaunchDecision()
    testOnboardingDraft()
    testBatteryInstallPlan()
    testOnboardingSteps()
    testOnboardingMotion()
    testRadarBeamGeometry()
    testCapabilityDemo()
    testCursorScripts()
    testBatteryMenuBarMetric()
}

private func testOnboardingLaunchDecision() {
    let eval = OnboardingPolicy.evaluateLaunch

    expectEq(eval(nil, nil, []), .showOnboarding(startStep: 0), "fresh install shows onboarding")
    expectEq(eval(nil, nil, ["someUnrelatedKey", "NSWindow Frame main"]), .showOnboarding(startStep: 0),
             "unrelated defaults keys do not count as an existing user")

    for key in OnboardingPolicy.existingUserTraceKeys {
        expectEq(eval(nil, nil, [key]), .skipForExistingUpgrader, "trace key \(key) marks an upgrader")
    }

    expectEq(eval(1, nil, []), .openMainWindow, "completed current version")
    expectEq(eval(2, nil, []), .openMainWindow, "completed a newer version")
    expectEq(eval(1, 3, ["menuBarText"]), .openMainWindow, "completion wins over a stale resume step")
    expectEq(eval(0, nil, []), .showOnboarding(startStep: 0), "older completed version is re-shown")

    expectEq(eval(nil, 2, []), .showOnboarding(startStep: 2), "FDA restart resumes at step")
    expectEq(eval(nil, 2, ["batteryTargetLimit"]), .showOnboarding(startStep: 2),
             "resume step wins over trace keys (onboarding itself writes them)")
    expectEq(eval(nil, 0, []), .showOnboarding(startStep: 0), "resume lower bound")
    expectEq(eval(nil, 5, []), .showOnboarding(startStep: 5), "resume upper bound")
    expectEq(eval(nil, 6, []), .showOnboarding(startStep: 0), "out-of-range resume falls back to start")
    expectEq(eval(nil, -1, []), .showOnboarding(startStep: 0), "negative resume falls back to start")
    expectEq(eval(nil, 99, ["refreshSeconds"]), .skipForExistingUpgrader,
             "invalid resume step does not bypass upgrader detection")
}

private func testOnboardingDraft() {
    let d = OnboardingDraft()
    expectEq(d.chargingChoice, .systemManaged, "default does not touch charging")
    expectEq(d.targetLimit, 80, "default limit 80")
    expectEq(d.launchAtLogin, false, "launch at login off by default")

    expectEq(OnboardingDraft.firstLaunch(hasBattery: true).pinBatteryInPopover, true, "laptop pins battery card")
    expectEq(OnboardingDraft.firstLaunch(hasBattery: false).pinBatteryInPopover, false, "desktop does not")
    expectEq(OnboardingDraft.firstLaunch(hasBattery: true).chargingChoice, .systemManaged, "first launch never opts in")

    var c = OnboardingDraft()
    c.setTargetLimit(49); expectEq(c.targetLimit, 50, "clamp below 50")
    c.setTargetLimit(50); expectEq(c.targetLimit, 50, "50 kept")
    c.setTargetLimit(85); expectEq(c.targetLimit, 85, "in range kept")
    c.setTargetLimit(100); expectEq(c.targetLimit, 100, "100 kept")
    c.setTargetLimit(101); expectEq(c.targetLimit, 100, "clamp above 100")
    c.setTargetLimit(-5); expectEq(c.targetLimit, 50, "negative clamped")
    expectEq(OnboardingDraft(targetLimit: 10).targetLimit, 50, "init clamps low")
    expectEq(OnboardingDraft(targetLimit: 200).targetLimit, 100, "init clamps high")
}

private func testBatteryInstallPlan() {
    let plan = BatteryInstallPlan.modeAfterInstall

    // Onboarding fresh install: stays in system mode.
    expectEq(plan(false, false, .system, false, 80), nil, "onboarding install keeps .system")
    // Legacy BatteryControlView fresh install: activates the limit.
    expectEq(plan(true, false, .system, false, 80), .limit(maxPercent: 80), "default install activates limit")
    // A persisted limit preference is restored either way.
    expectEq(plan(false, false, .system, true, 85), .limit(maxPercent: 85), "existing limit pref restored")
    // Helper update while limiting / full: put the same mode back.
    expectEq(plan(false, true, .limit(maxPercent: 90), true, 90), .limit(maxPercent: 90), "update restores limit")
    expectEq(plan(true, true, .full, true, 80), .full, "update restores full override")
    // Helper update while in system mode: never starts limiting.
    expectEq(plan(true, true, .system, false, 80), nil, "update in system mode stays system")
    expectEq(plan(false, true, .system, false, 80), nil, "onboarding update in system mode stays system")
    // Target is clamped.
    expectEq(plan(true, false, .system, false, 30), .limit(maxPercent: 50), "target clamped")
}

private func testOnboardingSteps() {
    expectEq(OnboardingStep.allCases.count, OnboardingPolicy.stepCount, "step count matches policy")
    expectEq(OnboardingStep.welcome.previous, nil, "no step before welcome")
    expectEq(OnboardingStep.completion.next, nil, "no step after completion")
    expectEq(OnboardingStep.permissions.next, .preferences, "next")
    expectEq(OnboardingStep.permissions.previous, .capabilities, "previous")
    expect(OnboardingStep.welcome.isFirst && OnboardingStep.completion.isLast, "first/last")
    expectEq(OnboardingStep.at(2), .permissions, "index 2")
    expectEq(OnboardingStep.at(6), .welcome, "out of range -> welcome")
    expectEq(OnboardingStep.at(-1), .welcome, "negative -> welcome")
    if case .showOnboarding(let i) = OnboardingPolicy.evaluateLaunch(completedVersion: nil, resumeStep: 4, presentKeys: []) {
        expectEq(OnboardingStep.at(i), .menuBar, "resume index maps to step")
    } else { expect(false, "resume should show onboarding") }
}

private func testOnboardingMotion() {
    typealias L = OnboardingMotionLevel
    expectEq(L.resolve(reduceMotion: true, lowPower: false), .minimal, "reduce motion wins")
    expectEq(L.resolve(reduceMotion: true, lowPower: true), .minimal, "reduce motion wins over low power")
    expectEq(L.resolve(reduceMotion: false, lowPower: true), .reduced, "low power -> reduced")
    expectEq(L.resolve(reduceMotion: false, lowPower: false), .rich, "onboarding is rich regardless of in-app 3D setting")
    expect(!L.minimal.allowsScale && !L.minimal.allowsBlur, "minimal: fade only")
    expect(L.reduced.allowsScale && !L.reduced.allowsBlur && !L.reduced.allowsContinuousFrames, "reduced: no blur/frames")
    expect(L.rich.allowsBlur && L.rich.allowsContinuousFrames, "rich: everything")

    typealias G = OnboardingTransitionGeometry
    for level in [L.minimal, .reduced, .rich] {
        for dir in [OnboardingNavigationDirection.forward, .backward] {
            let rest = G.values(phase: .identity, direction: dir, level: level)
            expectEq(rest, G.Values(scale: 1, offsetX: 0, blur: 0, opacity: 1), "rest is exact identity (\(level) \(dir))")
            for phase in [G.Phase.willAppear, .didDisappear] {
                let v = G.values(phase: phase, direction: dir, level: level)
                expect(v.blur <= G.maxBlurRadius, "blur capped")
                expectEq(v.opacity, 0, "transient phases are invisible")
                if !level.allowsBlur { expectEq(v.blur, 0, "no blur below rich") }
                if !level.allowsScale { expectEq(v.scale, 1, "no scale when minimal"); expectEq(v.offsetX, 0, "no offset when minimal") }
            }
        }
    }
    let fIn = G.values(phase: .willAppear, direction: .forward, level: .rich)
    let fOut = G.values(phase: .didDisappear, direction: .forward, level: .rich)
    let bIn = G.values(phase: .willAppear, direction: .backward, level: .rich)
    let bOut = G.values(phase: .didDisappear, direction: .backward, level: .rich)
    expectEq(fIn.scale, 1.06, "forward incoming from close"); expectEq(fIn.offsetX, 28, "forward incoming from right")
    expectEq(fOut.scale, 0.93, "forward outgoing recedes"); expectEq(fOut.offsetX, -28, "forward outgoing to left")
    expectEq(bIn.scale, 0.93, "backward mirrors"); expectEq(bIn.offsetX, -28, "backward incoming from left")
    expectEq(bOut.scale, 1.06, "backward outgoing toward viewer"); expectEq(bOut.offsetX, 28, "backward outgoing to right")

    typealias C = OnboardingCollapseGeometry
    for level in [L.minimal, .reduced, .rich] {
        let closed = C.values(progress: 0, level: level)
        let open = C.values(progress: 1, level: level)
        expectEq(closed.blur, 0, "collapsed rest has no blur (\(level))")
        expectEq(open.blur, 0, "expanded rest has no blur (\(level))")
        expectEq(closed.heightFraction, 0, "collapsed height 0")
        expectEq(closed.opacity, 0, "collapsed invisible")
        expectEq(open, C.Values(heightFraction: 1, opacity: 1, scaleY: 1, blur: 0), "expanded is identity (\(level))")
        if !level.allowsBlur { expectEq(C.values(progress: 0.5, level: level).blur, 0, "no blur below rich") }
        if !level.allowsScale { expectEq(C.values(progress: 0.3, level: level).scaleY, 1, "no scale when minimal") }
    }
    let mid = C.values(progress: 0.5, level: .rich)
    expect(mid.blur > 0 && mid.blur <= C.maxBlur, "rich mid-collapse blurs within cap")
    expectEq(C.values(progress: 0.1, level: .rich).opacity, 0, "content fades before clip edge")
    expectEq(C.values(progress: -1, level: .rich).heightFraction, 0, "progress clamped low")
    expectEq(C.values(progress: 2, level: .rich).heightFraction, 1, "progress clamped high")
}

private func testRadarBeamGeometry() {
    typealias R = RadarBeamGeometry
    expectEq(R.leadingDegrees(elapsed: 0), -450, "sweep starts at -90° (plus one turn)")
    expectEq(R.leadingDegrees(elapsed: R.sweepDuration), R.restLeadingDegrees, "lands exactly on rest angle")
    expectEq(R.leadingDegrees(elapsed: 99), R.restLeadingDegrees, "stays at rest afterwards")
    expectEq(R.leadingDegrees(elapsed: -1), -450, "negative elapsed clamps to start")
    expect(!R.isSettled(elapsed: 2.19) && R.isSettled(elapsed: 2.2), "settles at 2.2 s")
    var last = R.leadingDegrees(elapsed: 0)
    var monotonic = true
    for i in 1...44 {
        let v = R.leadingDegrees(elapsed: Double(i) * 0.05)
        if v < last { monotonic = false }
        last = v
    }
    expect(monotonic, "sweep never reverses")
    let early = R.leadingDegrees(elapsed: 0.2) - R.leadingDegrees(elapsed: 0)
    let late = R.leadingDegrees(elapsed: 2.2) - R.leadingDegrees(elapsed: 2.0)
    expect(early > late, "eases out (decelerates)")
    expectEq(R.restLeadingDegrees - R.restTrailingDegrees, R.spreadDegrees, "rest wedge matches icon 25°–65°")

    // Heat matches make-icon at rest: 1 at leading edge, 0 outside.
    let lamp = R.lamp
    func at(_ deg: Double, _ d: Double = 400) -> (Double, Double) {
        (lamp.x + cos(deg * .pi / 180) * d, lamp.y + sin(deg * .pi / 180) * d)
    }
    let edge = at(64.9), mid = at(45), outside = at(80), behind = at(10)
    expect(R.heat(x: edge.0, y: edge.1, leadingDegrees: 65) > 0.95, "hot at leading edge")
    let m = R.heat(x: mid.0, y: mid.1, leadingDegrees: 65)
    expect(m > 0.1 && m < 0.9, "partial in middle")
    expectEq(R.heat(x: outside.0, y: outside.1, leadingDegrees: 65), 0, "cold ahead of beam")
    expectEq(R.heat(x: behind.0, y: behind.1, leadingDegrees: 65), 0, "cold behind beam")
    // Rotation invariance: same relative point, beam turned by a full revolution.
    expect(abs(R.heat(x: mid.0, y: mid.1, leadingDegrees: 65 - 360) - m) < 1e-9, "heat works for any turn")

    for t in R.targets {
        expectEq(R.targetVisibility(frac: t.frac, leadingDegrees: R.restLeadingDegrees), 1,
                 "targets fully visible at rest (\(t.frac))")
        expectEq(R.targetVisibility(frac: t.frac, leadingDegrees: -90), 0, "targets hidden at start")
    }
}

private func testCapabilityDemo() {
    typealias K = OnboardingCapabilityKind
    expectEq(K.lineup(hasBattery: true), [.memory, .ports, .power, .cleanup], "laptop lineup")
    expectEq(K.lineup(hasBattery: false), [.memory, .ports, .thermals, .cleanup], "desktop lineup")
    expectEq(OnboardingStep.capabilities.rawValue, 1, "capabilities keeps resume index 1")
    expectEq(OnboardingStep.allCases.count, 6, "still six steps")

    var d = OnboardingCapabilityDemo()
    expectEq(d.memoryPercent, 78, "memory before"); expect(!d.memoryHealthy, "memory high before")
    expectEq(d.listeningPorts, 2, "ports before")
    expectEq(d.cellMilliamps, 1480, "cell before")
    expectEq(d.reclaimableCacheGB, 6.8, "cache before")
    expect(!d.showsThermalDetail, "thermal summary before")
    for k in K.allCases { d.perform(k) }
    expectEq(d.memoryPercent, 61, "memory after"); expect(d.memoryHealthy, "memory healthy after")
    expectEq(d.listeningPorts, 1, "ports after")
    expectEq(d.cellMilliamps, 0, "cell passthrough 0 mA")
    expectEq(d.reclaimableCacheGB, 0, "cache cleared")
    expect(d.showsThermalDetail, "thermal detail after")
    d.perform(.memory)
    expectEq(d.memoryPercent, 61, "perform is idempotent")
    d.reset()
    expectEq(d, OnboardingCapabilityDemo(), "reset restores initial state")
}

private func testCursorScripts() {
    let scripts = [OnboardingCursorScript.capabilities(hasBattery: true), .capabilities(hasBattery: false),
                   .menuBar(hasSecondTab: true), .menuBar(hasSecondTab: false)]
    for s in scripts {
        expect(!s.steps.isEmpty, "script has steps")
        expect(s.totalDuration < OnboardingCursorScript.maxTotalDuration, "script under 10s (\(s.totalDuration))")
        for step in s.steps {
            expect(step.moveDuration >= 0 && step.aimPause >= 0 && step.pressDuration >= 0 && step.dwellAfterClick >= 0,
                   "non-negative timings")
        }
    }
    let neg = OnboardingCursorStep("x", moveDuration: -1, aimPause: -1, pressDuration: -1, dwellAfterClick: -1)
    expectEq(neg.totalDuration, 0, "negative timings clamp to 0")
    expect(OnboardingCursorScript.capabilities(hasBattery: false).steps.contains { $0.targetID == "cap.act.thermals" },
           "desktop tour acts on thermals")
    expectEq(OnboardingCursorScript.capabilities(hasBattery: true).steps.last?.targetID, "cap.act.cleanup",
             "tour ends on the cleanup sweep")
    expectEq(OnboardingCursorScript.menuBar(hasSecondTab: false).steps.map(\.targetID), ["menubar.icon"], "single tab: icon only")
    expectEq(OnboardingCursorScript.menuBar(hasSecondTab: true).steps.last?.targetID, "menubar.secondTab", "then second tab")
}

private func testBatteryMenuBarMetric() {
    typealias B = BatteryMenuBarMetric
    expectEq(B.fraction(percent: 80), 0.8, "fraction")
    expectEq(B.fraction(percent: 130), 1, "fraction clamps high")
    expectEq(B.fraction(percent: -5), 0, "fraction clamps low")
    expectEq(B.level(percent: 100, onAC: false), .normal, "full battery is fine")
    expectEq(B.level(percent: 20, onAC: false), .warning, "20% warns")
    expectEq(B.level(percent: 21, onAC: false), .normal, "21% fine")
    expectEq(B.level(percent: 10, onAC: false), .critical, "10% critical")
    expectEq(B.level(percent: 5, onAC: true), .normal, "on AC never warns")
    expectEq(B.label(percent: 76, hasBattery: true), "76%", "label")
    expectEq(B.label(percent: 76, hasBattery: false), nil, "desktop: no label")
}
