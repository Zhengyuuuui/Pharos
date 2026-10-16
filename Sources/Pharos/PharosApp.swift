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
        _ = MenuBarSettings.shared
        _ = FanStore.shared
        _ = BatteryStore.shared
        Notifier.shared.start(observing: store)
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

/// Page-switch requests for an already-open main window (from the popover or internal navigation).
@MainActor
final class WindowRouter: ObservableObject {
    static let shared = WindowRouter()
    @Published var request: MainWindowView.SidebarItem?
    @Published var cleanupTargetGroup: DiskCleaner.Group? = nil
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
            for v in DiskVolumes.read() {
                print("disk\t\(v.name)\t\(v.kind)\tused \(ByteFormat.disk(v.used)) / \(ByteFormat.disk(v.total))\tavailable \(ByteFormat.disk(v.available))\t\(v.connection ?? "-")\t\(v.path)")
            }
            if let t = Thermals.read() {
                for f in t.fans {
                    print("fan\t\(f.index)\t\(f.actualRPM) rpm\t(\(f.minRPM)–\(f.maxRPM))\t\(f.mode.rawValue)")
                }
                let temps = SensorGroup.allCases.compactMap { g in t.groups[g].map { "\(g.rawValue) \($0)°C" } }
                print("temps\t" + temps.joined(separator: "\t") + "\tthermalState \(ProcessInfo.processInfo.thermalState.rawValue)")
            }
            for p in ProjectGrouper.group(procs, includeSystem: all) {
                let ports = p.ports.map { ":\($0.port)\($0.loopbackOnly ? "" : "*")" }.joined(separator: " ")
                print("\(p.name)\t\(ports)\t\(ByteFormat.short(p.memoryBytes))\t\(p.processCount) proc\t\(p.directory ?? "-")")
            }
            let clis = PackageScanner.scanGlobalCliTools()
            let caches = PackageScanner.scanCacheRepositories()
            let totalCacheBytes = caches.reduce(0) { $0 + $1.fileSizeBytes }
            print("packages\t\(clis.count) CLI tools\t\(caches.count) caches (\(ByteFormat.disk(totalCacheBytes)))")
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(appDelegate.store)
        } label: {
            MenuBarLabel(store: appDelegate.store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Dynamic gauge icon in the menu bar, reflecting active resource usage and pressure.
private enum DynamicMenuBarIcon {
    static func image(fraction: Double, pressure: MemoryPressure) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 6.2
            let lineWidth: CGFloat = 2.0

            // Background gray track circle (clearly visible gray area)
            ctx.setStrokeColor(NSColor.labelColor.withAlphaComponent(0.32).cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            ctx.strokePath()

            // Active progress arc (white area representing the percentage)
            if fraction > 0 {
                let startAngle: CGFloat = .pi / 2
                let clamped = min(1.0, max(0.02, CGFloat(fraction)))
                let endAngle: CGFloat = startAngle - (clamped * 2 * .pi)

                let ringColor: NSColor
                switch pressure {
                case .critical:
                    ringColor = .systemRed
                case .warning:
                    ringColor = .systemOrange
                case .normal:
                    if fraction >= 0.95 { ringColor = .systemRed }
                    else if fraction >= 0.85 { ringColor = .systemOrange }
                    else { ringColor = .labelColor }
                }

                ctx.setStrokeColor(ringColor.cgColor)
                ctx.setLineWidth(lineWidth)
                ctx.setLineCap(.round)
                ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                ctx.strokePath()
            }

            // Center status dot indicating health/pressure
            let dotColor: NSColor
            switch pressure {
            case .normal: dotColor = .systemGreen
            case .warning: dotColor = .systemYellow
            case .critical: dotColor = .systemRed
            }
            ctx.setFillColor(dotColor.cgColor)
            let dotRadius: CGFloat = 1.75
            ctx.addArc(center: center, radius: dotRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            ctx.fillPath()

            return true
        }
        image.isTemplate = false
        return image
    }
}

/// Icon plus the optional number chosen in Settings → "Menu bar shows".
private struct MenuBarLabel: View {
    @ObservedObject var store: ProjectStore
    @ObservedObject private var settings = MenuBarSettings.shared

    private var activeMetric: (fraction: Double, pressure: MemoryPressure) {
        switch settings.text {
        case .disk:
            let disk = store.volumes.first { $0.kind == .startup }
            let frac = disk?.usedFraction ?? 0
            let press: MemoryPressure = frac >= 0.95 ? .critical : (frac >= 0.85 ? .warning : .normal)
            return (frac, press)
        case .memory:
            return (store.system?.usedFraction ?? 0, store.system?.pressure ?? .normal)
        case .projects:
            let cap = max(1, settings.maxProjects)
            let frac = Double(store.projects.count) / Double(cap)
            let press: MemoryPressure = frac >= 1.0 ? .critical : (frac >= 0.85 ? .warning : .normal)
            return (min(1.0, frac), press)
        case .ports:
            let cap = max(1, settings.maxPorts)
            let frac = Double(store.totalPorts) / Double(cap)
            let press: MemoryPressure = frac >= 1.0 ? .critical : (frac >= 0.85 ? .warning : .normal)
            return (min(1.0, frac), press)
        case .none:
            return (store.system?.usedFraction ?? 0, store.system?.pressure ?? .normal)
        }
    }

    var body: some View {
        let metric = activeMetric
        HStack(spacing: 4) {
            Image(nsImage: DynamicMenuBarIcon.image(
                fraction: metric.fraction,
                pressure: metric.pressure
            ))
            if let text = settings.label(for: store) {
                Text(text).monospacedDigit()
            }
        }
    }
}
