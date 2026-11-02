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

    var isVisible: Bool { window?.isVisible == true }

    func show(store: ProjectStore, isReplay: Bool) {
        NSApp.setActivationPolicy(.regular)
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
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Main window opens first so the Dock icon does not flicker between policies.
    private func finish(select: MainWindowView.SidebarItem?) {
        if let select, select == .batteryAndThermals { WindowRouter.shared.batteryThermalTab = .battery }
        AppDelegate.shared?.showMainWindow(selecting: select)
        window?.close()
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
