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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    if showsTitle {
                        Text(l10n.thermalTitle).font(.system(size: 20, weight: .bold))
                    } else {
                        Text(l10n.blockDescription(.thermals))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(l10n.thermalStateName(store.thermalState), systemImage: "thermometer.medium")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ThermalStyle.stateColor(store.thermalState))
                    Button(l10n.openEnergySettings) { ThermalStyle.openEnergySettings() }
                        .controlSize(.small)
                }

                if let t = store.thermals {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n.fansTitle).font(.system(size: 13, weight: .semibold))
                        HStack(spacing: 12) {
                            ForEach(t.fans) { FanCard(fan: $0, count: t.fans.count) }
                        }
                    }

                    FanControlCard()

                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n.temperaturesTitle).font(.system(size: 13, weight: .semibold))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(SensorGroup.allCases, id: \.self) { g in
                                if let c = t.groups[g] { TempTile(group: g, celsius: c) }
                            }
                        }
                    }
                } else {
                    Label(l10n.thermalUnavailable, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }

                Text(l10n.thermalReadNotice)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await store.refreshThermals() }
    }
}

private struct FanCard: View {
    @ObservedObject private var l10n = L10n.shared
    let fan: FanReading
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(l10n.fanName(fan.index, of: count), systemImage: "fanblades")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(l10n.fanMode(fan.mode))
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(fan.mode == .manual ? Color.orange.opacity(0.15) : Color.primary.opacity(0.07)))
                    .foregroundStyle(fan.mode == .manual ? .orange : .secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(fan.actualRPM > 0 ? "\(fan.actualRPM)" : "0")
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                Text("rpm").font(.system(size: 11)).foregroundStyle(.secondary)
                if fan.actualRPM == 0 {
                    Text(l10n.fanStopped).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.primary.opacity(0.08))
                    Rectangle().fill(Color.blue).frame(width: geo.size.width * fan.fraction)
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            Text(l10n.fanRange(fan.minRPM, fan.maxRPM)).font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}

private struct TempTile: View {
    @ObservedObject private var l10n = L10n.shared
    let group: SensorGroup
    let celsius: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l10n.sensorGroup(group)).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(ThermalStyle.temp(celsius))
                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                .foregroundStyle(ThermalStyle.color(celsius))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}
