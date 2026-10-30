import SwiftUI
import PharosCore

/// Main window: whole-machine memory (Activity Monitor style) + top apps.
struct SystemMemoryView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    private let metricColumns = [GridItem(.adaptive(minimum: 150), spacing: PharosSpacing.l, alignment: .top)]

    var body: some View {
        PharosPage {
            HStack(alignment: .center) {
                Text(l10n.systemMemory).font(PharosFont.pageTitle)
                Spacer()
                if let s = store.system {
                    PharosStatusIndicator(level: Self.level(s.pressure),
                                          text: "\(l10n.pressure): \(l10n.pressureLabel(s.pressure))")
                }
            }
        } content: {
            if let s = store.system {
                PharosSection(title: l10n.overview, systemImage: "gauge.with.dots.needle.33percent") {
                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: PharosSpacing.l) {
                        PharosMetricValue(title: l10n.memoryUsed,
                                          value: ByteFormat.short(s.used),
                                          detail: "/ \(ByteFormat.short(s.total)) · \(Int((s.usedFraction * 100).rounded()))%",
                                          systemImage: "memorychip")
                        PharosMetricValue(title: l10n.availableMemory,
                                          value: ByteFormat.short(s.available),
                                          detail: "\(l10n.cachedReclaimable) \(ByteFormat.short(s.cachedFiles))",
                                          systemImage: "checkmark.circle")
                        PharosMetricValue(title: l10n.swapUsed,
                                          value: ByteFormat.short(s.swapUsed),
                                          detail: s.swapTotal > 0 ? "/ \(ByteFormat.short(s.swapTotal))" : nil,
                                          systemImage: "arrow.left.arrow.right")
                        PharosMetricValue(title: l10n.devProjects,
                                          value: ByteFormat.short(store.totalMemory),
                                          detail: s.used > 0 ? "\(Int((Double(store.totalMemory) / Double(s.used) * 100).rounded()))% \(l10n.shareOfSystem)" : nil,
                                          systemImage: "shippingbox")
                    }
                }

                PharosSection(title: l10n.physicalMemory, systemImage: "memorychip") {
                    MemoryCompositionBar(stats: s, height: 16)
                }

                PharosSection(title: l10n.memoryTrend, systemImage: "chart.xyaxis.line") {
                    Text(l10n.lastHour)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textTertiary)
                } content: {
                    if store.history.samples.count < 2 {
                        CollectingHint()
                    } else {
                        SystemTrendChart(samples: store.history.samples, total: s.total)
                            .frame(height: 170)
                    }
                }
            } else {
                PharosCard {
                    ProgressView().frame(maxWidth: .infinity).padding(PharosSpacing.xxl)
                }
            }

            PharosSection(title: l10n.topApps, systemImage: "square.stack.3d.up") {
                TopAppsChart(apps: Array(store.apps.prefix(12)))
            }

            MemoryBloatSectionView()
        }
    }

    private static func level(_ p: MemoryPressure) -> PharosStatusIndicator.Level {
        switch p {
        case .normal: return .normal
        case .warning: return .warning
        case .critical: return .critical
        }
    }
}

