import SwiftUI
import PharosCore

/// A sandboxed illustration: nothing here talks to `pharos-battd`. Only the footer line reads real values.
struct OnboardingPowerIntroStepView: View {
    let level: OnboardingMotionLevel
    @EnvironmentObject private var store: ProjectStore
    @ObservedObject private var battery = BatteryStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if battery.reading.hasBattery {
            OnboardingStepScaffold(title: l10n.onboardingPowerTitle, subtitle: l10n.onboardingPowerSubtitle, level: level) {
                OnboardingPowerDemoCard(level: level)
            }
        } else {
            OnboardingStepScaffold(title: l10n.onboardingDesktopTitle, subtitle: l10n.onboardingDesktopSubtitle, level: level) {
                desktopGrid
            }
        }
    }

    private var desktopGrid: some View {
        let t = store.thermals
        let peak = t?.peakChipTemperature.map { "\(Int($0.rounded()))°C" } ?? "—"
        let fan = t?.fans.first.map { "\($0.actualRPM) rpm" } ?? "—"
        let mem = store.system.map { "\(Int(($0.usedFraction * 100).rounded()))%" } ?? "—"
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            metric(l10n.onboardingDesktopPeakTemp, peak, "thermometer.medium")
            metric(l10n.onboardingDesktopFan, fan, "fan")
            metric(l10n.onboardingDesktopMemory, mem, "memorychip")
            metric(l10n.onboardingDesktopPorts, "\(store.totalPorts)", "network")
        }
        .frame(maxWidth: 520)
    }

    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        PharosCard(padding: 14) {
            HStack(spacing: PharosSpacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(PharosColor.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                    Text(value)
                        .font(PharosFont.metricValue)
                        .foregroundStyle(PharosColor.textPrimary)
                        .contentTransition(.numericText())
                }
            }
        }
    }
}

private struct OnboardingPowerDemoCard: View {
    let level: OnboardingMotionLevel
    @ObservedObject private var battery = BatteryStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var flow: PowerDemoFlow = .charging
    @State private var userPicked = false

    var body: some View {
        PharosCard(padding: 16) {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack {
                    PharosTag(l10n.onboardingPowerDemoBadge, systemImage: "hand.tap", tint: PharosColor.warning)
                    Spacer()
                }
                modePicker
                PowerFlowDiagramView(flow: flow, level: level)
                Text(caption)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 30, alignment: .topLeading)
                PharosListDivider()
                Text(liveLine)
                    .font(PharosFont.captionDigits)
                    .foregroundStyle(PharosColor.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 560)
        // One gentle tour ending on passthrough; any click stops it for good. Reduce Motion: no tour.
        .task {
            guard level != .minimal else { flow = .passthrough; return }
            for next in PowerDemoFlow.tour {
                try? await Task.sleep(for: .seconds(3.2))
                if Task.isCancelled || userPicked { return }
                withAnimation(.easeInOut(duration: 0.35)) { flow = next }
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(PowerDemoFlow.allCases, id: \.self) { m in
                let selected = m == flow
                Button {
                    userPicked = true
                    withAnimation(.easeInOut(duration: 0.25)) { flow = m }
                } label: {
                    Text(title(m))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(selected ? PharosColor.textPrimary : PharosColor.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(Capsule(style: .continuous).fill(selected ? PharosColor.surface : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule(style: .continuous).fill(PharosColor.fill))
    }

    private func title(_ m: PowerDemoFlow) -> String {
        switch m {
        case .charging: l10n.onboardingPowerModeCharging
        case .passthrough: l10n.onboardingPowerModeBypass
        case .onBattery: l10n.onboardingPowerModeBattery
        }
    }

    private var caption: String {
        switch flow {
        case .charging: l10n.onboardingPowerChargingCaption
        case .passthrough: l10n.onboardingPowerBypassCaption
        case .onBattery: l10n.onboardingPowerBatteryCaption
        }
    }

    private var liveLine: String {
        let r = battery.reading
        let flowText: String = switch battery.powerFlow {
        case .passthrough: l10n.batteryFlowPassthrough
        case .charging: l10n.batteryFlowCharging
        case .supplementing: l10n.batteryFlowSupplementing
        case .onBattery: l10n.batteryFlowOnBattery
        }
        return l10n.onboardingPowerLiveReading(percent: r.currentPercent, flow: flowText, amperage: r.amperage)
    }
}
