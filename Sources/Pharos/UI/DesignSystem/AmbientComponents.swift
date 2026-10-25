import SwiftUI
import PharosCore

/// Status dot for ambient inspector (6pt diameter with subtle glow).
struct PharosStatusDot: View {
    enum Level {
        case normal
        case info
        case warning
        case critical
        case offline

        var color: Color {
            switch self {
            case .normal: return PharosColor.success
            case .info: return PharosColor.accent
            case .warning: return PharosColor.warning
            case .critical: return PharosColor.error
            case .offline: return PharosColor.textTertiary
            }
        }
    }

    let level: Level
    var animated: Bool = false
    @State private var isPulsing: Bool = false

    var body: some View {
        Circle()
            .fill(level.color)
            .frame(width: 6, height: 6)
            .shadow(color: level.color.opacity(level == .offline ? 0 : 0.45), radius: 2.5, x: 0, y: 0)
            .scaleEffect(animated && isPulsing ? 1.25 : 1.0)
            .opacity(animated && isPulsing ? 0.8 : 1.0)
            .onAppear {
                if animated && level == .warning {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
    }
}

/// Compact action pill (height 24pt, corner radius 12pt, subtle fill, micro icon + 11pt text).
struct PharosActionPill: View {
    let title: String
    let systemImage: String
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @State private var isCopiedFeedback = false

    var body: some View {
        Button {
            action()
            if systemImage.contains("doc.on.doc") || systemImage.contains("clipboard") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCopiedFeedback = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCopiedFeedback = false
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isCopiedFeedback ? "checkmark" : systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isCopiedFeedback ? PharosColor.success : (isPrimary ? PharosColor.accent : PharosColor.textSecondary))

                Text(isCopiedFeedback ? (L10n.shared.isZh ? "已复制" : "Copied") : title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isCopiedFeedback ? PharosColor.success : PharosColor.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(
                Capsule(style: .continuous)
                    .fill(isPrimary
                          ? PharosColor.accent.opacity(isHovered ? 0.2 : 0.12)
                          : (isHovered ? PharosColor.fill.opacity(0.8) : PharosColor.fill.opacity(0.45)))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isPrimary
                            ? PharosColor.accent.opacity(0.35)
                            : PharosColor.separator.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// Micro metric with label and monospaced value on a single row.
struct PharosMicroMetric: View {
    let label: String
    let value: String
    var unit: String? = nil
    var dotLevel: PharosStatusDot.Level? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let dotLevel {
                PharosStatusDot(level: dotLevel)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(PharosColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PharosColor.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(PharosColor.textTertiary)
                }
            }
            .lineLimit(1)
        }
    }
}

/// 1:1 Twin Tile for Bento Grid (macOS Control Center style, width 126pt, height 68pt).
struct PharosBentoTile: View {
    let title: String
    let value: String
    let subtitle: String
    var systemImage: String? = nil
    var dotLevel: PharosStatusDot.Level? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if let dotLevel {
                    PharosStatusDot(level: dotLevel)
                }
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(PharosColor.textSecondary)
                }
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(PharosColor.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 16.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(PharosColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(subtitle)
                .font(.system(size: 9.5))
                .foregroundStyle(PharosColor.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(width: 126, height: 68, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PharosColor.surface)
                .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PharosColor.separator.opacity(0.3), lineWidth: 0.5)
        )
    }
}

/// Row container for two 126pt twin tiles (8pt gap, total width 260pt).
struct InspectorTwinTilesRow<TileA: View, TileB: View>: View {
    let tileA: TileA
    let tileB: TileB

    init(@ViewBuilder a: () -> TileA, @ViewBuilder b: () -> TileB) {
        self.tileA = a()
        self.tileB = b()
    }

    var body: some View {
        HStack(spacing: 8) {
            tileA
            tileB
        }
        .frame(width: 260)
    }
}

/// Mini Bento Pulse capsule card (height 44~52pt, width 260pt).
struct PharosBentoPulse: View {
    let text: String
    var dotLevel: PharosStatusDot.Level = .normal

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            PharosStatusDot(level: dotLevel, animated: dotLevel == .warning)
                .padding(.top, 4)

            Text(text)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(PharosColor.textPrimary)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PharosColor.surface)
                .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PharosColor.separator.opacity(0.3), lineWidth: 0.5)
        )
    }
}

/// Full-width Bento modular card (width 260pt, 14pt squircle, dual shadows).
struct PharosBentoCard<Content: View>: View {
    let title: String
    var systemImage: String? = nil
    var trailingBadge: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PharosColor.textTertiary)
                        .frame(width: 14, alignment: .center)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PharosColor.textSecondary)
                Spacer()
                if let trailingBadge {
                    Text(trailingBadge)
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(PharosColor.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(PharosColor.fill.opacity(0.6)))
                }
            }

            content
        }
        .padding(11)
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PharosColor.surface)
                .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PharosColor.separator.opacity(0.3), lineWidth: 0.5)
        )
    }
}

typealias PharosInspectorPulse = PharosBentoPulse
typealias PharosInspectorCard = PharosBentoCard

