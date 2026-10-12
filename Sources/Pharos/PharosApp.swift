import SwiftUI
import PharosCore

/// Owns the shared ProjectStore and the main NSWindow.
/// The app is LSUIElement (menu-bar agent): it stays in the menu bar by
/// default (`.accessory`) and only shows a Dock icon while the main window
/// is open (`.regular`).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// `NSApp.delegate` is SwiftUI's adaptor wrapper, so `as? AppDelegate`
    /// fails at runtime; views reach the delegate through this instead.
    /// Weak: the @NSApplicationDelegateAdaptor owns the instance.
    private(set) static weak var shared: AppDelegate?

    let store: ProjectStore
    private var window: NSWindow?

    override init() {
        // Before any store reads its settings.
        LegacyDefaults.migrate()
        store = ProjectStore()
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        showMainWindow()
    }

    /// Clicking the Dock / Launchpad icon while running reopens the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { showMainWindow() }
        return true
    }

    func showMainWindow(selecting select: MainWindowView.SidebarItem? = nil) {
        NSApp.setActivationPolicy(.regular)
        if window != nil, let select {
            // Window already exists: switch its page instead of ignoring the request.
            WindowRouter.shared.request = select
        }
        if window == nil {
            let hosting = NSHostingController(
                rootView: MainWindowView(initialSelection: select).environmentObject(store)
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "Pharos"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.setContentSize(NSSize(width: 980, height: 680))
            w.isReleasedWhenClosed = false
            w.center()
            w.delegate = self
            window = w
        }
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Drop the window entirely instead of hiding it: a hidden window keeps its
    /// SwiftUI tree, Charts layers and GPU backing stores (~100 MB) alive.
    /// Rebuilding on reopen is cheap; history lives in the store, not the view.
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        closing.delegate = nil
        DispatchQueue.main.async { [weak self] in
            closing.contentViewController = nil
            self?.window = nil
        }
    }
}

/// Page-switch requests for an already-open main window (from the popover).
@MainActor
final class WindowRouter: ObservableObject {
    static let shared = WindowRouter()
    @Published var request: MainWindowView.SidebarItem?
}

@main
struct PharosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        LegacyDefaults.migrate()
        NSApplication.shared.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--check") {
            let all = CommandLine.arguments.contains("--all")
            let procs = ProcessScanner.scan()
            if let s = SystemMemory.read() {
                print("system\tused \(ByteFormat.short(s.used)) / \(ByteFormat.short(s.total))\tapp \(ByteFormat.short(s.appMemory)) wired \(ByteFormat.short(s.wired)) compressed \(ByteFormat.short(s.compressed)) cached \(ByteFormat.short(s.cachedFiles))\tswap \(ByteFormat.short(s.swapUsed))\tpressure \(s.pressure)")
            }
            for a in AppGrouper.group(procs).prefix(5) {
                print("app\t\(a.name)\t\(ByteFormat.short(a.memoryBytes))\t\(a.processCount) proc")
            }
            for p in ProjectGrouper.group(procs, includeSystem: all) {
                let ports = p.ports.map { ":\($0.port)\($0.loopbackOnly ? "" : "*")" }.joined(separator: " ")
                print("\(p.name)\t\(ports)\t\(ByteFormat.short(p.memoryBytes))\t\(p.processCount) proc\t\(p.directory ?? "-")")
            }
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(appDelegate.store)
        } label: {
            Image(systemName: "point.3.connected.trianglepath.dotted")
        }
        .menuBarExtraStyle(.window)
    }
}
