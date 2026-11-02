import SwiftUI
import PharosCore

/// Top bar (language + skip) and bottom bar (progress + back/continue) stay still;
/// only the step stage carries the zoom-blur transition, keeping the offscreen pass small.
struct OnboardingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var level: OnboardingMotionLevel { OnboardingMotion.level(reduceMotion: reduceMotion) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            bottomBar
        }
        .frame(width: OnboardingWindowController.contentSize.width,
               height: OnboardingWindowController.contentSize.height)
        .background(PharosColor.windowGradient)
    }

    // MARK: Bars

    private var topBar: some View {
        HStack(spacing: PharosSpacing.s) {
            Spacer()
            OnboardingLanguageToggle(language: $l10n.language)
            if !coordinator.step.isLast {
                Button(l10n.onboardingSkip) { coordinator.skip() }
                    .buttonStyle(.pharos)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, PharosSpacing.l)
        .frame(height: 44)
        // Leave room for the traffic lights on the left.
        .padding(.leading, 72)
    }

    private var stage: some View {
        ZStack {
            OnboardingStepPlaceholder(step: coordinator.step, level: level)
                .id(coordinator.step)
                .transition(OnboardingZoomBlurTransition(direction: coordinator.direction, level: level))
        }
        .animation(OnboardingMotion.stepAnimation(level), value: coordinator.step)
    }

    private var bottomBar: some View {
        HStack {
            OnboardingProgressDots(current: coordinator.step)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(l10n.onboardingStepIndicator(coordinator.step.rawValue + 1,
                                                                of: OnboardingStep.allCases.count))
            Spacer()
            if coordinator.canGoBack {
                Button(l10n.onboardingBack) { coordinator.goBack() }
                    .buttonStyle(.pharos)
            }
            Button(coordinator.step.isLast ? l10n.onboardingEnter : l10n.onboardingContinue) {
                coordinator.goForward()
            }
            .buttonStyle(.pharosPrimary)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, PharosSpacing.xl)
        .frame(height: 64)
    }
}

// MARK: - Components

private struct OnboardingLanguageToggle: View {
    @Binding var language: AppLanguage

    var body: some View {
        HStack(spacing: 2) {
            option(.simplifiedChinese, label: "中文")
            option(.english, label: "EN")
        }
        .padding(2)
        .background(Capsule(style: .continuous).fill(PharosColor.fill))
    }

    private func option(_ value: AppLanguage, label: String) -> some View {
        let selected = language == value
        return Button { language = value } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? PharosColor.textPrimary : PharosColor.textSecondary)
                .padding(.horizontal, 9)
                .frame(height: 20)
                .background(Capsule(style: .continuous).fill(selected ? PharosColor.surface : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(value.displayName)
    }
}

/// Capsule progress dots; the active pill slides between positions.
private struct OnboardingProgressDots: View {
    let current: OnboardingStep
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                ZStack {
                    Capsule().fill(PharosColor.separator).frame(width: 6, height: 6)
                    if step == current {
                        Capsule()
                            .fill(PharosColor.accentFill)
                            .frame(width: 18, height: 6)
                            .matchedGeometryEffect(id: "active", in: ns)
                    }
                }
                .frame(width: step == current ? 18 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: current)
    }
}

/// Phase 2 stand-in: real step views replace this in Phase 3.
private struct OnboardingStepPlaceholder: View {
    let step: OnboardingStep
    let level: OnboardingMotionLevel
    @ObservedObject private var l10n = L10n.shared

    private var content: (icon: String, title: String, subtitle: String) {
        switch step {
        case .welcome: ("sparkles", l10n.onboardingWelcomeTitle, l10n.onboardingWelcomeSubtitle)
        case .powerIntro: ("powerplug.fill", l10n.onboardingPowerTitle, l10n.onboardingPowerSubtitle)
        case .permissions: ("lock.shield", l10n.onboardingPermissionsTitle, l10n.onboardingPermissionsSubtitle)
        case .preferences: ("slider.horizontal.3", l10n.onboardingPrefsTitle, l10n.onboardingPrefsSubtitle)
        case .menuBar: ("menubar.rectangle", l10n.onboardingMenuBarTitle, l10n.onboardingMenuBarSubtitle)
        case .completion: ("checkmark.circle.fill", l10n.onboardingDoneTitle, l10n.onboardingDoneSubtitle)
        }
    }

    var body: some View {
        let c = content
        VStack(spacing: PharosSpacing.m) {
            Image(systemName: c.icon)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(PharosColor.textPrimary)
                .frame(width: 96, height: 96)
                .background(RoundedRectangle(cornerRadius: PharosRadius.container, style: .continuous)
                    .fill(PharosColor.surface))
                .onboardingEntrance(0, level: level)
            Text(c.title)
                .font(PharosFont.pageTitle)
                .foregroundStyle(PharosColor.textPrimary)
                .onboardingEntrance(1, level: level)
            Text(c.subtitle)
                .font(PharosFont.body)
                .foregroundStyle(PharosColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingEntrance(2, level: level)
            PharosTag(l10n.onboardingPlaceholderNote)
                .onboardingEntrance(3, level: level)
        }
        .padding(PharosSpacing.xl)
    }
}
