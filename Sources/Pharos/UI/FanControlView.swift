import SwiftUI
import PharosCore

/// Thermal page card: install the helper, then pick macOS / fixed RPM / max.
struct FanControlCard: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var fan = FanStore.shared
    @ObservedObject private var l10n = L10n.shared

    private enum Mode: Hashable { case system, curve, fixed, max }

    var body: some View {
        let fans = store.thermals?.fans ?? []
        let minRPM = fans.map(\.minRPM).max() ?? 1200
        let maxRPM = max(minRPM + 100, fans.map(\.maxRPM).min() ?? 6000)
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack {
                    Label(l10n.fanControlTitle, systemImage: "slider.horizontal.3")
                        .font(PharosFont.rowLabel)
                    Spacer()
                    if fan.busy { ProgressView().controlSize(.small) }
                    if fan.helper != .notInstalled { uninstallButton }
                }

                if let message = fan.errorMessage {
                    PharosBanner(kind: .error, text: message) {
                        IconButton(systemImage: "xmark", help: l10n.dismiss) { fan.errorMessage = nil }
                    }
                }

                if fan.helperNeedsUpdate {
                    PharosBanner(kind: .warning, text: l10n.fanHelperNeedsUpdateNotice) {
                        Button(l10n.fanUpdateHelper) { fan.install() }
                            .buttonStyle(.pharosPrimary)
                            .controlSize(.small)
                            .disabled(fan.busy)
                    }
                }

                switch fan.helper {
                case .notInstalled:
                    Text(l10n.fanControlIntro).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(l10n.fanInstall) { fan.install() }
                        .buttonStyle(.pharosPrimary)
                        .controlSize(.small)
                        .disabled(fan.busy)
                case .notResponding:
                    Label(l10n.fanNotResponding, systemImage: "exclamationmark.triangle")
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.warning)
                case .ready:
                    Picker("", selection: Binding(get: { mode }, set: { set($0) })) {
                        Text(l10n.fanModeSystem).tag(Mode.system)
                        Text(l10n.fanModeCurve).tag(Mode.curve)
                        Text(l10n.fanModeFixed).tag(Mode.fixed)
                        Text(l10n.fanModeMax).tag(Mode.max)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(fan.busy)

                    if mode == .curve {
                        HStack(alignment: .top, spacing: PharosSpacing.s) {
                            Image(systemName: "wave.3.forward")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PharosColor.accent)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n.fanModeCurve)
                                    .font(.system(size: 12.5, weight: .medium))
                                Text(l10n.fanCurveIntro)
                                    .font(PharosFont.caption)
                                    .foregroundStyle(PharosColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(PharosSpacing.s)
                        .background(
                            RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                                .fill(PharosColor.fill.opacity(0.4))
                        )
                    }

                    if mode == .fixed {
                        VStack(alignment: .leading, spacing: PharosSpacing.xs) {
                            HStack(spacing: PharosSpacing.s) {
                                Slider(
                                    value: Binding(get: { Double(fan.fixedRPM) }, set: { fan.fixedRPM = Int($0 / 100) * 100 }),
                                    in: Double(minRPM)...Double(maxRPM),
                                    onEditingChanged: { isEditing in
                                        if !isEditing {
                                            fan.apply(.fixed(rpm: fan.fixedRPM))
                                        }
                                    }
                                )
                                Text("\(fan.fixedRPM) rpm").font(PharosFont.captionDigits)
                                    .frame(width: 80, alignment: .trailing)
                                Button(l10n.fanApply) { fan.apply(.fixed(rpm: fan.fixedRPM)) }
                                    .buttonStyle(.pharosPrimary)
                                    .controlSize(.small)
                                    .disabled(fan.busy || fan.request == .fixed(rpm: fan.fixedRPM))
                            }
                            Text(l10n.fanFixedIntro)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textTertiary)
                        }
                        .onAppear { fan.fixedRPM = min(max(fan.fixedRPM, minRPM), maxRPM) }
                    }
                    if fan.request == .curve && fan.overheating {
                        Label(l10n.fanOverheat, systemImage: "flame.fill").font(PharosFont.caption).foregroundStyle(PharosColor.error)
                    }
                    if fan.unsupported {
                        Label(l10n.fanUnsupported, systemImage: "nosign").font(PharosFont.caption).foregroundStyle(PharosColor.warning)
                    }
                }

                Text(l10n.fanSafety).font(PharosFont.caption).foregroundStyle(PharosColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            fan.viewAppeared()
            fan.refreshState()
        }
        .onDisappear {
            fan.viewDisappeared()
        }
    }

    private var mode: Mode {
        switch fan.request {
        case .system: return .system
        case .curve: return .curve
        case .fixed: return .fixed
        case .max: return .max
        }
    }

    private func set(_ m: Mode) {
        switch m {
        case .system: fan.apply(.system)
        case .curve: fan.apply(.curve)
        case .max: fan.apply(.max)
        case .fixed: fan.apply(.fixed(rpm: fan.fixedRPM))
        }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await store.refreshThermals()
        }
    }

    private var uninstallButton: some View {
        PharosConfirmButton(
            title: l10n.fanUninstall,
            confirmTitle: l10n.confirm
        ) {
            fan.uninstall()
        }
    }
}

