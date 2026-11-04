import AppKit
import SwiftUI
import PharosCore

enum ThermalStyle {
    static func color(_ celsius: Double) -> Color {
        celsius >= 95 ? .red : celsius >= 85 ? .orange : celsius >= 70 ? .yellow : .green
    }

    static func stateColor(_ s: ProcessInfo.ThermalState) -> Color {
        switch s {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .secondary
        }
    }

    static func temp(_ c: Double) -> String { String(format: "%.0f°C", c) }

    /// Battery → Energy Mode is the only Apple-supported way to raise fan
    /// headroom (High Power Mode, on supported models).
    static func openEnergySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Compact rows for the popover overview.
struct PopoverThermalSection: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if let t = store.thermals {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.thermalTitle).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(l10n.thermalStateName(store.thermalState))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ThermalStyle.stateColor(store.thermalState))
                    Button {
                        WindowRouter.shared.batteryThermalTab = .thermals
                        AppDelegate.shared?.showMainWindow(selecting: .batteryAndThermals)
                    } label: {
                        Text(l10n.manage).font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                }
                HStack(spacing: 10) {
                    ForEach(t.fans) { f in
                        HStack(spacing: 4) {
                            Image(systemName: "fanblades").font(.system(size: 10)).foregroundStyle(.secondary)
                            Text(f.actualRPM > 0 ? "\(f.actualRPM)" : l10n.fanStopped)
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                        }
                        .help(l10n.fanName(f.index, of: t.fans.count))
                    }
                    Spacer()
                    ForEach([SensorGroup.cpu, .gpu], id: \.self) { g in
                        if let c = t.groups[g] {
                            HStack(spacing: 3) {
                                Text(l10n.sensorGroup(g)).font(.system(size: 10)).foregroundStyle(.secondary)
                                Text(ThermalStyle.temp(c))
                                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                                    .foregroundStyle(ThermalStyle.color(c))
                            }
                        }
                    }
                }
                FanControlStatusLine()
            }
        }
    }
}

/// Main window page: fans, temperatures, and fan control (when installed).
struct ThermalView: View {
    var showsTitle: Bool = true
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    private var statusLevel: PharosStatusIndicator.Level {
        switch store.thermalState {
        case .nominal: return .normal
        case .critical: return .critical
        default: return .warning
        }
    }

    var body: some View {
        PharosPage {
            PharosPageHeader(
                title: showsTitle ? l10n.thermalTitle : l10n.blockDescription(.thermals)
            ) {
                HStack(spacing: PharosSpacing.s) {
                    PharosStatusIndicator(
                        level: statusLevel,
                        text: l10n.thermalStateName(store.thermalState)
                    )
                    PharosActionButton(l10n.openEnergySettings, role: .standard) {
                        ThermalStyle.openEnergySettings()
                    }
                    .controlSize(.small)
                }
            }
        } content: {
            if let t = store.thermals {
                FanSpeedometerClusterView()

                FanControlCard()

                ThermalDiagnosticsSection()

                PharosSection(title: l10n.temperaturesTitle, systemImage: "thermometer.medium") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: PharosSpacing.m)], spacing: PharosSpacing.m) {
                        ForEach(SensorGroup.allCases, id: \.self) { g in
                            if let c = t.groups[g] {
                                TempTile(group: g, celsius: c)
                            }
                        }
                    }
                }
            } else {
                ThermalDiagnosticsSection()

                PharosCard {
                    PharosEmptyState(
                        title: l10n.thermalUnavailable,
                        systemImage: "exclamationmark.triangle",
                        message: l10n.thermalReadNotice,
                        tint: PharosColor.warning
                    )
                }
            }

            PharosBanner(kind: .info, text: l10n.thermalReadNotice)
        }
        .onAppear {
            FanStore.shared.refreshState()
        }
        .task {
            while !Task.isCancelled {
                await store.refreshThermals()
                try? await Task.sleep(for: .milliseconds(800))
            }
        }
    }
}

private typealias FanCard = ClassicFanBarCard

private struct TempTile: View {
    @ObservedObject private var l10n = L10n.shared
    let group: SensorGroup
    let celsius: Double

    var body: some View {
        VStack(alignment: .leading, spacing: PharosSpacing.xs) {
            Text(l10n.sensorGroup(group))
                .font(PharosFont.caption)
                .foregroundStyle(PharosColor.textSecondary)
            Text(ThermalStyle.temp(celsius))
                .font(PharosFont.metricValue)
                .foregroundStyle(ThermalStyle.color(celsius))
        }
        .padding(PharosSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: PharosRadius.card, style: .continuous).fill(PharosColor.fill))
    }
}

