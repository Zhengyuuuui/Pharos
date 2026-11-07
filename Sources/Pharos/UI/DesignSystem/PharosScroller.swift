import AppKit
import SwiftUI

// MARK: - Pharos Slim Overlay Scroller

/// An ultra-slim (3.5pt), highly refined custom overlay scroller.
/// Replaces macOS's chunky default vertical scrollers (which can be 15pt+ with dark tracks when
/// an external mouse is connected or System Settings enforces 'Always show scroll bars').
/// Eliminates visual noise while providing an elegant, non-intrusive indicator that gently brightens on hover.
public final class PharosSlimScroller: NSScroller {
    override public class var isCompatibleWithOverlayScrollers: Bool { true }

    override public var scrollerStyle: NSScroller.Style {
        get { .overlay }
        set { super.scrollerStyle = .overlay }
    }

    override public class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        // Return 0 so even if the system queries legacy width, it never reserves a thick gutter
        0
    }

    override public func drawKnob() {
        let knobRect = self.rect(for: .knob)
        guard knobRect.width > 0, knobRect.height > 0 else { return }

        let slimWidth: CGFloat = 3.5
        let rightMargin: CGFloat = 2.0
        let x = bounds.width - slimWidth - rightMargin
        let y = knobRect.origin.y + 2
        let h = max(18, knobRect.height - 4)

        let pillRect = NSRect(x: x, y: y, width: slimWidth, height: h)
        let path = NSBezierPath(roundedRect: pillRect, xRadius: slimWidth / 2, yRadius: slimWidth / 2)

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let isHighlighted = (hitPart != .noPart)
        let alpha: CGFloat = isDark
            ? (isHighlighted ? 0.60 : 0.35)
            : (isHighlighted ? 0.45 : 0.25)

        let color = (isDark ? NSColor.white : NSColor.black).withAlphaComponent(alpha)
        color.setFill()
        path.fill()
    }

    override public func drawKnobSlot(in rect: NSRect, highlight: Bool) {
        // Keep track gutter 100% transparent: zero gray bar noise
    }
}

// MARK: - Attachers for SwiftUI

public struct PharosSlimScrollerAttacher: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> PharosSlimScrollerNSView {
        PharosSlimScrollerNSView()
    }

    public func updateNSView(_ nsView: PharosSlimScrollerNSView, context: Context) {
        nsView.attach()
    }
}

public final class PharosSlimScrollerNSView: NSView {
    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attach()
    }

    override public func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        attach()
    }

    public func attach() {
        guard let sv = enclosingScrollView else { return }
        if !(sv.verticalScroller is PharosSlimScroller) {
            let s = PharosSlimScroller()
            sv.verticalScroller = s
            sv.scrollerStyle = .overlay
            sv.autohidesScrollers = true
        }
    }

    override public func hitTest(_ point: NSPoint) -> NSView? { nil }
}

public struct PharosHiddenScrollerAttacher: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> PharosHiddenScrollerNSView {
        PharosHiddenScrollerNSView()
    }

    public func updateNSView(_ nsView: PharosHiddenScrollerNSView, context: Context) {
        nsView.apply()
    }
}

public final class PharosHiddenScrollerNSView: NSView {
    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    override public func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        apply()
    }

    public func apply() {
        guard let sv = enclosingScrollView else { return }
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.verticalScroller = nil
        sv.horizontalScroller = nil
    }

    override public func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - View Modifiers

extension View {
    /// Replaces bulky default macOS vertical scrollers with an ultra-slim (3.5pt),
    /// non-intrusive overlay pill that eliminates visual noise across the UI.
    public func pharosSlimScroller() -> some View {
        background(PharosSlimScrollerAttacher())
    }

    /// Enforces completely hidden scrollbars on containers intended to be borderless and clean (e.g. sidebar),
    /// preventing macOS "Always show scroll bars" from forcing a thick vertical bar.
    public func pharosHiddenScroller() -> some View {
        background(PharosHiddenScrollerAttacher())
    }
}

// MARK: - Compatibility Aliases

public typealias SlimPopoverScroller = PharosSlimScroller
public typealias SlimScrollerAttacher = PharosSlimScrollerAttacher
