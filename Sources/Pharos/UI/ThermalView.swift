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
                        AppDelegate.shared?.showMainWindow(selecting: .thermals)
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

                PharosSection(title: l10n.temperaturesTitle, systemImage: "thermometer.medium") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: PharosSpacing.m)], spacing: PharosSpacing.m) {
                        ForEach(SensorGroup.allCases, id: \.self) { g in
                            if let c = t.groups[g] {
                                TempTile(group: g, celsius: c)
                            }
                        }
                    }
                }

                ThermalDiagnosticsSection()
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
            FanStore.shared.viewAppeared()
            FanStore.shared.refreshState()
        }
        .onDisappear {
            FanStore.shared.viewDisappeared()
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

/// Dynamic real-time CPU Heat & Runaway Diagnostics.
/// Identifies heavy CPU hogs and orphaned background processes causing chip heat,
/// presenting full commands, working directories, and one-click graceful-to-force termination.
private struct ThermalDiagnosticsSection: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let report = store.cpuDiagnosis ?? .nominal

        PharosSection(
            title: l10n.cpuDiagnosticsTitle,
            systemImage: "cpu"
        ) {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                // Top Status Card
                if report.isNominal {
                    nominalStatusBanner
                } else {
                    elevatedStatusBanner(count: report.processes.count)
                }

                // High-load or Orphan Process Cards
                if !report.processes.isEmpty {
                    VStack(spacing: PharosSpacing.s) {
                        ForEach(report.processes) { process in
                            culpritProcessCard(process)
                        }
                    }
                }
            }
        }
    }

    private var nominalStatusBanner: some View {
        HStack(spacing: PharosSpacing.m) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PharosColor.success)

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.cpuLoadNormal)
                    .font(PharosFont.rowLabel)
                    .foregroundStyle(PharosColor.textPrimary)
                Text(l10n.cpuDiagnosticsDesc)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
            }
            Spacer()
        }
        .padding(PharosSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: PharosRadius.card, style: .continuous)
                .fill(PharosColor.success.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PharosRadius.card, style: .continuous)
                .strokeBorder(PharosColor.success.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func elevatedStatusBanner(count: Int) -> some View {
        HStack(spacing: PharosSpacing.m) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PharosColor.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.cpuAbnormalProcessCount(count))
                    .font(PharosFont.rowLabel)
                    .foregroundStyle(PharosColor.textPrimary)
                Text(l10n.cpuDiagnosticsDesc)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
            }
            Spacer()
        }
        .padding(PharosSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: PharosRadius.card, style: .continuous)
                .fill(PharosColor.warning.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PharosRadius.card, style: .continuous)
                .strokeBorder(PharosColor.warning.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func culpritProcessCard(_ process: CPURunawayProcess) -> some View {
        let isTerminating = store.terminatingPIDs.contains(process.pid)
        let isCriticalHeat = process.cpuPercent >= 70.0

        return VStack(alignment: .leading, spacing: PharosSpacing.s) {
            // Header Row: Icon, Name, PID, Badges, Spacer, Terminate Button
            HStack(alignment: .center, spacing: PharosSpacing.s) {
                Image(systemName: process.isOrphan ? "exclamationmark.triangle.fill" : (process.isCompilerOrBuild ? "hammer.fill" : "cpu"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(process.isOrphan ? PharosColor.warning : (isCriticalHeat ? PharosColor.error : PharosColor.accent))
                    .frame(width: 18)

                Text(process.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PharosColor.textPrimary)

                Text("PID \(process.pid)")
                    .font(PharosFont.captionDigits)
                    .foregroundStyle(PharosColor.textTertiary)

                // CPU% Badge
                Text(String(format: "%.0f%% CPU", process.cpuPercent))
                    .font(PharosFont.captionDigits)
                    .fontWeight(.semibold)
                    .foregroundStyle(isCriticalHeat ? PharosColor.error : PharosColor.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill((isCriticalHeat ? PharosColor.error : PharosColor.warning).opacity(0.14))
                    )

                // Category Badge
                HStack(spacing: 3) {
                    Image(systemName: {
                        switch process.category {
                        case .runawayOrphan: return "link.badge.plus"
                        case .compiler: return "hammer.fill"
                        case .thermalInducement: return "flame.fill"
                        case .highWorkload: return "cpu.fill"
                        }
                    }())
                    .font(.system(size: 8))
                    Text(l10n.cpuCategoryTag(process.category))
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(process.category == .runawayOrphan ? PharosColor.warning : (isCriticalHeat ? PharosColor.error : PharosColor.accent))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill((process.category == .runawayOrphan ? PharosColor.warning : (isCriticalHeat ? PharosColor.error : PharosColor.accent)).opacity(0.12))
                )

                // Memory Footprint (if > 0)
                if process.memoryBytes > 0 {
                    Text(ByteFormat.short(process.memoryBytes))
                        .font(PharosFont.captionDigits)
                        .foregroundStyle(PharosColor.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(PharosColor.fill))
                }

                // Elapsed Uptime
                if process.elapsedTimeSeconds > 0 {
                    Text("⏱ \(process.formattedElapsedTime)")
                        .font(PharosFont.captionDigits)
                        .foregroundStyle(PharosColor.textTertiary)
                }

                Spacer(minLength: 8)

                // Terminate Action Button
                PharosActionButton(
                    isTerminating ? l10n.terminating : l10n.terminateProcess,
                    role: .destructive
                ) {
                    store.terminateCulprit(pid: process.pid)
                }
                .controlSize(.small)
                .disabled(isTerminating || !process.isKillable)
            }

            // Friendly Cause Explanation
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(PharosColor.textTertiary)
                    .padding(.top, 1)

                Text(l10n.cpuCulpritExplanation(process.category))
                    .font(.system(size: 11))
                    .foregroundStyle(PharosColor.textSecondary)
            }

            // Command & Directory Inspect Strip
            if !process.fullCommand.isEmpty || (process.workingDirectory != nil && !process.workingDirectory!.isEmpty) {
                VStack(alignment: .leading, spacing: 3) {
                    if !process.fullCommand.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Text(l10n.command + ":")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PharosColor.textTertiary)
                            Text(process.fullCommand)
                                .font(.system(size: 10.5).monospaced())
                                .foregroundStyle(PharosColor.textSecondary)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }
                    if let cwd = process.workingDirectory, !cwd.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Text(l10n.workingDir + ":")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PharosColor.textTertiary)
                            Text(cwd)
                                .font(.system(size: 10.5).monospaced())
                                .foregroundStyle(PharosColor.textTertiary)
                                .lineLimit(1)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.12))
                )
            }
        }
        .padding(PharosSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: PharosRadius.card, style: .continuous)
                .fill(PharosColor.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PharosRadius.card, style: .continuous)
                .strokeBorder(isCriticalHeat ? PharosColor.error.opacity(0.25) : PharosColor.separator.opacity(0.3), lineWidth: 0.5)
        )
    }
}
