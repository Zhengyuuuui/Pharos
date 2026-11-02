import Foundation
import ServiceManagement
import PharosCore

/// Owns step routing and the Step 04 draft. Lives only as long as the onboarding window.
@MainActor
final class OnboardingCoordinator: ObservableObject {
    @Published private(set) var step: OnboardingStep
    @Published private(set) var direction: OnboardingNavigationDirection = .forward
    @Published var draft: OnboardingDraft

    let isReplay: Bool
    /// Called once when the user finishes or skips. Held strongly only by this coordinator,
    /// which the window controller drops on close — no cycle survives the window.
    var onFinish: (@MainActor (_ completed: Bool) -> Void)?

    init(isReplay: Bool, startStep: OnboardingStep = .welcome) {
        self.isReplay = isReplay
        self.step = startStep
        self.draft = isReplay ? Self.draftFromCurrentSettings() : .firstLaunch(hasBattery: BatteryStore.shared.reading.hasBattery)
    }

    // MARK: Launch decision

    static func launchDecision(defaults: UserDefaults = .standard) -> OnboardingPolicy.LaunchDecision {
        OnboardingPolicy.evaluateLaunch(
            completedVersion: defaults.object(forKey: OnboardingPolicy.completedVersionKey) as? Int,
            resumeStep: defaults.object(forKey: OnboardingPolicy.resumeStepKey) as? Int,
            presentKeys: Set(defaults.dictionaryRepresentation().keys)
        )
    }

    /// Upgraders are marked completed here so they are never asked again.
    static func shouldPresentOnLaunch(defaults: UserDefaults = .standard) -> Bool {
        switch launchDecision(defaults: defaults) {
        case .showOnboarding: return true
        case .skipForExistingUpgrader:
            defaults.set(OnboardingPolicy.currentVersion, forKey: OnboardingPolicy.completedVersionKey)
            return false
        case .openMainWindow: return false
        }
    }

    static func launchStartStep(defaults: UserDefaults = .standard) -> OnboardingStep {
        if case .showOnboarding(let i) = launchDecision(defaults: defaults) { return .at(i) }
        return .welcome
    }

    // MARK: Navigation

    var canGoBack: Bool { !step.isFirst }

    func goForward() {
        guard let next = step.next else { finish(); return }
        direction = .forward
        step = next
    }

    func goBack() {
        guard let previous = step.previous else { return }
        direction = .backward
        step = previous
    }

    func skip() { finish() }

    /// Only Step 03 → System Settings may need a relaunch; remember where to come back to.
    func rememberResumePoint() {
        UserDefaults.standard.set(step.rawValue, forKey: OnboardingPolicy.resumeStepKey)
    }

    private func finish() {
        let d = UserDefaults.standard
        d.set(OnboardingPolicy.currentVersion, forKey: OnboardingPolicy.completedVersionKey)
        d.removeObject(forKey: OnboardingPolicy.resumeStepKey)
        let callback = onFinish
        onFinish = nil
        callback?(true)
    }

    // MARK: Draft

    /// Replay must reflect what is active now, so it never resets an enabled limit to defaults.
    private static func draftFromCurrentSettings() -> OnboardingDraft {
        let battery = BatteryStore.shared
        return OnboardingDraft(
            chargingChoice: battery.isPharosManaging ? .pharosLimit : .systemManaged,
            targetLimit: battery.targetLimit,
            persistentGuard: battery.persistentGuard,
            pinBatteryInPopover: PopoverLayoutStore.shared.layout.tab(of: .battery) != nil,
            menuBarTextRaw: MenuBarSettings.shared.text.rawValue,
            launchAtLogin: SMAppService.mainApp.status == .enabled
        )
    }
}
