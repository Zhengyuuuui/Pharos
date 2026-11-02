import SwiftUI
import PharosCore

/// Every control writes `coordinator.draft` only. Nothing reaches hardware until Continue.
struct OnboardingPreferencesStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let level: OnboardingMotionLevel
    @ObservedObject private var battery = BatteryStore.shared
    @ObservedObject private var l10n = L10n.shared

    private var limitBinding: Binding<Double> {
        Binding(
            get: { Double(coordinator.draft.targetLimit) },
            set: { coordinator.draft.setTargetLimit(Int($0.rounded())) }
        )
    }

    var body: some View {
        OnboardingStepScaffold(title: l10n.onboardingPrefsTitle, subtitle: l10n.onboardingPrefsSubtitle, level: level) {
            ScrollView {
                VStack(spacing: PharosSpacing.m) {
                    if coordinator.canOfferChargeLimit { chargingCard }
                    if let notice = coordinator.preferencesNotice {
                        PharosBanner(kind: .info, text: notice)
                    }
                    generalCard
                }
                // One transaction for the whole stack so the cards below follow the collapsing edge.
                .animation(OnboardingMotion.collapseAnimation(level), value: coordinator.draft.chargingChoice)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.never)
            .disabled(coordinator.isCommitting)
        }
    }

    private var chargingCard: some View {
        PharosCard(padding: 14) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: PharosSpacing.m) {
                    Text(l10n.onboardingPrefsChargingTitle).font(PharosFont.rowLabel)
                    Picker("", selection: $coordinator.draft.chargingChoice) {
                        Text(l10n.onboardingPrefsChargingSystem).tag(OnboardingDraft.ChargingChoice.systemManaged)
                        Text(l10n.onboardingPrefsChargingLimit).tag(OnboardingDraft.ChargingChoice.pharosLimit)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                OnboardingCollapsibleSection(isExpanded: coordinator.draft.chargingChoice == .pharosLimit, level: level) {
                    limitPanel.padding(.top, PharosSpacing.m)
                }
            }
        }
    }

    private var limitPanel: some View {
        VStack(alignment: .leading, spacing: PharosSpacing.s) {
            HStack(alignment: .center, spacing: PharosSpacing.l) {
                VStack(alignment: .leading, spacing: PharosSpacing.s) {
                    HStack(spacing: 6) {
                        presetPill(80, label: l10n.onboardingPrefsLimitRecommended)
                        presetPill(85, label: "85%")
                        presetPill(90, label: "90%")
                    }
                    Slider(value: limitBinding, in: 50...100, step: 1)
                        .controlSize(.small)
                }
                ring
            }
            Toggle(l10n.onboardingPrefsPersistentGuard, isOn: $coordinator.draft.persistentGuard)
                .toggleStyle(.switch)
                .controlSize(.small)
            Text(l10n.onboardingPrefsLimitSafetyNote)
                .font(PharosFont.caption)
                .foregroundStyle(PharosColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func presetPill(_ value: Int, label: String) -> some View {
        let selected = coordinator.draft.targetLimit == value
        return Button { coordinator.draft.setTargetLimit(value) } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(selected ? PharosColor.onAccent : PharosColor.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(Capsule(style: .continuous).fill(selected ? PharosColor.accentFill : PharosColor.fill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var ring: some View {
        let limit = coordinator.draft.targetLimit
        return ZStack {
            // Inset strokes keep the ring inside its frame; the collapsible section clips anything outside.
            Circle().inset(by: 3).stroke(PharosColor.fill, lineWidth: 6)
            Circle()
                .inset(by: 3)
                .trim(from: 0, to: CGFloat(limit) / 100)
                .stroke(Color.teal, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(limit)%")
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .contentTransition(.numericText(value: Double(limit)))
        }
        .frame(width: 64, height: 64)
        .padding(.horizontal, PharosSpacing.s)
        .padding(.vertical, 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: limit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(limit)%")
    }

    private var generalCard: some View {
        PharosCard(padding: 14) {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                if battery.reading.hasBattery {
                    Toggle(isOn: $coordinator.draft.pinBatteryInPopover) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.onboardingPrefsPinBattery)
                            Text(l10n.onboardingPrefsPinBatteryDesc)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    PharosListDivider()
                }
                HStack {
                    Text(l10n.onboardingPrefsMenuBarText)
                    Spacer()
                    Picker("", selection: $coordinator.draft.menuBarTextRaw) {
                        ForEach(MenuBarText.allCases) { option in
                            Text(l10n.menuBarTextOption(option)).tag(option.rawValue)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                PharosListDivider()
                Toggle(l10n.onboardingPrefsLaunchAtLogin, isOn: $coordinator.draft.launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }
}
