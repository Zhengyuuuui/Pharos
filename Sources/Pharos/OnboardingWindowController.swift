import AppKit
import SwiftUI
import PharosCore

/// Fixed 720×520 onboarding window. Closing (finish, skip or the red button) tears down the
/// hosting controller so no view tree, layer or IOSurface outlives it.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()
    static let contentSize = NSSize(width: 720, height: 520)

    private var window: NSWindow?
    private var coordinator: OnboardingCoordinator?
    /// Borderless overlay that carries the snapshot during the hand-off; nil at rest.
    private var handoffWindow: NSWindow?
    private(set) var isHandingOff = false

    /// True from `show` until the window is gone, including the hand-off flight.
    var isVisible: Bool { window != nil }

    func show(store: ProjectStore, isReplay: Bool) {
        guard !isHandingOff else { return }
        NSApp.setActivationPolicy(.regular)
        // Only the onboarding window on screen, whether first launch or replay.
        AppDelegate.shared?.dismissMainWindowForOnboarding()
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let start: OnboardingStep = isReplay ? .welcome : OnboardingCoordinator.launchStartStep()
        let coordinator = OnboardingCoordinator(isReplay: isReplay, startStep: start)
        coordinator.onFinish = { [weak self] select in
            self?.finish(select: select)
        }
        self.coordinator = coordinator

        let hosting = NSHostingController(
            rootView: OnboardingView(coordinator: coordinator).environmentObject(store)
        )
        hosting.sizingOptions = []
        let w = OnboardingWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.contentViewController = hosting
        w.setContentSize(Self.contentSize)
        w.title = L10n.shared.onboardingWindowTitle
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = false
        w.isReleasedWhenClosed = false
        w.center()
        w.delegate = self
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func bringToFront() {
        guard !isHandingOff else { return }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// "Enter Pharos" / "Skip": the onboarding card expands in place into the main window (same centre),
    /// its content fading out while the main window's content fades in. The red button closes directly.
    private func finish(select: MainWindowView.SidebarItem?) {
        if let select, select == .batteryAndThermals { WindowRouter.shared.batteryThermalTab = .battery }
        guard let onboarding = window, let app = AppDelegate.shared else {
            AppDelegate.shared?.showMainWindow(selecting: select)
            window?.close()
            return
        }
        isHandingOff = true
        onboarding.ignoresMouseEvents = true
        let target = Self.expandedFrame(around: onboarding)
        let main = app.prepareMainWindowForReveal(selecting: select, frame: target, below: onboarding)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion || !playExpansion(from: onboarding, to: main) {
            crossfade(from: onboarding, to: main)
        }
    }

    // MARK: Hand-off

    static let mainSize = NSSize(width: 1040, height: 700)
    private static let duration: CFTimeInterval = 0.42

    /// 1040×700 centred on the onboarding window, nudged inside the screen's visible area.
    static func expandedFrame(around onboarding: NSWindow) -> NSRect {
        let f = onboarding.frame
        var r = NSRect(x: f.midX - mainSize.width / 2, y: f.midY - mainSize.height / 2,
                       width: mainSize.width, height: mainSize.height)
        if let v = (onboarding.screen ?? NSScreen.main)?.visibleFrame.insetBy(dx: 8, dy: 8) {
            r.origin.x = min(max(r.minX, v.minX), max(v.minX, v.maxX - r.width))
            r.origin.y = min(max(r.minY, v.minY), max(v.minY, v.maxY - r.height))
        }
        return r.integral
    }

    private static func snapshot(_ window: NSWindow) -> CGImage? {
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.cgImage
    }

    /// Returns false when the onboarding snapshot fails; the caller cross-fades instead.
    private func playExpansion(from onboarding: NSWindow, to main: NSWindow) -> Bool {
        guard let onboardingImage = Self.snapshot(onboarding) else { return false }
        // The real main window stays at alpha 0 until the end (it would show outside the growing card),
        // so its content must come from a snapshot; without one, cross-fade instead.
        guard let mainImage = Self.snapshot(main) else { return false }

        let startFrame = onboarding.frame
        let endFrame = main.frame
        let screenFrame = (onboarding.screen ?? NSScreen.main)?.frame ?? startFrame.union(endFrame)
        let overlay = NSWindow(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false)
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.ignoresMouseEvents = true
        overlay.isReleasedWhenClosed = false
        overlay.level = main.level
        let root = NSView(frame: NSRect(origin: .zero, size: screenFrame.size))
        root.wantsLayer = true
        overlay.contentView = root

        func local(_ r: NSRect) -> CGRect {
            CGRect(x: r.minX - screenFrame.minX, y: r.minY - screenFrame.minY, width: r.width, height: r.height)
        }
        let start = local(startFrame), end = local(endFrame)
        let scale = onboarding.backingScaleFactor
        let startRadius: CGFloat = 16, endRadius: CGFloat = 12

        // Outer layer carries the shadow; inner container clips content to the rounded card.
        let shadow = CALayer()
        shadow.bounds = CGRect(origin: .zero, size: end.size)
        shadow.position = CGPoint(x: end.midX, y: end.midY)
        shadow.shadowColor = NSColor.black.cgColor
        shadow.shadowOpacity = 0.28
        shadow.shadowRadius = 24
        shadow.shadowOffset = CGSize(width: 0, height: -10)
        shadow.cornerRadius = endRadius
        shadow.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let container = CALayer()
        container.frame = shadow.bounds
        container.cornerRadius = endRadius
        container.cornerCurve = .continuous
        container.masksToBounds = true
        container.backgroundColor = NSColor.windowBackgroundColor.cgColor
        shadow.addSublayer(container)

        // Content layers fill the container and are scaled about its centre.
        func contentLayer(_ image: CGImage?) -> CALayer {
            let l = CALayer()
            l.contents = image
            l.contentsScale = scale
            l.contentsGravity = .center
            l.bounds = container.bounds
            l.position = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
            return l
        }
        let mainLayer = contentLayer(mainImage as CGImage?)
        mainLayer.contentsGravity = .resize
        let guideLayer = contentLayer(onboardingImage)
        // Guide stays at its native size, centred, so the text never stretches while the frame grows.
        guideLayer.bounds = CGRect(origin: .zero, size: start.size)
        container.addSublayer(mainLayer)
        container.addSublayer(guideLayer)
        root.layer?.addSublayer(shadow)

        overlay.order(.above, relativeTo: main.windowNumber)
        onboarding.orderOut(nil)
        handoffWindow = overlay

        let d = Self.duration
        func spring(_ key: String, from: Any, to: Any) -> CASpringAnimation {
            let a = CASpringAnimation(keyPath: key)
            a.mass = 1; a.stiffness = 200; a.damping = 26
            a.fromValue = from; a.toValue = to
            a.beginTime = 0.05
            a.duration = d - 0.05
            a.fillMode = .backwards
            return a
        }
        func timed(_ a: CAAnimation, begin: CFTimeInterval, length: CFTimeInterval) -> CAAnimation {
            a.beginTime = begin; a.duration = length; a.fillMode = .both
            a.timingFunction = CAMediaTimingFunction(name: .easeOut)
            return a
        }
        func basic(_ key: String, _ from: Any, _ to: Any) -> CABasicAnimation {
            let a = CABasicAnimation(keyPath: key); a.fromValue = from; a.toValue = to; return a
        }
        func group(_ anims: [CAAnimation]) -> CAAnimationGroup {
            let g = CAAnimationGroup(); g.animations = anims; g.duration = d; return g
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            self?.completeHandoff(main: main, onboarding: onboarding)
        }

        // Phase 2: frame expands about the shared centre (high-damping spring, no overshoot visible).
        let frameAnims: [CAAnimation] = [
            spring("bounds.size", from: NSValue(size: start.size), to: NSValue(size: end.size)),
            spring("position", from: NSValue(point: CGPoint(x: start.midX, y: start.midY)),
                   to: NSValue(point: CGPoint(x: end.midX, y: end.midY))),
            spring("cornerRadius", from: startRadius, to: endRadius),
        ]
        shadow.add(group(frameAnims), forKey: "expand")
        container.add(group([
            spring("bounds.size", from: NSValue(size: start.size), to: NSValue(size: end.size)),
            spring("position", from: NSValue(point: CGPoint(x: start.width / 2, y: start.height / 2)),
                   to: NSValue(point: CGPoint(x: end.width / 2, y: end.height / 2))),
            spring("cornerRadius", from: startRadius, to: endRadius),
        ]), forKey: "expand")
        // Keep the content layers centred in the growing container.
        let centre = spring("position", from: NSValue(point: CGPoint(x: start.width / 2, y: start.height / 2)),
                            to: NSValue(point: CGPoint(x: end.width / 2, y: end.height / 2)))

        // Phase 1: onboarding content pushes in slightly and fades (0–0.16 s).
        guideLayer.opacity = 0
        guideLayer.add(group([
            centre.copy() as! CAAnimation,
            timed(basic("opacity", 1, 0), begin: 0, length: 0.16),
            timed(basic("transform.scale", 1.0, 1.03), begin: 0, length: 0.16),
        ]), forKey: "out")

        // Phase 3: main content settles in (0.12–0.42 s).
        let mainSpring = CASpringAnimation(keyPath: "transform.scale")
        mainSpring.mass = 1; mainSpring.stiffness = 200; mainSpring.damping = 26
        mainSpring.fromValue = 0.96; mainSpring.toValue = 1.0
        mainSpring.beginTime = 0.12; mainSpring.duration = d - 0.12; mainSpring.fillMode = .backwards
        mainLayer.add(group([centre, mainSpring, timed(basic("opacity", 0, 1), begin: 0.12, length: 0.24)]), forKey: "in")
        CATransaction.commit()

        return true
    }

    /// Reduce Motion (or no snapshot): plain 0.22 s cross-fade, no movement.
    private func crossfade(from onboarding: NSWindow, to main: NSWindow) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            main.animator().alphaValue = 1
            onboarding.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak main, weak onboarding] in
            Task { @MainActor [weak self] in
                guard let self, let main, let onboarding else { return }
                self.completeHandoff(main: main, onboarding: onboarding)
            }
        })
    }

    private func completeHandoff(main: NSWindow, onboarding: NSWindow) {
        // Reveal the real window before dropping the overlay so no frame shows neither.
        main.alphaValue = 1
        main.makeKeyAndOrderFront(nil)
        if let overlay = handoffWindow {
            overlay.orderOut(nil)
            overlay.contentView = nil
            handoffWindow = nil
        }
        NSApp.activate(ignoringOtherApps: true)
        isHandingOff = false
        onboarding.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        closing.delegate = nil
        let mainWindowOpen = NSApp.windows.contains { $0 !== closing && $0.isVisible && $0.canBecomeMain }
        // Red button: a deliberate dismissal, so it is not shown again on next launch (replay from Settings).
        // A pending FDA resume point is kept — that relaunch is macOS's doing, not the user's.
        if let coordinator, !coordinator.isFinished,
           UserDefaults.standard.object(forKey: OnboardingPolicy.resumeStepKey) == nil {
            coordinator.markCompleted()
        }
        coordinator?.onFinish = nil
        coordinator = nil
        DispatchQueue.main.async { [weak self] in
            closing.contentViewController = nil
            self?.window = nil
            if !mainWindowOpen { NSApp.setActivationPolicy(.accessory) }
        }
    }
}

/// Window drag only from the top 44 pt strip so sliders and controls never move the window.
private final class OnboardingWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            let distFromTop = frame.height - event.locationInWindow.y
            let inStrip = distFromTop >= 0 && distFromTop <= 44
            if isMovableByWindowBackground != inStrip { isMovableByWindowBackground = inStrip }
        case .leftMouseUp:
            if isMovableByWindowBackground { isMovableByWindowBackground = false }
        default:
            break
        }
        super.sendEvent(event)
    }
}
