import SwiftUI
import ServiceManagement
import PharosCore

/// Every row reads live state, not the draft — this is what is really in effect.
struct OnboardingCompletionStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let level: OnboardingMotionLevel
    @ObservedObject private var battery = BatteryStore.shared
    @ObservedObject private var menuBar = MenuBarSettings.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(spacing: PharosSpacing.l) {
            Spacer(minLength: 0)
            OnboardingCompletionBadge(level: level)
            VStack(spacing: PharosSpacing.xs) {
                Text(l10n.onboardingDoneTitle).font(PharosFont.pageTitle)
                Text(l10n.onboardingDoneSubtitle).font(PharosFont.body).foregroundStyle(PharosColor.textSecondary)
            }
            .onboardingEntrance(1, level: level)

            PharosCard(padding: 0) {
                VStack(spacing: 0) {
                    if battery.reading.hasBattery {
                        summaryRow(l10n.onboardingDonePowerRow, powerValue).onboardingEntrance(3, level: level)
                        PharosListDivider()
                        summaryRow(l10n.onboardingDoneHelperRow,
                                   battery.helper == .ready ? l10n.onboardingDoneHelperRunning : l10n.onboardingDoneHelperNotInstalled)
                            .onboardingEntrance(4, level: level)
                        PharosListDivider()
                    }
                    summaryRow(l10n.onboardingDoneMenuBarRow, l10n.menuBarTextOption(menuBar.text))
                        .onboardingEntrance(5, level: level)
                    PharosListDivider()
                    summaryRow(l10n.onboardingDoneLaunchRow, coordinator.draft.launchAtLogin ? l10n.onboardingOn : l10n.onboardingOff)
                        .onboardingEntrance(6, level: level)
                }
            }
            .frame(maxWidth: 460)
            .onboardingEntrance(2, level: level)

            Text(l10n.onboardingDoneReplayHint)
                .font(PharosFont.caption)
                .foregroundStyle(PharosColor.textTertiary)
                .onboardingEntrance(3, level: level)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PharosSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var powerValue: String {
        if let limit = battery.activeLimit { return l10n.onboardingDonePowerLimit(limit) }
        return l10n.onboardingDonePowerSystem
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(PharosColor.textSecondary)
            Spacer()
            Text(value).foregroundStyle(PharosColor.textPrimary).multilineTextAlignment(.trailing)
        }
        .font(PharosFont.body)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Two-stage spring landing: 0.6 → 1.08 → 1.0. Plays once; Reduce Motion shows it at rest.
private struct OnboardingCompletionBadge: View {
    let level: OnboardingMotionLevel
    @State private var trigger = false

    var body: some View {
        let icon = Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 52))
            .foregroundStyle(PharosColor.success)
            .symbolRenderingMode(.hierarchical)
            .accessibilityHidden(true)
        if level == .minimal {
            icon
        } else {
            icon
                .keyframeAnimator(initialValue: BadgeFrame(), trigger: trigger) { content, f in
                    content.scaleEffect(f.scale).opacity(f.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(0.6, duration: 0.01)
                        SpringKeyframe(1.08, duration: 0.28, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.32, spring: .smooth)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0, duration: 0.01)
                        LinearKeyframe(1, duration: 0.18)
                    }
                }
                .onAppear { trigger.toggle() }
        }
    }
}

private struct BadgeFrame {
    var scale: Double = 1
    var opacity: Double = 1
}
