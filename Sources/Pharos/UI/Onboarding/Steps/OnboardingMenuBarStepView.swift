import SwiftUI
import PharosCore

/// Reuses the real `MenuBarLabel` and `PopoverTabsContent`, so the preview is the popover itself.
struct OnboardingMenuBarStepView: View {
    let level: OnboardingMotionLevel
    @EnvironmentObject private var store: ProjectStore
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var previewTab: PopoverTab = .overview
    @State private var expanded = true

    var body: some View {
        OnboardingStepScaffold(title: l10n.onboardingMenuBarTitle, subtitle: l10n.onboardingMenuBarSubtitle, level: level) {
            HStack(alignment: .top, spacing: PharosSpacing.xl) {
                VStack(alignment: .trailing, spacing: PharosSpacing.s) {
                    menuBarStrip
                    if expanded {
                        popoverPreview
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                    }
                }
                .frame(width: 320)
                .animation(OnboardingMotion.stepAnimation(level), value: expanded)

                VStack(alignment: .leading, spacing: PharosSpacing.m) {
                    tip("circle.dashed", l10n.onboardingMenuBarTipRing)
                    tip("moon.zzz", l10n.onboardingMenuBarTipBackground)
                    tip("bolt.batteryblock", l10n.onboardingMenuBarTipFull)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, PharosSpacing.s)
            }
            .frame(maxWidth: 620)
        }
        .onAppear {
            if let first = layoutStore.layout.visibleTabs.first { previewTab = first }
        }
    }

    private var menuBarStrip: some View {
        HStack(spacing: PharosSpacing.s) {
            Text(l10n.onboardingMenuBarClickHint)
                .font(PharosFont.caption)
                .foregroundStyle(PharosColor.textTertiary)
            Spacer()
            Button { expanded.toggle() } label: {
                MenuBarLabel(store: store)
                    .font(.system(size: 13))
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(expanded ? PharosColor.fillPressed : .clear))
                    .contentShape(Rectangle())
            }
            .buttonStyle(OnboardingPressScaleStyle(enabled: level.allowsScale))
            Image(systemName: "wifi").font(.system(size: 12)).foregroundStyle(PharosColor.textSecondary)
            Image(systemName: "battery.75").font(.system(size: 12)).foregroundStyle(PharosColor.textSecondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous).fill(.bar))
        .overlay(RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
            .strokeBorder(PharosColor.separator.opacity(0.6), lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    private var popoverPreview: some View {
        ScrollView {
            PopoverTabsContent(layout: layoutStore.layout, tab: $previewTab, interactive: false)
                .padding(10)
        }
        .scrollIndicators(.never)
        .frame(width: 320)
        .frame(maxHeight: 250)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(PharosColor.separator.opacity(0.6), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: PharosSpacing.s) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(PharosColor.textSecondary)
                .frame(width: 20)
            Text(text)
                .font(PharosFont.caption)
                .foregroundStyle(PharosColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingPressScaleStyle: ButtonStyle {
    let enabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(enabled && configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
