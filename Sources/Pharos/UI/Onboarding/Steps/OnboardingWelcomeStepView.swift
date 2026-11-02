import SwiftUI
import PharosCore

struct OnboardingWelcomeStepView: View {
    let level: OnboardingMotionLevel
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(spacing: PharosSpacing.l) {
            Spacer(minLength: 0)
            RadarBeamLogoCanvas(level: level)
                .onboardingEntrance(0, level: level)
            VStack(spacing: PharosSpacing.xs) {
                Text(l10n.onboardingWelcomeTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PharosColor.textPrimary)
                    .onboardingEntrance(1, level: level)
                Text(l10n.onboardingWelcomeSubtitle)
                    .font(PharosFont.body)
                    .foregroundStyle(PharosColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 480)
                    .onboardingEntrance(2, level: level)
            }
            HStack(spacing: PharosSpacing.s) {
                PharosTag(l10n.onboardingCapabilityPower, systemImage: "bolt.batteryblock")
                PharosTag(l10n.onboardingCapabilityMemory, systemImage: "memorychip")
                PharosTag(l10n.onboardingCapabilityCleanup, systemImage: "sparkles")
            }
            .onboardingEntrance(3, level: level)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PharosSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