/// Main window: all dev ports at a glance + dev memory charts.
struct PortsOverviewView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    var onSelect: (Project) -> Void = { _ in }
    var onSelectFavorite: (Favorite) -> Void = { _ in }

    private let metricColumns = [GridItem(.adaptive(minimum: 150), spacing: PharosSpacing.l, alignment: .top)]

    var body: some View {
        PharosPage {
            PharosPageHeader(title: l10n.portsOverview)
        } content: {
            FavoritesTable(onSelect: onSelectFavorite)

            PharosSection(title: l10n.overview, systemImage: "gauge.with.dots.needle.33percent") {
                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: PharosSpacing.l) {
                    PharosMetricValue(title: l10n.projects,
                                      value: "\(store.projects.count)",
                                      systemImage: "shippingbox")
                    PharosMetricValue(title: l10n.ports,
                                      value: "\(store.totalPorts)",
                                      systemImage: "point.3.connected.trianglepath.dotted")
                    PharosMetricValue(title: l10n.exposed,
                                      value: "\(store.exposedPorts)",
                                      detail: store.exposedPorts > 0 ? l10n.exposedHint : nil,
                                      systemImage: "globe")
                    PharosMetricValue(title: l10n.memory,
                                      value: ByteFormat.short(store.totalMemory),
                                      systemImage: "memorychip")
                }
            }

            if store.projects.isEmpty {
                PharosCard {
                    PharosEmptyState(
                        title: l10n.noProjects,
                        systemImage: "network.slash",
                        message: l10n.noProjectsDesc
                    )
                }
            } else {
                PharosSection(title: l10n.portMap, systemImage: "point.3.connected.trianglepath.dotted") {
                    VStack(alignment: .leading, spacing: PharosSpacing.m) {
                        PortMapChart(projects: store.projects)
                        HStack(spacing: PharosSpacing.m) {
                            Label(l10n.localOnly, systemImage: "circle.fill")
                            Label(l10n.allInterfaces, systemImage: "diamond.fill")
                        }
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                    }
                }

                HStack(alignment: .top, spacing: PharosSpacing.l) {
                    PharosSection(title: l10n.memoryByProject, systemImage: "chart.bar") {
                        ProjectMemoryBars(projects: store.projects)
                    }
                    PharosSection(title: l10n.devMemoryTrend, systemImage: "chart.xyaxis.line") {
                        Text(l10n.lastHour)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textTertiary)
                    } content: {
                        if store.history.samples.count < 2 {
                            CollectingHint()
                        } else {
                            DevTrendChart(history: store.history)
                                .frame(height: max(160, CGFloat(store.projects.count) * 24))
                        }
                    }
                }

                PharosSection(title: l10n.runningProjects, systemImage: "shippingbox") {
                    portTable
                }
            }
        }
    }

    private var portTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.projects.enumerated()), id: \.element.id) { index, p in
                if index > 0 {
                    PharosListDivider()
                }
                HStack(spacing: PharosSpacing.s) {
                    Button { onSelect(p) } label: {
                        Text(p.name)
                            .font(PharosFont.rowLabel)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 150, alignment: .leading)
                    PortChips(ports: p.ports)
                    Spacer(minLength: PharosSpacing.s)
                    Text(p.startCommand)
                        .font(PharosFont.technical)
                        .foregroundStyle(PharosColor.textTertiary)
                        .lineLimit(1)
                        .frame(maxWidth: 240, alignment: .trailing)
                        .help(p.startCommand)
                    Text(ByteFormat.short(p.memoryBytes))
                        .font(PharosFont.captionDigits)
                        .frame(width: 52, alignment: .trailing)
                    PinButton(project: p)
                    StopButton(project: p, compact: true)
                }
                .padding(.horizontal, PharosSpacing.xs)
                .padding(.vertical, PharosSpacing.s)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var detail: String? = nil
    let icon: String
    var tint: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 11))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 22, weight: .semibold).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.25), value: value)
            if let detail {
                Text(detail)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}

private struct Section<Content: View>: View {
    let title: String
    var trailing: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                if let trailing {
                    Text(trailing).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct CollectingHint: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text(l10n.collectingHistory)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }
}

// MARK: - Memory Bloated Daemons & Diagnostics Section