/// One-line status in the popover when Pharos is holding the fans.
struct FanControlStatusLine: View {
    @ObservedObject private var fan = FanStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let isCurveOverheat = (fan.request == .curve && fan.overheating)
        if fan.helper == .ready, fan.request != .system {
            HStack(spacing: 6) {
                Image(systemName: isCurveOverheat ? "flame.fill" : "fanblades.fill")
                    .foregroundStyle(isCurveOverheat ? .red : .orange)
                Text(isCurveOverheat ? l10n.fanOverheat : label)
                    .font(.system(size: 10))
                    .lineLimit(2)
                Spacer()
                if !isCurveOverheat {
                    Button(l10n.fanModeSystem) { fan.apply(.system) }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10))
                }
            }
        }
    }

    private var label: String {
        switch fan.request {
        case .system: return ""
        case .curve: return "\(l10n.fanHeld) · \(l10n.fanModeCurve)"
        case .max: return "\(l10n.fanHeld) · \(l10n.fanModeMax)"
        case .fixed(let rpm): return "\(l10n.fanHeld) · \(rpm) rpm"
        }
    }
}

/// Compact one-click toggle row in the menu-bar popover for Clamshell Agent Guard.
struct PopoverClamshellControlRow: View {
    @ObservedObject private var fan = FanStore.shared
    @ObservedObject private var l10n = L10n.shared

