import Charts
import SwiftUI
import UsageBarCore

enum ChartFormat {
    static func gb(_ bytes: UInt64) -> Double { Double(bytes) / 1_073_741_824 }
    static func mb(_ bytes: UInt64) -> Double { Double(bytes) / 1_048_576 }
}

/// Used (App / Wired / Compressed, solid) vs. Available. Cached files sit inside
/// the available part as a light tint: macOS reclaims them on demand, so
/// drawing them as solid made the machine look nearly full.
struct MemoryCompositionBar: View {
    @ObservedObject private var l10n = L10n.shared
    let stats: SystemMemoryStats
    var height: CGFloat = 14
    var showLegend = true

    private struct Segment: Identifiable {
        let name: String
        let bytes: UInt64
        let color: Color
        var id: String { name }
    }

    static let cachedColor = Color.green.opacity(0.28)
    static let freeColor = Color.green.opacity(0.10)

    private var usedSegments: [Segment] {
        [
            Segment(name: l10n.appMemory, bytes: stats.appMemory, color: .blue),
            Segment(name: l10n.wiredMemory, bytes: stats.wired, color: .orange),
            Segment(name: l10n.compressedMemory, bytes: stats.compressed, color: .purple),
        ]
    }

    private var availableSegments: [Segment] {
        [
            Segment(name: l10n.cachedReclaimable, bytes: stats.cachedFiles, color: Self.cachedColor),
            Segment(name: l10n.freeMemory, bytes: stats.free, color: Self.freeColor),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showLegend {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(l10n.used) \(ByteFormat.short(stats.used))")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    Spacer()
                    Text("\(l10n.availableMemory) \(ByteFormat.short(stats.available))")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.green)
                }
            }

            GeometryReader { geo in
                let total = Double(max(1, stats.total))
                HStack(spacing: 0) {
                    ForEach(usedSegments + availableSegments) { s in
                        Rectangle()
                            .fill(s.color)
                            .frame(width: geo.size.width * Double(s.bytes) / total)
                    }
                    Spacer(minLength: 0)
                }
                .overlay(alignment: .leading) {
                    // Boundary between used and available.
                    Rectangle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 1.5)
                        .offset(x: geo.size.width * Double(stats.used) / total)
                }
            }
            .frame(height: height)
            .background(Self.freeColor)
            .clipShape(RoundedRectangle(cornerRadius: height / 3))

            if showLegend {
                HStack(alignment: .top) {
                    legend(usedSegments)
                    Spacer()
                    legend(availableSegments)
                }
            }
        }
    }

    private func legend(_ segments: [Segment]) -> some View {
        HStack(spacing: 10) {
            ForEach(segments) { s in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(s.color).frame(width: 9, height: 9)
                    Text("\(s.name) \(ByteFormat.short(s.bytes))")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Machine "Memory Used" over time, with total memory as the y ceiling.
struct SystemTrendChart: View {
    @ObservedObject private var l10n = L10n.shared
    let samples: [MemorySample]
    let total: UInt64
    var compact = false

    var body: some View {
        Chart(samples) { s in
            AreaMark(x: .value(l10n.time, s.date),
                     y: .value(l10n.used, ChartFormat.gb(s.systemUsed)))
                .foregroundStyle(.linearGradient(colors: [.blue.opacity(0.35), .blue.opacity(0.05)],
                                                 startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value(l10n.time, s.date),
                     y: .value(l10n.used, ChartFormat.gb(s.systemUsed)))
                .foregroundStyle(.blue)
                .interpolationMethod(.monotone)
        }
        .chartYScale(domain: 0...max(1, ChartFormat.gb(total)))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: compact ? 2 : 4)) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))G") } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: compact ? 3 : 6)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
    }
}

/// Stacked area of dev-project memory over time (top N + Other).
struct DevTrendChart: View {
    @ObservedObject private var l10n = L10n.shared
    let history: MemoryHistory
    var limit = 6
    var compact = false

