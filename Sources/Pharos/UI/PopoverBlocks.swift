import SwiftUI
import PharosCore

/// One popover section. The real popover and the Customize preview render the
/// same view, so the preview is an exact snapshot.
struct PopoverBlockView: View {
    @EnvironmentObject var store: ProjectStore
    let block: PopoverBlock

    var body: some View {
        switch block {
        case .memory: MemoryBlock()
        case .disk: if !store.volumes.isEmpty { PopoverDiskSection() } else { BlockPlaceholder(block: block) }
        case .thermals: if store.thermals != nil { PopoverThermalSection() } else { BlockPlaceholder(block: block) }
        case .devProjects: DevProjectsBlock()
        case .topApps: TopAppsBlock()
        case .projects: ProjectListBlock()
        case .browsers: BrowsersBlock()
        case .favorites: FavoritesBlock()
        case .battery: PopoverBatteryBlock()
        }
    }
}

/// The blocks of one tab, separated like the original popover.
struct PopoverBlockStack: View {
    let blocks: [PopoverBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.element) { index, block in
                if index > 0 { Divider() }
                PopoverBlockView(block: block)
            }
        }
    }
}

extension PopoverBlock {
    var icon: String {
        switch self {
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .thermals: return "fanblades"
        case .devProjects: return "chart.bar"
        case .topApps: return "square.stack.3d.up"
        case .projects: return "shippingbox"
        case .browsers: return "globe"
        case .favorites: return "star"
        case .battery: return "battery.100.bolt"
        }
    }
}

/// Shown when a block has no data on this Mac (e.g. no SMC), so it isn't invisible.
private struct BlockPlaceholder: View {
    @ObservedObject private var l10n = L10n.shared
    let block: PopoverBlock

    var body: some View {
        Label(l10n.blockName(block), systemImage: block.icon)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
    }
}

private struct MemoryBlock: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if let s = store.system {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.systemMemory).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(ByteFormat.short(s.used)) / \(ByteFormat.short(s.total))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                    Text("· \(l10n.availableMemory) \(ByteFormat.short(s.available))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.green)
                }
                MemoryCompositionBar(stats: s, height: 10, showLegend: false)
                HStack {
                    PressureBadge(pressure: s.pressure)
                    Spacer()
                    Text("\(l10n.swapUsed) \(ByteFormat.short(s.swapUsed))")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if store.history.samples.count >= 2 {
                    SystemTrendChart(samples: store.history.samples, total: s.total, compact: true)
                        .frame(height: 70)
                }
            }
        } else {
            BlockPlaceholder(block: .memory)
        }
    }
}

private struct DevProjectsBlock: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.devProjects).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(store.totalPorts) \(l10n.ports) · \(ByteFormat.short(store.totalMemory))")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
            }
            if store.history.samples.count >= 2 && !store.projects.isEmpty {
                DevTrendChart(history: store.history, limit: 5, compact: true)
                    .frame(height: 80)
            }
            if !store.projects.isEmpty {
                ProjectMemoryBars(projects: Array(store.projects.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(5)))
            }
        }
    }
}

private struct TopAppsBlock: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l10n.topApps).font(.system(size: 12, weight: .semibold))
            ForEach(store.apps.prefix(5)) { app in
                HStack {
                    Text(app.name).font(.system(size: 11)).lineLimit(1)
                    Spacer()
                    Text(ByteFormat.short(app.memoryBytes))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ProjectListBlock: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @State private var rowHeights: [Int: CGFloat] = [:]

    var body: some View {
        let maxMem = store.projects.map(\.memoryBytes).max() ?? 1
        let limit = layoutStore.layout.visibleProjectRows
        if store.projects.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "network.slash").font(.system(size: 20)).foregroundStyle(.tertiary)
                Text(l10n.noProjects).font(.system(size: 12, weight: .medium))
                Text(l10n.noProjectsDesc).font(.system(size: 10)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        } else {
            let rows = VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(store.projects.enumerated()), id: \.element.id) { index, project in
                    PopoverProjectRow(project: project, fraction: Double(project.memoryBytes) / Double(max(1, maxMem)))
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: RowHeightsKey.self, value: [index: geo.size.height])
                        })
                }
            }
            .onPreferenceChange(RowHeightsKey.self) { rowHeights = $0 }

            if limit > 0, store.projects.count > limit {
                ScrollView { rows }
                    // Exactly `limit` rows tall (rows differ in height: port chips wrap).
                    .frame(height: visibleHeight(limit))
            } else {
                rows
            }
        }
    }

    private func visibleHeight(_ limit: Int) -> CGFloat {
        let measured = (0..<limit).compactMap { rowHeights[$0] }
        let fallback: CGFloat = 58
        let total = measured.reduce(0, +) + CGFloat(limit - measured.count) * fallback
        return total + CGFloat(max(0, limit - 1)) * 2
    }
}

