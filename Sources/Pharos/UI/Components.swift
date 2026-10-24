import SwiftUI
import PharosCore

enum Format {
    static func relativeAge(_ date: Date?, now: Date = Date()) -> String {
        let l10n = L10n.shared
        guard let date else { return "–" }
        let s = Int(now.timeIntervalSince(date))
        if s < 3 { return l10n.justNow }
        if s < 60 { return l10n.agoSeconds(s) }
        return l10n.agoMinutes(s / 60)
    }
}

/// Clickable ":5173" chip; opens http://localhost:port.
struct PortChip: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let port: ListeningPort
    var large = false
    @State private var hovering = false

    var body: some View {
        Button {
            store.openInBrowser(port)
        } label: {
            HStack(spacing: 3) {
                if !port.loopbackOnly {
                    Image(systemName: "globe")
                        .font(.system(size: large ? 10 : 8))
                }
                Text(":\(String(port.port))")
                    .font(.system(size: large ? 12 : 10.5, weight: .medium).monospacedDigit())
            }
            .padding(.horizontal, large ? 7 : 5)
            .padding(.vertical, large ? 3 : 1.5)
            .background(
                Capsule().fill(Color.accentColor.opacity(hovering ? 0.25 : 0.13))
            )
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("\(l10n.openInBrowser) — \(port.loopbackOnly ? l10n.localOnlyHelp : l10n.allInterfacesHelp)")
    }
}

/// Wrapping row of port chips.
struct PortChips: View {
    let ports: [ListeningPort]
    var large = false

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(ports, id: \.self) { PortChip(port: $0, large: large) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: .unspecified)
                x += size.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var y: CGFloat = 0
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                y += current.height + spacing
                current = Row(y: y)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(i)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// Memory share bar relative to the heaviest project.
struct MemoryBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(PharosColor.fill)
                Capsule(style: .continuous)
                    .fill(PharosColor.accent.opacity(0.85))
                    .frame(width: max(3, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 4)
    }
}

/// Menu-row style: full-width hover highlight, subtle press feedback.
struct RowButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PharosFont.body)
            .padding(.horizontal, PharosSpacing.s)
            .padding(.vertical, PharosSpacing.xs + 1)
            .background(
                RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                    .fill(hovering ? PharosColor.fill : .clear)
            )
            .animation(.easeInOut(duration: 0.15), value: hovering)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .onHover { hovering = $0 }
    }
}

/// Small borderless icon button used in project rows.
struct IconButton: View {
    let systemImage: String
    let help: String
    var tint: Color = PharosColor.textSecondary
    var size: CGFloat = 22
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size <= 20 ? 10 : 11, weight: .regular))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                        .fill(hovering ? PharosColor.fill : .clear)
                )
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}
