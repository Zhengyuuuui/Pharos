import SwiftUI

/// Content container (DESIGN.md §5). Elevation comes from the surface/background
/// lightness step; the hairline is only added where that step is too weak.
struct PharosCard<Content: View>: View {
    var padding: CGFloat = PharosSpacing.cardPadding
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var needsHairline: Bool { scheme == .dark || contrast == .increased }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PharosRadius.card, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(shape.fill(PharosColor.surface))
            .overlay {
                if needsHairline { shape.strokeBorder(PharosColor.separator, lineWidth: 0.5) }
            }
            .shadow(color: needsHairline ? .clear : PharosShadow.color,
                    radius: PharosShadow.radius, y: PharosShadow.y)
    }
}

/// Group title that sits above (outside) its card.
struct PharosSectionHeader<Trailing: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PharosSpacing.s) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PharosColor.textSecondary)
                    .frame(width: 18)
            }
            Text(title).font(PharosFont.sectionTitle)
            Spacer(minLength: PharosSpacing.s)
            trailing
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension PharosSectionHeader where Trailing == EmptyView {
    init(title: String, systemImage: String? = nil) {
        self.init(title: title, systemImage: systemImage) { EmptyView() }
    }
}

/// Header + card, the standard building block of a page.
struct PharosSection<Trailing: View, Content: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder var trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: PharosSpacing.titleToCard) {
            PharosSectionHeader(title: title, systemImage: systemImage) { trailing }
                .padding(.horizontal, PharosSpacing.xs)
            PharosCard { content }
        }
    }
}

extension PharosSection where Trailing == EmptyView {
    init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, systemImage: systemImage, trailing: { EmptyView() }, content: content)
    }
}

/// Primary metric: label, prominent value, secondary detail.
struct PharosMetricValue: View {
    let title: String
    let value: String
    var detail: String? = nil
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: PharosSpacing.xs) {
            HStack(spacing: PharosSpacing.xs) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).lineLimit(1)
            }
            .font(PharosFont.caption)
            .foregroundStyle(PharosColor.textSecondary)

            Text(value)
                .font(PharosFont.metricValue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.25), value: value)

            if let detail {
                Text(detail)
                    .font(PharosFont.captionDigits)
                    .foregroundStyle(PharosColor.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Status is never conveyed by color alone: dot color + symbol + text.
struct PharosStatusIndicator: View {
    enum Level { case normal, warning, critical }

    let level: Level
    let text: String

    private var color: Color {
        switch level {
        case .normal: return PharosColor.success
        case .warning: return PharosColor.warning
        case .critical: return PharosColor.error
        }
    }

    private var symbol: String {
        switch level {
        case .normal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(spacing: PharosSpacing.xs + 1) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).foregroundStyle(PharosColor.textSecondary)
        }
        .font(PharosFont.caption)
        .padding(.horizontal, PharosSpacing.s + 2)
        .padding(.vertical, PharosSpacing.xs)
        .background(Capsule().fill(PharosColor.fill))
        .animation(.easeInOut(duration: 0.2), value: level)
        .accessibilityElement(children: .combine)
    }
}

/// Chart wrapper container (DESIGN.md §5 & §7). Handles title, legend, time range,
/// and unified states: loading / empty / unavailable / error / ready.
struct PharosChartContainer<Content: View, Trailing: View>: View {
    enum State: Equatable {
        case ready
        case loading
        case empty(message: String)
        case unavailable(message: String)
        case error(message: String)
    }

    let title: String
    var systemImage: String? = nil
    var state: State = .ready
    var minHeight: CGFloat = 160
    @ViewBuilder var trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        PharosSection(title: title, systemImage: systemImage) {
            trailing
        } content: {
            Group {
                switch state {
                case .loading:
                    HStack(spacing: PharosSpacing.s) {
                        ProgressView().controlSize(.small)
                        Text(L10n.shared.loading)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: minHeight)
                case .empty(let message):
                    PharosEmptyState(
                        title: title,
                        systemImage: "chart.line.uptrend.xyaxis",
                        message: message
                    )
                    .frame(minHeight: minHeight)
                case .unavailable(let message):
                    PharosEmptyState(
                        title: title,
                        systemImage: "slash.circle",
                        message: message,
                        tint: PharosColor.warning
                    )
                    .frame(minHeight: minHeight)
                case .error(let message):
                    PharosEmptyState(
                        title: title,
                        systemImage: "exclamationmark.triangle",
                        message: message,
                        tint: PharosColor.error
                    )
                    .frame(minHeight: minHeight)
                case .ready:
                    content
                }
            }
        }
    }
}

extension PharosChartContainer where Trailing == EmptyView {
    init(
        title: String,
        systemImage: String? = nil,
        state: State = .ready,
        minHeight: CGFloat = 160,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            state: state,
            minHeight: minHeight,
            trailing: { EmptyView() },
            content: content
        )
    }
}