private struct RowHeightsKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct BrowsersBlock: View {
    @EnvironmentObject var store: ProjectStore

    var body: some View {
        let entries = ChromeStore.shared.entries(store.chrome)
        if entries.isEmpty {
            BlockPlaceholder(block: .browsers)
        } else {
            PopoverChromeSection(entries: entries)
        }
    }
}

/// Saved workspaces with run state, and one-click Open in Terminal for stopped ones.
private struct FavoritesBlock: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var workspaces = WorkspaceStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let statuses = workspaces.statuses(store.projects)
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(l10n.favorites).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    AppDelegate.shared?.showMainWindow(selecting: .portsOverview)
                } label: {
                    Text(l10n.manage).font(.system(size: 10))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            if statuses.isEmpty {
                Text(l10n.favoritesEmptyShort).font(.system(size: 10)).foregroundStyle(.tertiary).padding(.horizontal, 8)
            }
            ForEach(statuses, id: \.favorite.id) { s in
                HStack(spacing: 6) {
                    RunDot(running: s.isRunning)
                    Text(s.favorite.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(s.isRunning ? s.ports.prefix(2).map { ":\($0.port)" }.joined(separator: " ")
                                     : s.favorite.lastPorts.prefix(2).map { ":\($0)" }.joined(separator: " "))
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(s.isRunning ? Color.accentColor : .secondary)
                    Spacer(minLength: 4)
                    if s.isRunning {
                        Text(ByteFormat.short(s.memoryBytes)).font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
                    } else if !s.favorite.command.isEmpty {
                        IconButton(systemImage: "play.fill", help: l10n.openInTerminal, tint: .green) {
                            workspaces.openInTerminal(s.favorite)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }
}

/// Battery and charging limit block in popover.
private struct PopoverBatteryBlock: View {
    @ObservedObject private var battery = BatteryStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let r = battery.reading
        let isHolding = battery.isHolding || (!r.isCharging && r.powerSource == .acPower && r.currentPercent < 100)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(l10n.batteryTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    WindowRouter.shared.batteryThermalTab = .battery
                    AppDelegate.shared?.showMainWindow(selecting: .batteryAndThermals)
                } label: {
                    Text(l10n.manage).font(.system(size: 10))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)

            HStack(spacing: 8) {
                if isHolding {
                    Image(systemName: "powerplug.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.teal)
                } else if r.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "battery.75")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("\(r.currentPercent)%")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        if isHolding {
                            Text("(\(battery.targetLimit)%)")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.teal)
                        } else if r.isCharging {
                            Text("→ \(battery.targetLimit)%")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.green)
                        }
                    }
                    Text(isHolding ? l10n.batteryHoldingSubtitle : (r.isCharging ? l10n.batteryChargingTo(battery.targetLimit) : l10n.batteryDischarging))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isHolding {
                    Button(l10n.batteryChargeToFullNow) {
                        battery.chargeToFullNow()
                    }
                    .controlSize(.mini)
                } else if case .full = battery.mode {
                    Button(l10n.batteryResumeLimit) {
                        battery.resumeLimit()
                    }
                    .controlSize(.mini)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

