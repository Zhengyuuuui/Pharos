import SwiftUI
import PharosCore

/// Common title block + body layout so every step lines up the same way.
struct OnboardingStepScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let level: OnboardingMotionLevel
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: PharosSpacing.l) {
            VStack(spacing: PharosSpacing.xs) {
                Text(title)
                    .font(PharosFont.pageTitle)
                    .foregroundStyle(PharosColor.textPrimary)
                    .onboardingEntrance(0, level: level)
                Text(subtitle)
                    .font(PharosFont.body)
                    .foregroundStyle(PharosColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520)
                    .onboardingEntrance(1, level: level)
            }
            content
                .onboardingEntrance(2, level: level)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PharosSpacing.xxl)
        .padding(.top, PharosSpacing.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Right-aligned green status capsule used for "ready / installed / granted".
struct OnboardingStatusTag: View {
    let text: String
    var body: some View {
        PharosTag(text, systemImage: "checkmark.circle.fill", tint: PharosColor.success)
    }
}
