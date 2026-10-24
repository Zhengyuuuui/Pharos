import AppKit
import SwiftUI

/// Shared design tokens (see DESIGN.md §4). Views must not hardcode colors,
/// corner radii or spacing; add a token here instead.
enum PharosColor {
    /// Hierarchy comes from lightness steps (background → surface → fill), not strokes.
    /// High-contrast values widen both background-to-surface and surface-to-fill separation.
    static let background = dynamic(
        light: 0.945, dark: 0.118,
        lightContrast: 0.915, darkContrast: 0.085
    )
    static let backgroundTop = dynamic(
        light: 0.995, dark: 0.148,
        lightContrast: 1.0, darkContrast: 0.165
    )
    static let backgroundBottom = dynamic(
        light: 0.915, dark: 0.095,
        lightContrast: 0.885, darkContrast: 0.075
    )

    /// Global subtle vertical gradient (top pure white → bottom soft silver-gray).
    static var windowGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    static let surface = dynamic(
        light: 1.0, dark: 0.173,
        lightContrast: 1.0, darkContrast: 0.195
    )
    static let surfaceSecondary = dynamic(
        light: 0.972, dark: 0.145,
        lightContrast: 0.958, darkContrast: 0.140
    )
    static let fill = dynamic(
        light: 0.895, dark: 0.235,
        lightContrast: 0.845, darkContrast: 0.285
    )
    static let fillPressed = dynamic(
        light: 0.84, dark: 0.29,
        lightContrast: 0.78, darkContrast: 0.35
    )

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    static let separator = Color(nsColor: .separatorColor)

    static let accent = Color.accentColor
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red

    private static func dynamic(
        light: CGFloat,
        dark: CGFloat,
        lightContrast: CGFloat,
        darkContrast: CGFloat
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            let val: CGFloat
            if contrast {
                val = isDark ? darkContrast : lightContrast
            } else {
                val = isDark ? dark : light
            }
            return NSColor(white: val, alpha: 1)
        })
    }
}

enum PharosSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let xxxl: CGFloat = 40

    static let page = xl
    static let section = xxl
    static let titleToCard = m
    static let cardPadding = l
    static let row = m
}

enum PharosRadius {
    static let small: CGFloat = 6
    static let control: CGFloat = 10
    static let card: CGFloat = 14
    static let container: CGFloat = 18
}

enum PharosFont {
    static let pageTitle = Font.system(.title2, weight: .bold)
    static let sectionTitle = Font.system(.headline, weight: .semibold)
    static let metricValue = Font.system(.title, weight: .semibold).monospacedDigit()
    static let rowLabel = Font.system(.body, weight: .medium)
    static let body = Font.system(.body)
    static let caption = Font.system(.caption)
    static let captionDigits = Font.system(.caption).monospacedDigit()
    static let technical = Font.system(.caption, design: .monospaced)
}

enum PharosShadow {
    static let color = Color.black.opacity(0.05)
    static let radius: CGFloat = 6
    static let y: CGFloat = 1
}
