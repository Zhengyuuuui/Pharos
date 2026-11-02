import Foundation
import PharosCore

func testOnboarding() {
    testOnboardingLaunchDecision()
    testOnboardingDraft()
    testBatteryInstallPlan()
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