    var body: some View {
        let (names, points) = history.projectSeries(limit: limit, otherName: l10n.other)
        Chart(points, id: \.self) { p in
            AreaMark(x: .value(l10n.time, p.date),
                     y: .value("MB", ChartFormat.mb(p.bytes)),
                     stacking: .standard)
                .foregroundStyle(by: .value(l10n.project, p.series))
                .interpolationMethod(.monotone)
        }
        .chartForegroundStyleScale(domain: names, range: Palette.colors(names.count))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: compact ? 2 : 4)) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text(Self.mbLabel(d)) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: compact ? 3 : 6)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartLegend(compact ? .hidden : .visible)
    }

    static func mbLabel(_ mb: Double) -> String {
        mb >= 1024 ? String(format: "%.1fG", mb / 1024) : "\(Int(mb))M"
    }
}

/// Horizontal bars: current memory per dev project.
struct ProjectMemoryBars: View {
    @ObservedObject private var l10n = L10n.shared
    let projects: [Project]

    var body: some View {
        let sorted = projects.sorted { $0.memoryBytes > $1.memoryBytes }
        let names = sorted.map(\.name)
        Chart(sorted) { p in
            BarMark(x: .value("MB", ChartFormat.mb(p.memoryBytes)),
                    y: .value(l10n.project, p.name))
                .foregroundStyle(by: .value(l10n.project, p.name))
                .annotation(position: .trailing, spacing: 4) {
                    Text(ByteFormat.short(p.memoryBytes))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
        }
        .chartForegroundStyleScale(domain: names, range: Palette.colors(names.count))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text(DevTrendChart.mbLabel(d)) } }
            }
        }
        .frame(height: max(80, CGFloat(sorted.count) * 24 + 24))
    }
}

/// Horizontal bars: top apps by memory.
struct TopAppsChart: View {
    @ObservedObject private var l10n = L10n.shared
    let apps: [AppUsage]

    var body: some View {
        Chart(apps) { a in
            BarMark(x: .value("MB", ChartFormat.mb(a.memoryBytes)),
                    y: .value(l10n.application, a.name))
                .foregroundStyle(Color.accentColor.gradient)
                .annotation(position: .trailing, spacing: 4) {
                    Text(ByteFormat.short(a.memoryBytes))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text(DevTrendChart.mbLabel(d)) } }
            }
        }
        .frame(height: max(80, CGFloat(apps.count) * 24 + 24))
    }
}

/// Every listening port placed on a log-scaled number line, colored by project.
struct PortMapChart: View {
    @ObservedObject private var l10n = L10n.shared
    let projects: [Project]

    private struct Entry: Identifiable {
        let project: String
        let port: ListeningPort
        var id: String { "\(project):\(port.port)" }
    }

    var body: some View {
        let entries = projects.flatMap { p in p.ports.map { Entry(project: p.name, port: $0) } }
        let names = projects.map(\.name)
        Chart(entries) { e in
            PointMark(x: .value(l10n.port, Double(e.port.port)),
                      y: .value(l10n.project, e.project))
                .foregroundStyle(by: .value(l10n.project, e.project))
                .symbol(e.port.loopbackOnly ? .circle : .diamond)
                .symbolSize(70)
                .annotation(position: .top, spacing: 2) {
                    Text(String(e.port.port))
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
        }
        .chartXScale(domain: 1000...65535, type: .log)
        .chartXAxis {
            AxisMarks(values: [1024, 3000, 5000, 8000, 10000, 20000, 40000, 65535]) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text(String(Int(d))) } }
            }
        }
        .chartForegroundStyleScale(domain: names, range: Palette.colors(names.count))
        .chartLegend(.hidden)
        .frame(height: max(100, CGFloat(projects.count) * 26 + 30))
    }
}

/// Memory-pressure gauge chip (green / yellow / red, like Activity Monitor).
struct PressureBadge: View {
    @ObservedObject private var l10n = L10n.shared
    let pressure: MemoryPressure

    private var color: Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(l10n.pressure): \(l10n.pressureLabel(pressure))")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }
}

enum Palette {
    private static let base: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint, .brown, .cyan, .red, .yellow]

    static func colors(_ n: Int) -> [Color] {
        (0..<max(n, 1)).map { base[$0 % base.count] }
    }
}
