import Foundation
import ServiceManagement
import PharosCore

/// Owns step routing and the Step 04 draft. Lives only as long as the onboarding window.
@MainActor
final class OnboardingCoordinator: ObservableObject {
    @Published private(set) var step: OnboardingStep
    @Published private(set) var direction: OnboardingNavigationDirection = .forward
    @Published var draft: OnboardingDraft

    /// Step 04 → 05 is waiting on the admin prompt / daemon.
    @Published private(set) var isCommitting = false
    /// Gentle, non-error notice shown on Step 04 (e.g. password prompt cancelled).
    @Published var preferencesNotice: String?
    @Published private(set) var launchAtLoginError: String?

    let isReplay: Bool
    /// Set when this session turned the charge limit on, so we can land on the battery page.
    private(set) var enabledLimitThisSession = false
    private(set) var isFinished = false

    /// Called once when the user finishes or skips, with the page the main window should open on.
    /// Held only by this coordinator, which the window controller drops on close — no cycle survives.
    var onFinish: (@MainActor (_ select: MainWindowView.SidebarItem?) -> Void)?

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
        guard !isCommitting else { return }
        if step == .preferences {
            commitPreferences { [weak self] proceed in
                guard let self, proceed else { return }
                self.advance()
            }
            return
        }
        if step.isLast {
            applyLaunchAtLogin()
            finish(select: enabledLimitThisSession ? .battery : nil)
            return
        }
        advance()
    }

    private func advance() {
        guard let next = step.next else { return }
        direction = .forward
        step = next
    }

    func goBack() {
        guard let previous = step.previous else { return }
        direction = .backward
        step = previous
    }

    /// Skipping applies nothing that was not already confirmed on Step 04.
    func skip() { finish(select: nil) }

    /// Only Step 03 → System Settings may need a relaunch; remember where to come back to.
    func rememberResumePoint() {
        UserDefaults.standard.set(step.rawValue, forKey: OnboardingPolicy.resumeStepKey)
    }

    /// Back in the app without a relaunch: the resume point is no longer needed.
    func clearResumePoint() {
        UserDefaults.standard.removeObject(forKey: OnboardingPolicy.resumeStepKey)
    }

    /// Also used when the window is closed with the red button: the user dismissed it deliberately,
    /// and Settings → Replay brings it back.
    func markCompleted() {
        let d = UserDefaults.standard
        d.set(OnboardingPolicy.currentVersion, forKey: OnboardingPolicy.completedVersionKey)
        d.removeObject(forKey: OnboardingPolicy.resumeStepKey)
        CleanupStoreHolder.shared.dismissFirstLaunchPermissionPrompt()
    }

    private func finish(select: MainWindowView.SidebarItem?) {
        guard !isFinished else { return }
        isFinished = true
        markCompleted()
        let callback = onFinish
        onFinish = nil
        callback?(select)
    }

    // MARK: Two-phase commit

    var canOfferChargeLimit: Bool {
        let b = BatteryStore.shared
        return b.reading.hasBattery && b.capabilities.isSupported
    }

    /// Phase one (leaving Step 04): side-effect-free UI prefs first, so the Step 05 preview already
    /// shows them; then the charge limit, which may need the admin prompt. Cancelling the prompt
    /// falls back to macOS-managed charging and keeps the user on Step 04 with a notice.
    private func commitPreferences(_ done: @escaping @MainActor (_ proceed: Bool) -> Void) {
        applyUIPreferences()
        let battery = BatteryStore.shared
        guard canOfferChargeLimit else { done(true); return }

        switch draft.chargingChoice {
        case .systemManaged:
            // Only an explicit change on replay touches hardware; first launch never does.
            if isReplay, battery.isPharosManaging { battery.setSystemMode() }
            done(true)
        case .pharosLimit:
            if battery.persistentGuard != draft.persistentGuard { battery.persistentGuard = draft.persistentGuard }
            let limit = draft.targetLimit
            if battery.helper == .ready {
                enableLimit(limit)
                done(true)
                return
            }
            isCommitting = true
            preferencesNotice = nil
            battery.install(activateLimitAfterInstall: false) { [weak self] ok in
                guard let self else { return }
                self.isCommitting = false
                if ok {
                    self.enableLimit(limit)
                    done(true)
                } else {
                    self.draft.chargingChoice = .systemManaged
                    self.preferencesNotice = L10n.shared.onboardingInstallCancelledFallback
                    done(false)
                }
            }
        }
    }

    private func enableLimit(_ limit: Int) {
        let battery = BatteryStore.shared
        if !battery.isPharosManaging || battery.activeLimit != limit { enabledLimitThisSession = true }
        battery.selectLimit(limit)
    }

    private func applyUIPreferences() {
        if let text = MenuBarText(rawValue: draft.menuBarTextRaw), MenuBarSettings.shared.text != text {
            MenuBarSettings.shared.text = text
        }
        let layoutStore = PopoverLayoutStore.shared
        let pinned = layoutStore.layout.tab(of: .battery) != nil
        if draft.pinBatteryInPopover, !pinned {
            layoutStore.update { $0.insert(.battery, into: .overview, before: $0.overview.first) }
        } else if !draft.pinBatteryInPopover, pinned {
            layoutStore.update { $0.remove(.battery) }
        }
    }

    /// Phase two (Step 06 → Enter): login item. Failure is shown but never blocks entering.
    private func applyLaunchAtLogin() {
        let enabled = SMAppService.mainApp.status == .enabled
        guard draft.launchAtLogin != enabled else { return }
        do {
            if draft.launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
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