    private var helperReady: Bool {
        fan.helper == .ready && !fan.helperNeedsUpdate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: fan.clamshellEnabled ? "shield.lefthalf.filled" : "laptopcomputer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(fan.clamshellEnabled ? PharosColor.accent : .secondary)

                Text(l10n.clamshellPopoverToggle)
                    .font(.system(size: 11, weight: .medium))

                Spacer()

                if helperReady {
                    Toggle("", isOn: Binding(
                        get: { fan.clamshellEnabled },
                        set: { fan.setClamshell(enabled: $0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .disabled(fan.busy)
                } else {
                    Button {
                        AppDelegate.shared?.showMainWindow(selecting: .thermals)
                    } label: {
                        Text(l10n.clamshellNeedsHelperHint)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PharosColor.warning)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if fan.clamshellEnabled {
                Text(l10n.clamshellPopoverMeta(
                    abortC: Int(fan.clamshellThermalAbort.rounded()),
                    battPct: fan.clamshellBatteryFloor,
                    proactive: fan.clamshellProactiveFan
                ))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(PharosColor.success)
                .padding(.leading, 17)
            }

            if let abort = fan.lastClamshellAbort {
                Button {
                    AppDelegate.shared?.showMainWindow(selecting: .thermals)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        Text(abortSummary(abort))
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(PharosColor.error)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(fan.clamshellEnabled ? PharosColor.accent.opacity(0.08) : PharosColor.fill.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(fan.clamshellEnabled ? PharosColor.accent.opacity(0.28) : Color.clear, lineWidth: 1)
        )
    }

    private func abortSummary(_ abort: ClamshellAbortReason) -> String {
        switch abort {
        case .thermalRunaway(let c):
            return l10n.clamshellAbortThermalMsg(Int(c.rounded()))
        case .lowBattery(let p):
            return l10n.clamshellAbortBatteryMsg(p)
        case .heartbeatTimeout:
            return l10n.clamshellAbortHeartbeatMsg
        }
    }
}

/// Main Thermals page card: toggle Clamshell Agent Guard & configure sealed-bag thermal redline + battery floor.
struct ClamshellGuardCard: View {
    @ObservedObject private var fan = FanStore.shared
    @ObservedObject private var l10n = L10n.shared

    private let thermalChoices: [Int] = [80, 82, 84, 86, 88, 90]
    private let batteryChoices: [Int] = [10, 15, 20, 30]

    private var helperReady: Bool {
        fan.helper == .ready && !fan.helperNeedsUpdate
    }

    var body: some View {
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack(spacing: PharosSpacing.s) {
                    Label(l10n.clamshellTitle, systemImage: fan.clamshellEnabled ? "shield.lefthalf.filled" : "laptopcomputer")
                        .font(PharosFont.rowLabel)

                    if fan.clamshellEnabled {
                        PharosStatusIndicator(
                            level: .normal,
                            text: l10n.clamshellActiveBadge
                        )
                    } else {
                        HStack(spacing: PharosSpacing.xs + 1) {
                            Image(systemName: "moon.zzz")
                                .foregroundStyle(PharosColor.textTertiary)
                            Text(l10n.clamshellInactiveBadge)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                        .font(PharosFont.caption)
                        .padding(.horizontal, PharosSpacing.s + 2)
                        .padding(.vertical, PharosSpacing.xs)
                        .background(Capsule().fill(PharosColor.fill))
                    }

                    Spacer()

                    if helperReady {
                        Toggle("", isOn: Binding(
                            get: { fan.clamshellEnabled },
                            set: { fan.setClamshell(enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(fan.busy)
                    } else if fan.helper == .notInstalled {
                        Button(l10n.fanInstall) { fan.install() }
                            .buttonStyle(.pharosPrimary)
                            .controlSize(.small)
                            .disabled(fan.busy)
                    } else if fan.helperNeedsUpdate {
                        Button(l10n.fanUpdateHelper) { fan.install() }
                            .buttonStyle(.pharosPrimary)
                            .controlSize(.small)
                            .disabled(fan.busy)
                    }
                }

                Text(l10n.clamshellIntro)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let abort = fan.lastClamshellAbort {
                    PharosBanner(kind: .error, text: abortMessage(abort)) {
                        IconButton(systemImage: "xmark", help: l10n.dismiss) {
                            fan.dismissClamshellAbort()
                        }
                    }
                }

                // Backpack / sealed container thermal suffocation safeguard explanation
                HStack(alignment: .top, spacing: PharosSpacing.s) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PharosColor.warning)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.clamshellBagWarningTitle)
                            .font(.system(size: 12, weight: .semibold))
                        Text(l10n.clamshellBagWarningBody)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(PharosSpacing.s)
                .background(
                    RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                        .fill(PharosColor.warning.opacity(0.08))
                )

                Divider()

                // Safety controls
                VStack(alignment: .leading, spacing: PharosSpacing.s) {
                    Toggle(isOn: $fan.clamshellProactiveFan) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.clamshellProactiveFanTitle)
                                .font(.system(size: 12.5, weight: .medium))
                            Text(l10n.clamshellProactiveFanDesc)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                    }
                    .toggleStyle(.switch)

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.clamshellThermalAbortLabel)
                                .font(.system(size: 12.5, weight: .medium))
                            Text(l10n.clamshellThermalAbortDesc(Int(fan.clamshellThermalAbort.rounded())))
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { Int(fan.clamshellThermalAbort.rounded()) },
                            set: { fan.clamshellThermalAbort = Double($0) }
                        )) {
                            ForEach(thermalChoices, id: \.self) { deg in
                                Text("\(deg)°C").tag(deg)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                    }

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.clamshellBatteryFloorLabel)
                                .font(.system(size: 12.5, weight: .medium))
                            Text(l10n.clamshellBatteryFloorDesc(fan.clamshellBatteryFloor))
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                        Spacer()
                        Picker("", selection: $fan.clamshellBatteryFloor) {
                            ForEach(batteryChoices, id: \.self) { pct in
                                Text("\(pct)%").tag(pct)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                    }
                }
            }
        }
        .onAppear {
            fan.viewAppeared()
            fan.refreshState()
        }
        .onDisappear {
            fan.viewDisappeared()
        }
    }

    private func abortMessage(_ abort: ClamshellAbortReason) -> String {
        switch abort {
        case .thermalRunaway(let c):
            return l10n.clamshellAbortThermalMsg(Int(c.rounded()))
        case .lowBattery(let p):
            return l10n.clamshellAbortBatteryMsg(p)
        case .heartbeatTimeout:
            return l10n.clamshellAbortHeartbeatMsg
        }
    }
}
