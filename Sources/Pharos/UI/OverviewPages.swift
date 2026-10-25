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
                    Text(p.listeners.first?.shortCommand ?? "")
                        .font(PharosFont.technical)
                        .foregroundStyle(PharosColor.textTertiary)
                        .lineLimit(1)
                        .frame(maxWidth: 200, alignment: .trailing)
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