/// Comprehensive heat diagnostics section explaining why the Mac is warm/hot,
/// highlighting root causes (fast charging, compile jobs, media AI, silent fan curve delay),
/// and offering direct remediation actions.
private struct ThermalDiagnosticsSection: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if let diag = store.thermalDiagnosis {
            PharosSection(
                title: l10n.thermalDiagnosticsTitle,
                systemImage: "flame.circle.fill"
            ) {
                VStack(alignment: .leading, spacing: PharosSpacing.l) {
                    // Overall Severity Header
                    severityBanner(diag)

                    // Root Causes & Inducements
                    if !diag.reasons.isEmpty {
                        VStack(alignment: .leading, spacing: PharosSpacing.s) {
                            Text(l10n.thermalReasonsTitle)
                                .font(PharosFont.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(PharosColor.textSecondary)

                            VStack(spacing: PharosSpacing.s) {
                                ForEach(diag.reasons) { reason in
                                    reasonCard(reason)
                                }
                            }
                        }
                    }

                    // Top Culprit Workloads
                    if !diag.culprits.isEmpty {
                        VStack(alignment: .leading, spacing: PharosSpacing.s) {
                            HStack {
                                Text(l10n.thermalCulpritsTitle)
                                    .font(PharosFont.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(PharosColor.textSecondary)
                                Spacer()
                                Text("\(diag.culprits.count)")
                                    .font(PharosFont.captionDigits)
                                    .foregroundStyle(PharosColor.textTertiary)
                            }

                            VStack(spacing: PharosSpacing.xs) {
                                ForEach(diag.culprits) { culprit in
                                    culpritRow(culprit)
                                }
                            }
                        }
                    }

                    // Suggestions & Mitigation Actions
                    if !diag.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: PharosSpacing.s) {
                            Text(l10n.thermalSuggestionsTitle)
                                .font(PharosFont.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(PharosColor.textSecondary)

                            ForEach(diag.suggestions) { suggestion in
                                suggestionCard(suggestion)
                            }
                        }
                    }
                }
            }
        }
    }

    private func severityBanner(_ diag: ThermalDiagnosisReport) -> some View {
        HStack(alignment: .center, spacing: PharosSpacing.m) {
            ZStack {
                Circle()
                    .fill(severityColor(diag.level).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: severityIcon(diag.level))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(severityColor(diag.level))
            }

            VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                HStack(spacing: PharosSpacing.xs) {
                    Text(severityTitle(diag.level))
                        .font(PharosFont.rowLabel)
                    Spacer()
                    Text(String(format: "%.0f°C", diag.peakTemperature))
                        .font(PharosFont.metricValue)
                        .foregroundStyle(severityColor(diag.level))
                }
                Text(l10n.thermalDiagnosticsSubtitle)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
            }
        }
        .padding(PharosSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                .fill(PharosColor.fill.opacity(0.6))
        )
    }

    private func reasonCard(_ reason: ThermalReason) -> some View {
        HStack(alignment: .top, spacing: PharosSpacing.s + 2) {
            ZStack {
                RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                    .fill(severityColor(reason.severity).opacity(0.16))
                    .frame(width: 28, height: 28)
                Image(systemName: reason.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(severityColor(reason.severity))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(reason.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(PharosColor.textPrimary)
                Text(reason.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(PharosColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(PharosSpacing.s + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                .fill(PharosColor.surfaceSecondary)
        )
    }

    private func culpritRow(_ culprit: ThermalCulprit) -> some View {
        HStack(spacing: PharosSpacing.s) {
            Image(systemName: culprit.category.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PharosColor.textSecondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(culprit.name)
                        .font(.system(size: 12, weight: .semibold))
                    Text("PID \(culprit.pid)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(PharosColor.textTertiary)
                    if culprit.memoryBytes > 0 {
                        Text(ByteFormat.short(culprit.memoryBytes))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(PharosColor.textSecondary)
                    }
                }
                Text(culprit.explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(PharosColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if culprit.isKillable {
                PharosActionButton(l10n.terminateCulpritProcess, role: .destructive) {
                    store.terminateCulprit(pid: culprit.pid)
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, PharosSpacing.s + 2)
        .padding(.vertical, PharosSpacing.xs + 2)
        .background(
            RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                .fill(PharosColor.fill.opacity(0.4))
        )
    }

    private func suggestionCard(_ suggestion: ThermalSuggestion) -> some View {
        HStack(spacing: PharosSpacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PharosColor.textPrimary)
                Text(suggestion.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(PharosColor.textSecondary)
            }

            Spacer(minLength: 8)

            switch suggestion.actionKind {
            case .maxFans:
                PharosActionButton(l10n.rampUpFansAction, role: .primary) {
                    if FanStore.shared.helper == .ready {
                        FanStore.shared.apply(.max)
                    } else {
                        FanStore.shared.install()
                    }
                }
                .controlSize(.small)
            case .openEnergySettings:
                PharosActionButton(l10n.openEnergyModeAction, role: .standard) {
                    ThermalStyle.openEnergySettings()
                }
                .controlSize(.small)
            case .killProcess(let pid, _):
                PharosActionButton(l10n.terminateCulpritProcess, role: .destructive) {
                    store.terminateCulprit(pid: pid)
                }
                .controlSize(.small)
            case .adviceOnly:
                EmptyView()
            }
        }
        .padding(PharosSpacing.s + 2)
        .background(
            RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                .fill(PharosColor.surfaceSecondary)
        )
    }

    private func severityTitle(_ level: ThermalSeverityLevel) -> String {
        switch level {
        case .cool: return l10n.thermalCoolTitle
        case .warm: return l10n.thermalWarmTitle
        case .hot: return l10n.thermalHotTitle
        case .critical: return l10n.thermalCriticalTitle
        }
    }

    private func severityColor(_ level: ThermalSeverityLevel) -> Color {
        switch level {
        case .cool: return PharosColor.success
        case .warm: return Color.yellow
        case .hot: return PharosColor.warning
        case .critical: return PharosColor.error
        }
    }

    private func severityIcon(_ level: ThermalSeverityLevel) -> String {
        switch level {
        case .cool: return "snowflake"
        case .warm: return "thermometer.medium"
        case .hot: return "flame.fill"
        case .critical: return "exclamationmark.triangle.fill"
        }
    }
}
