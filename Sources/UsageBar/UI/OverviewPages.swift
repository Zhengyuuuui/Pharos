import SwiftUI
import UsageBarCore

/// Main window: whole-machine memory (Activity Monitor style) + top apps.
struct SystemMemoryView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.systemMemory).font(.system(size: 20, weight: .bold))
                    Spacer()
                    if let s = store.system { PressureBadge(pressure: s.pressure) }
                }

                if let s = store.system {
                    HStack(spacing: 12) {
                        StatCard(title: l10n.memoryUsed,
                                 value: ByteFormat.short(s.used),
                                 detail: "/ \(ByteFormat.short(s.total)) · \(Int((s.usedFraction * 100).rounded()))%",
                                 icon: "memorychip")
                        StatCard(title: l10n.availableMemory,
                                 value: ByteFormat.short(s.available),
                                 detail: "\(l10n.cachedReclaimable) \(ByteFormat.short(s.cachedFiles))",
                                 icon: "checkmark.circle", tint: .green)
                        StatCard(title: l10n.swapUsed,
                                 value: ByteFormat.short(s.swapUsed),
                                 detail: s.swapTotal > 0 ? "/ \(ByteFormat.short(s.swapTotal))" : nil,
                                 icon: "arrow.left.arrow.right")
                        StatCard(title: l10n.devProjects,
                                 value: ByteFormat.short(store.totalMemory),
                                 detail: s.used > 0 ? "\(Int((Double(store.totalMemory) / Double(s.used) * 100).rounded()))% \(l10n.shareOfSystem)" : nil,
                                 icon: "shippingbox")
                    }

                    Section(title: l10n.physicalMemory) {
                        MemoryCompositionBar(stats: s, height: 18)
                    }

                    Section(title: l10n.memoryTrend, trailing: l10n.lastHour) {
                        if store.history.samples.count < 2 {
                            CollectingHint()
                        } else {
                            SystemTrendChart(samples: store.history.samples, total: s.total)
                                .frame(height: 170)
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(30)
                }

                Section(title: l10n.topApps) {
                    TopAppsChart(apps: Array(store.apps.prefix(12)))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Main window: all dev ports at a glance + dev memory charts.
struct PortsOverviewView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    var onSelect: (Project) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(l10n.portsOverview).font(.system(size: 20, weight: .bold))

                HStack(spacing: 12) {
                    StatCard(title: l10n.projects, value: "\(store.projects.count)", icon: "shippingbox")
                    StatCard(title: l10n.ports, value: "\(store.totalPorts)", icon: "point.3.connected.trianglepath.dotted")
                    StatCard(title: l10n.exposed, value: "\(store.exposedPorts)",
                             icon: "globe", tint: store.exposedPorts > 0 ? .orange : .secondary)
                        .help(l10n.exposedHint)
                    StatCard(title: l10n.memory, value: ByteFormat.short(store.totalMemory), icon: "memorychip")
                }

                if store.projects.isEmpty {
                    ContentUnavailableView(l10n.noProjects, systemImage: "network.slash",
                                           description: Text(l10n.noProjectsDesc))
                        .frame(height: 200)
                } else {
                    Section(title: l10n.portMap) {
                        PortMapChart(projects: store.projects)
                        HStack(spacing: 14) {
                            Label(l10n.localOnly, systemImage: "circle.fill")
                            Label(l10n.allInterfaces, systemImage: "diamond.fill")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top, spacing: 16) {
                        Section(title: l10n.memoryByProject) {
                            ProjectMemoryBars(projects: store.projects)
                        }
                        Section(title: l10n.devMemoryTrend, trailing: l10n.lastHour) {
                            if store.history.samples.count < 2 {
                                CollectingHint()
                            } else {
                                DevTrendChart(history: store.history)
                                    .frame(height: max(160, CGFloat(store.projects.count) * 24))
                            }
                        }
                    }

                    Section(title: l10n.projects) {
                        portTable
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var portTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.projects.enumerated()), id: \.element.id) { index, p in
                HStack(spacing: 10) {
                    Button { onSelect(p) } label: {
                        Text(p.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 150, alignment: .leading)
                    PortChips(ports: p.ports)
                    Spacer(minLength: 8)
                    Text(p.listeners.first?.shortCommand ?? "")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: 200, alignment: .trailing)
                    Text(ByteFormat.short(p.memoryBytes))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .frame(width: 52, alignment: .trailing)
                    StopButton(project: p, compact: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(index.isMultiple(of: 2) ? Color.primary.opacity(0.03) : .clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08)))
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
