import SwiftUI
import PharosCore

/// Thermal page card: install the helper, then pick macOS / fixed RPM / max.
struct FanControlCard: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var fan = FanStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var armedUninstall = false

    private enum Mode: Hashable { case system, fixed, max }

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
                        Text(l10n.fanModeFixed).tag(Mode.fixed)
                        Text(l10n.fanModeMax).tag(Mode.max)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(fan.busy)

                    if mode == .fixed {
                        HStack(spacing: PharosSpacing.s) {
                            Slider(value: Binding(get: { Double(fan.fixedRPM) }, set: { fan.fixedRPM = Int($0 / 100) * 100 }),
                                   in: Double(minRPM)...Double(maxRPM))
                            Text("\(fan.fixedRPM) rpm").font(PharosFont.captionDigits)
                                .frame(width: 80, alignment: .trailing)
                            Button(l10n.fanApply) { fan.apply(.fixed(rpm: fan.fixedRPM)) }
                                .buttonStyle(.pharosPrimary)
                                .controlSize(.small)
                                .disabled(fan.busy || fan.request == .fixed(rpm: fan.fixedRPM))
                        }
                        .onAppear { fan.fixedRPM = min(max(fan.fixedRPM, minRPM), maxRPM) }
                    }
                    if fan.overheating {
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
        .onAppear { fan.refreshState() }
    }

    private var mode: Mode {
        switch fan.request {
        case .system: return .system
        case .fixed: return .fixed
        case .max: return .max
        }
    }

    private func set(_ m: Mode) {
        switch m {
        case .system: fan.apply(.system)
        case .max: fan.apply(.max)
        case .fixed: fan.apply(.fixed(rpm: fan.fixedRPM))
        }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await store.refreshThermals()
        }
    }

    @ViewBuilder
    private var uninstallButton: some View {
        if armedUninstall {
            Button(l10n.fanUninstall) { armedUninstall = false; fan.uninstall() }
                .buttonStyle(.pharosDestructive).controlSize(.small)
            IconButton(systemImage: "xmark", help: l10n.cancel) { armedUninstall = false }
        } else {
            Button(l10n.fanUninstall) { armedUninstall = true }
                .buttonStyle(.pharos)
                .controlSize(.small)
        }
    }
}

/// One-line status in the popover when Pharos is holding the fans.
struct FanControlStatusLine: View {
    @ObservedObject private var fan = FanStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if fan.helper == .ready, fan.request != .system || fan.overheating {
            HStack(spacing: 6) {
                Image(systemName: fan.overheating ? "flame.fill" : "fanblades.fill")
                    .foregroundStyle(fan.overheating ? .red : .orange)
                Text(fan.overheating ? l10n.fanOverheat : label)
                    .font(.system(size: 10))
                    .lineLimit(2)
                Spacer()
                if !fan.overheating {
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
        case .max: return "\(l10n.fanHeld) · \(l10n.fanModeMax)"
        case .fixed(let rpm): return "\(l10n.fanHeld) · \(rpm) rpm"
        }
    }
}
