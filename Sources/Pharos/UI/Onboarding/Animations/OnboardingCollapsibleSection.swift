import SwiftUI
import PharosCore

/// Reports `full.height * progress` to its parent while always laying the child out at full size,
/// so siblings below follow the edge every frame and wrapped text never reflows mid-collapse.
private struct OnboardingRevealLayout: Layout {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private func fullSize(_ proposal: ProposedViewSize, _ subviews: Subviews) -> CGSize {
        let width = proposal.width
        let h = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }.max() ?? 0
        let w = width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        return CGSize(width: w, height: h)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let full = fullSize(proposal, subviews)
        return CGSize(width: full.width, height: full.height * min(max(progress, 0), 1))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let full = fullSize(ProposedViewSize(width: bounds.width, height: nil), subviews)
        for subview in subviews {
            subview.place(at: bounds.origin, anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: full.height))
        }
    }
}

/// Animatable so opacity / scale / sin-shaped blur are re-evaluated per frame from the interpolated
/// progress (plain modifiers would only interpolate between endpoint values, and blur would stay 0).
private struct OnboardingCollapseModifier: ViewModifier, Animatable {
    var progress: Double
    let level: OnboardingMotionLevel

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let v = OnboardingCollapseGeometry.values(progress: progress, level: level)
        OnboardingRevealLayout(progress: v.heightFraction) {
            content
                .opacity(v.opacity)
                .scaleEffect(x: 1, y: v.scaleY, anchor: .top)
                .blur(radius: v.blur)
        }
        .clipped()
    }
}

/// Height-clipped collapsible container. The content stays mounted (no `if`), so there is no
/// insertion/removal jump; put any leading spacing inside `content` so it collapses to 0 too.
struct OnboardingCollapsibleSection<Content: View>: View {
    let isExpanded: Bool
    let level: OnboardingMotionLevel
    @ViewBuilder let content: Content

    var body: some View {
        content
            .modifier(OnboardingCollapseModifier(progress: isExpanded ? 1 : 0, level: level))
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
    }
}
