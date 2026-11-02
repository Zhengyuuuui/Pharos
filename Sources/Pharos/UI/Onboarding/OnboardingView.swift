import SwiftUI
import PharosCore

/// Top bar (language + skip) and bottom bar (progress + back/continue) stay still;
/// only the step stage carries the zoom-blur transition, keeping the offscreen pass small.
struct OnboardingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped when Low Power Mode toggles so `level` is re-read while the window is open.
    @State private var powerStateTick = 0

    private var level: OnboardingMotionLevel {
        _ = powerStateTick
        return OnboardingMotion.level(reduceMotion: reduceMotion)
    }

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
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: RunLoop.main)) { _ in
            powerStateTick &+= 1
        }
    }

    // MARK: Bars

    private var topBar: some View {
        HStack(spacing: PharosSpacing.s) {
            Spacer()
            OnboardingLanguageToggle(language: $l10n.language)
            if !coordinator.step.isLast {
                Button(l10n.onboardingSkip) { coordinator.skip() }
                    .buttonStyle(.pharos)
                    .disabled(coordinator.isCommitting)
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
            stepView
                .id(coordinator.step)
                .transition(OnboardingZoomBlurTransition(direction: coordinator.direction, level: level))
        }
        .animation(OnboardingMotion.stepAnimation(level), value: coordinator.step)
    }

    @ViewBuilder
    private var stepView: some View {
        switch coordinator.step {
        case .welcome: OnboardingWelcomeStepView(level: level)
        case .capabilities: OnboardingCapabilitiesStepView(level: level)
        case .permissions: OnboardingPermissionsStepView(coordinator: coordinator, level: level)
        case .preferences: OnboardingPreferencesStepView(coordinator: coordinator, level: level)
        case .menuBar: OnboardingMenuBarStepView(level: level)
        case .completion: OnboardingCompletionStepView(coordinator: coordinator, level: level)
        }
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
                    .disabled(coordinator.isCommitting)
            }
            Button {
                coordinator.goForward()
            } label: {
                HStack(spacing: 6) {
                    if coordinator.isCommitting { ProgressView().controlSize(.mini) }
                    Text(coordinator.step.isLast ? l10n.onboardingEnter : l10n.onboardingContinue)
                }
            }
            .buttonStyle(.pharosPrimary)
            .keyboardShortcut(.defaultAction)
            .disabled(coordinator.isCommitting)
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