struct MemoryBloatSectionView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @State private var showConfirmAll = false
    @State private var targetDaemonToReclaim: KnownBloatedDaemon? = nil
    @State private var showAllMonitored = false
    @State private var isOperating = false

    var body: some View {
        let diagnosis = store.memoryDiagnosis
        let displayItems: [DaemonDiagnosisItem] = {
            if showAllMonitored {
                return diagnosis.items
            } else if diagnosis.hasBloat {
                return diagnosis.bloatedItems
            } else {
                return diagnosis.runningItems
            }
        }()

        PharosSection(
            title: l10n.memoryBloatDiagnostics,
            systemImage: "cross.vial.fill"
        ) {
            HStack(spacing: PharosSpacing.s) {
                if diagnosis.hasBloat {
                    Button {
                        showConfirmAll = true
                    } label: {
                        Label(l10n.reclaimAllBloated, systemImage: "sparkles")
                    }
                    .buttonStyle(.pharosPrimary)
                    .controlSize(.small)
                    .disabled(isOperating)
                }

                Button {
                    Task {
                        isOperating = true
                        await store.refresh()
                        isOperating = false
                    }
                } label: {
                    Label(l10n.redetectDaemons, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.pharos)
                .controlSize(.small)
                .disabled(isOperating)
            }
        } content: {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                // Banner
                if diagnosis.hasBloat {
                    HStack(spacing: PharosSpacing.m) {
                        Image(systemName: diagnosis.criticalCount > 0 ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(diagnosis.criticalCount > 0 ? PharosColor.error : PharosColor.warning)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.reclaimableMemoryBanner(ByteFormat.short(diagnosis.reclaimableBytes)))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PharosColor.textPrimary)
                            Text(l10n.memoryBloatDiagnosticsDesc)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(PharosSpacing.s + 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill((diagnosis.criticalCount > 0 ? PharosColor.error : PharosColor.warning).opacity(0.12))
                    )
                } else {
                    HStack(spacing: PharosSpacing.m) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(PharosColor.success)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.allDaemonsHealthy)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PharosColor.textPrimary)
                            Text(l10n.allDaemonsHealthyDesc)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(PharosSpacing.s + 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(PharosColor.success.opacity(0.1))
                    )
                }

                // Daemon list
                if !displayItems.isEmpty {
                    VStack(spacing: PharosSpacing.xs) {
                        ForEach(displayItems) { item in
                            DaemonRowView(item: item, isOperating: isOperating) {
                                targetDaemonToReclaim = item.daemon
                            } onToggleAutostart: {
                                Task {
                                    isOperating = true
                                    await store.toggleDaemonAutostart(item.daemon)
                                    isOperating = false
                                }
                            }
                            if item.id != displayItems.last?.id {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                }

                // Expand / Collapse toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllMonitored.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAllMonitored ? l10n.hideMonitoredDaemons : l10n.viewAllMonitoredDaemons(diagnosis.items.count))
                        Image(systemName: showAllMonitored ? "chevron.up" : "chevron.down")
                    }
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .alert(l10n.confirmReclaimAllTitle, isPresented: $showConfirmAll) {
            Button(l10n.cancel, role: .cancel) {}
            Button(l10n.confirmReclaimButton, role: .destructive) {
                Task {
                    isOperating = true
                    await store.reclaimAllBloatedDaemons()
                    isOperating = false
                }
            }
        } message: {
            Text(l10n.confirmReclaimDesc)
        }
        .alert(l10n.confirmReclaimTitle, isPresented: Binding(
            get: { targetDaemonToReclaim != nil },
            set: { if !$0 { targetDaemonToReclaim = nil } }
        )) {
            Button(l10n.cancel, role: .cancel) {}
            Button(l10n.confirmReclaimButton, role: .destructive) {
                if let d = targetDaemonToReclaim {
                    Task {
                        isOperating = true
                        await store.reclaimBloatedDaemon(d)
                        isOperating = false
                    }
                }
            }
        } message: {
            Text(l10n.confirmReclaimDesc)
        }
    }
}

private struct DaemonRowView: View {
    let item: DaemonDiagnosisItem
    let isOperating: Bool
    let onReclaim: () -> Void
    let onToggleAutostart: () -> Void

    @ObservedObject private var l10n = L10n.shared

    private var statusColor: Color {
        switch item.status {
        case .healthy: return PharosColor.success
        case .bloated: return PharosColor.warning
        case .critical: return PharosColor.error
        }
    }

    private var statusIcon: String {
        switch item.status {
        case .healthy: return "checkmark.circle.fill"
        case .bloated: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: PharosSpacing.m) {
            // Status Icon
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.system(size: 13))
                .padding(.top, 2)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: PharosSpacing.xs + 2) {
                    Text(item.daemon.primaryName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PharosColor.textPrimary)

                    Text(l10n.daemonCategory(item.daemon.category))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PharosColor.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(PharosColor.fill))

                    if item.isRunning {
                        Text(item.processCount > 1 ? "\(item.processCount) proc" : "PID \(item.pids.first ?? 0)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(PharosColor.textTertiary)
                    }

                    if item.isLaunchdDisabled {
                        Text(l10n.autostartDisabled)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PharosColor.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().stroke(PharosColor.textTertiary.opacity(0.3), lineWidth: 1))
                    }
                }

                Text(l10n.daemonDescription(item.daemon))
                    .font(.system(size: 11))
                    .foregroundStyle(PharosColor.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(l10n.monitoredThreshold(ByteFormat.short(item.daemon.thresholdBytes)))
                        .font(.system(size: 10))
                        .foregroundStyle(PharosColor.textTertiary)
                    if item.status != .healthy {
                        Text("· \(l10n.daemonStatus(item.status))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(statusColor)
                    }
                }
            }

            Spacer(minLength: PharosSpacing.s)

            // Right side: Memory badge & actions
            VStack(alignment: .trailing, spacing: PharosSpacing.xs) {
                Text(item.isRunning ? ByteFormat.short(item.memoryBytes) : "0 B")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(item.isBloated ? statusColor : PharosColor.textPrimary)

                HStack(spacing: 6) {
                    if item.daemon.supportsLaunchdToggle {
                        Button(action: onToggleAutostart) {
                            Text(item.isLaunchdDisabled ? l10n.autostartDisabled : l10n.disableAutostart)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(item.isLaunchdDisabled ? PharosColor.accent : PharosColor.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(PharosColor.fill))
                        }
                        .buttonStyle(.plain)
                        .disabled(isOperating)
                    }

                    if item.isRunning {
                        Button(action: onReclaim) {
                            Label(l10n.reclaimDaemon, systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(item.isBloated ? .pharosDestructive : .pharos)
                        .controlSize(.mini)
                        .disabled(isOperating)
                    }
                }
            }
        }
        .padding(.vertical, PharosSpacing.xs)
    }
}
