import AppKit
import SwiftUI

/// Shared design tokens (see DESIGN.md §4). Views must not hardcode colors,
/// corner radii or spacing; add a token here instead.
enum PharosColor {
    /// Hierarchy comes from lightness steps (background → surface → fill), not strokes.
    static let background = dynamic(light: 0.945, dark: 0.118)
    static let surface = dynamic(light: 1.0, dark: 0.173)
    static let surfaceSecondary = dynamic(light: 0.972, dark: 0.145)
    static let fill = dynamic(light: 0.895, dark: 0.235)
    static let fillPressed = dynamic(light: 0.84, dark: 0.29)

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    static let separator = Color(nsColor: .separatorColor)

    static let accent = Color.accentColor
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red

    private static func dynamic(light: CGFloat, dark: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            let val: CGFloat
            if contrast {
                val = isDark ? max(0.05, dark - 0.04) : min(1.0, light + 0.03)
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
    static let pageTitle = Font.system(size: 20, weight: .bold)
    static let sectionTitle = Font.system(size: 14, weight: .semibold)
    static let metricValue = Font.system(size: 24, weight: .semibold).monospacedDigit()
    static let rowLabel = Font.system(size: 13, weight: .medium)
    static let body = Font.system(size: 13)
    static let caption = Font.system(size: 11.5)
    static let captionDigits = Font.system(size: 11.5).monospacedDigit()
    static let technical = Font.system(size: 11.5, design: .monospaced)
}

enum PharosShadow {
    static let color = Color.black.opacity(0.05)
    static let radius: CGFloat = 6
    static let y: CGFloat = 1
}
