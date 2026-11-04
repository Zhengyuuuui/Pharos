import AppKit
import SwiftUI
import CoreGraphics
import PharosCore

/// Automated high-fidelity Retina screenshot capture engine.
/// Produces pixel-perfect 2x Retina PNGs with native macOS rounded corners,
/// thin border stroke, and soft multi-layered drop shadow on transparent background.
/// Uses a dedicated developer mock dataset to ensure zero private project leakage.
@MainActor
enum ScreenshotCapture {
    static let outputDirectory = URL(fileURLWithPath: "/Users/zhengyusheng/Documents/WidgetAIUsage/img")
    private static var retainedWindows: [NSWindow] = []

    static func run(store: ProjectStore) async {
        print("📸 Starting Pharos Official Clean Demo Screenshot Capture...")

        // 1. Force macOS Dark Mode and English localization
        NSApp.appearance = NSAppearance(named: .darkAqua)
        UserDefaults.standard.set("en", forKey: "appLanguage")
        L10n.shared.language = .english

        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        // 2. Inject clean, developer-friendly mock data across all modules
        print("🛠️ Injecting pristine developer demo mock data...")
        setupMockData(store: store)

        await sleep(seconds: 0.6)

        // 3. Create single persistent main window (1040 x 700 pt)
        let mainSize = NSSize(width: 1040, height: 700)
        let hosting = NSHostingController(
            rootView: MainWindowView(initialSelection: .portsOverview).environmentObject(store)
        )

        let mainWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: mainSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        retainedWindows.append(mainWindow)
        mainWindow.appearance = NSAppearance(named: .darkAqua)
        mainWindow.contentViewController = hosting
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.titleVisibility = .hidden
        mainWindow.backgroundColor = .windowBackgroundColor
        mainWindow.setContentSize(mainSize)
        mainWindow.center()

        // Hide default system buttons to eliminate double traffic lights
        mainWindow.standardWindowButton(.closeButton)?.isHidden = true
        mainWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        mainWindow.standardWindowButton(.zoomButton)?.isHidden = true

        mainWindow.orderFrontRegardless()

        await sleep(seconds: 0.8)

        // Shot 1: Ports Overview (:3000 / :5173, favorites, port distribution)
        print("📷 [1/9] Capturing 01-dashboard-ports.png...")
        WindowRouter.shared.request = .portsOverview
        await sleep(seconds: 0.8)
        captureWindow(mainWindow, name: "01-dashboard-ports.png", cornerRadiusPt: 10.0, hasTrafficLights: true, topMarginPt: 20.0)

        // Shot 2: System Memory (Memory composition, swap, trend, Memory Doctor)
        print("📷 [2/9] Capturing 02-system-memory.png...")
        WindowRouter.shared.request = .systemMemory
        await sleep(seconds: 0.8)
        captureWindow(mainWindow, name: "02-system-memory.png", cornerRadiusPt: 10.0, hasTrafficLights: true, topMarginPt: 20.0)

        // Shot 3: Battery & Thermals (80% passthrough, 0 mA, tachometer gauges, peak temp)
        print("📷 [3/9] Capturing 03-battery-thermals.png...")
        WindowRouter.shared.batteryThermalTab = .battery
        WindowRouter.shared.request = .batteryAndThermals
        await sleep(seconds: 0.8)
        captureWindow(mainWindow, name: "03-battery-thermals.png", cornerRadiusPt: 10.0, hasTrafficLights: true, topMarginPt: 20.0)

        // Shot 4: Browser & Network (Chromium matrix + Clash/Mihomo realtime control)
        print("📷 [4/9] Capturing 04-clash-network.png...")
        WindowRouter.shared.request = .browsersAndNetwork
        await sleep(seconds: 0.8)
        captureWindow(mainWindow, name: "04-clash-network.png", cornerRadiusPt: 10.0, hasTrafficLights: true, topMarginPt: 20.0)

        // Shot 5: Disk Cleanup (4 tabs, system & dev caches, retention options)
        print("📷 [5/9] Capturing 05-disk-cleanup.png...")
        WindowRouter.shared.request = .diskCleanup
        await sleep(seconds: 0.8)
        captureWindow(mainWindow, name: "05-disk-cleanup.png", cornerRadiusPt: 10.0, hasTrafficLights: true, topMarginPt: 20.0)

        // Shot 6: AI Agent Chats (Claude Code, Cursor, Windsurf, Copilot, vacuum savings)
        print("📷 [6/9] Capturing 06-ai-agent-chats.png...")
        WindowRouter.shared.request = .agentChats
        await sleep(seconds: 0.8)
        captureWindow(mainWindow, name: "06-ai-agent-chats.png", cornerRadiusPt: 10.0, hasTrafficLights: true, topMarginPt: 20.0)

        // Shot 7: Packages & CLI (Homebrew, bun, uv, docker, cargo, bottle cache)
        print("📷 [7/9] Capturing 07-packages-cli.png...")
        WindowRouter.shared.request = .packages
        await sleep(seconds: 0.8)
        captureWindow(mainWindow, name: "07-packages-cli.png", cornerRadiusPt: 10.0, hasTrafficLights: true, topMarginPt: 20.0)

        mainWindow.orderOut(nil)

        // Shot 8: Popover
        print("📷 [8/9] Capturing 08-menu-bar-popover.png...")
        await capturePopover(name: "08-menu-bar-popover.png", store: store)

        // Shot 9: Onboarding Welcome
        print("📷 [9/9] Capturing 09-onboarding-welcome.png...")
        await captureOnboarding(name: "09-onboarding-welcome.png", store: store)

        print("🎉 All 9 pristine Retina screenshots captured successfully into \(outputDirectory.path)!")
    }

    // MARK: - Capture Helper

    private static func captureWindow(
        _ window: NSWindow,
        name: String,
        cornerRadiusPt: CGFloat,
        hasTrafficLights: Bool,
        topMarginPt: CGFloat = 20.0
    ) {
        guard let themeFrame = window.contentView?.superview else {
            print("❌ Failed to get themeFrame for \(name)")
            return
        }

        let bounds = themeFrame.bounds
        guard let rep = themeFrame.bitmapImageRepForCachingDisplay(in: bounds) else {
            print("❌ Failed to allocate bitmap rep for \(name)")
            return
        }
        themeFrame.cacheDisplay(in: bounds, to: rep)

        guard let rawCGImage = rep.cgImage else {
            print("❌ Failed to create CGImage for \(name)")
            return
        }

        let destination = outputDirectory.appendingPathComponent(name)
        if let composited = compositeWindow(
            contentImage: rawCGImage,
            cornerRadiusPt: cornerRadiusPt,
            hasTrafficLights: hasTrafficLights,
            shadowPaddingPt: 45.0,
            trafficLightTopMarginPt: topMarginPt
        ) {
            savePNG(composited, to: destination)
            print("✅ Saved \(name) (\(composited.width)x\(composited.height) px)")
        }
    }

    // MARK: - Popover Window Capture (340 pt width)

    private static func capturePopover(name: String, store: ProjectStore) async {
        let size = NSSize(width: 368, height: 530)

        let popoverContent = ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PharosColor.surface)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(PharosColor.separator.opacity(0.35), lineWidth: 0.5)

            PopoverView()
                .environmentObject(store)
                .padding(.horizontal, 4)
        }
        .frame(width: 340)
        .padding(14)

        let hosting = NSHostingController(rootView: popoverContent)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        retainedWindows.append(window)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentViewController = hosting
        window.backgroundColor = .clear
        window.isOpaque = false
        window.setContentSize(size)
        window.center()
        window.orderFrontRegardless()

        await sleep(seconds: 0.8)

        guard let view = window.contentView else { return }

        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        view.cacheDisplay(in: bounds, to: rep)

        guard let rawCGImage = rep.cgImage else { return }

        let destination = outputDirectory.appendingPathComponent(name)
        if let composited = compositeWindow(
            contentImage: rawCGImage,
            cornerRadiusPt: 16.0,
            hasTrafficLights: false,
            shadowPaddingPt: 40.0
        ) {
            savePNG(composited, to: destination)
            print("✅ Saved \(name) (\(composited.width)x\(composited.height) px)")
        }

        window.orderOut(nil)
    }

    // MARK: - Onboarding Window Capture (720 x 520 pt)

    private static func captureOnboarding(name: String, store: ProjectStore) async {
        let size = NSSize(width: 720, height: 520)
        let coordinator = OnboardingCoordinator(isReplay: true, startStep: .welcome)

        let hosting = NSHostingController(
            rootView: OnboardingView(coordinator: coordinator).environmentObject(store)
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        retainedWindows.append(window)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentViewController = hosting
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .windowBackgroundColor
        window.setContentSize(size)
        window.center()

        // Hide default system buttons to eliminate double traffic lights
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        window.orderFrontRegardless()

        await sleep(seconds: 0.8)

        guard let themeFrame = window.contentView?.superview else { return }

        let bounds = themeFrame.bounds
        guard let rep = themeFrame.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        themeFrame.cacheDisplay(in: bounds, to: rep)

        guard let rawCGImage = rep.cgImage else { return }

        let destination = outputDirectory.appendingPathComponent(name)
        if let composited = compositeWindow(
            contentImage: rawCGImage,
            cornerRadiusPt: 16.0,
            hasTrafficLights: true,
            shadowPaddingPt: 45.0,
            trafficLightTopMarginPt: 16.0 // Align precisely with Onboarding topBar (height 44pt, center 22pt)
        ) {
            savePNG(composited, to: destination)
            print("✅ Saved \(name) (\(composited.width)x\(composited.height) px)")
        }

        window.orderOut(nil)
    }

    // MARK: - CoreGraphics Compositing Engine

    private static func compositeWindow(
        contentImage: CGImage,
        cornerRadiusPt: CGFloat,
        hasTrafficLights: Bool,
        shadowPaddingPt: CGFloat,
        trafficLightTopMarginPt: CGFloat = 20.0
    ) -> CGImage? {
        let w = CGFloat(contentImage.width)
        let h = CGFloat(contentImage.height)
        let scale: CGFloat = 2.0 // Retina 2x factor

        let padPx = shadowPaddingPt * scale
        let offsetYPx: CGFloat = 10.0 * scale
        let totalW = Int(w + padPx * 2)
        let totalH = Int(h + padPx * 2 + offsetYPx)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: totalW,
            height: totalH,
            bitsPerComponent: 8,
            bytesPerRow: totalW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let windowRect = CGRect(x: padPx, y: padPx + offsetYPx, width: w, height: h)
        let cornerRadiusPx = cornerRadiusPt * scale
        let windowPath = CGPath(
            roundedRect: windowRect,
            cornerWidth: cornerRadiusPx,
            cornerHeight: cornerRadiusPx,
            transform: nil
        )

        // 1. Layer 1: Ambient Drop Shadow (Soft deep blur)
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -14 * scale),
            blur: 36 * scale,
            color: NSColor.black.withAlphaComponent(0.38).cgColor
        )
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.addPath(windowPath)
        ctx.fillPath()
        ctx.restoreGState()

        // 2. Layer 2: Key Drop Shadow (Crisp directionality)
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -4 * scale),
            blur: 12 * scale,
            color: NSColor.black.withAlphaComponent(0.24).cgColor
        )
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.addPath(windowPath)
        ctx.fillPath()
        ctx.restoreGState()

        // 3. Layer 3: Clipped Window Content
        ctx.saveGState()
        ctx.addPath(windowPath)
        ctx.clip()
        ctx.draw(contentImage, in: windowRect)
        ctx.restoreGState()

        // 4. Layer 4: Subtle Window Border (0.5 pt macOS dark outline)
        ctx.saveGState()
        ctx.addPath(windowPath)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
        ctx.setLineWidth(0.5 * scale)
        ctx.strokePath()
        ctx.restoreGState()

        // 5. Layer 5: Single Authentic Set of Colored Apple Traffic Lights
        if hasTrafficLights {
            drawTrafficLights(
                in: ctx,
                scale: scale,
                windowOrigin: windowRect.origin,
                windowHeight: h,
                topMarginPt: trafficLightTopMarginPt
            )
        }

        return ctx.makeImage()
    }

    private static func drawTrafficLights(
        in ctx: CGContext,
        scale: CGFloat,
        windowOrigin: CGPoint,
        windowHeight: CGFloat,
        topMarginPt: CGFloat
    ) {
        let diameter: CGFloat = 12.0 * scale
        let spacing: CGFloat = 8.0 * scale
        let leftMargin: CGFloat = 20.0 * scale
        let topMargin: CGFloat = topMarginPt * scale

        // Coordinates in CGContext (origin is bottom-left)
        let y = windowOrigin.y + windowHeight - topMargin - diameter

        let buttons: [(fill: NSColor, stroke: NSColor)] = [
            (
                NSColor(red: 1.0, green: 0.373, blue: 0.341, alpha: 1.0),
                NSColor(red: 0.88, green: 0.20, blue: 0.18, alpha: 1.0)
            ),
            (
                NSColor(red: 1.0, green: 0.741, blue: 0.180, alpha: 1.0),
                NSColor(red: 0.88, green: 0.60, blue: 0.10, alpha: 1.0)
            ),
            (
                NSColor(red: 0.157, green: 0.784, blue: 0.251, alpha: 1.0),
                NSColor(red: 0.10, green: 0.65, blue: 0.18, alpha: 1.0)
            ),
        ]

        for (i, btn) in buttons.enumerated() {
            let x = windowOrigin.x + leftMargin + CGFloat(i) * (diameter + spacing)
            let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
            ctx.saveGState()
            ctx.setFillColor(btn.fill.cgColor)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(btn.stroke.cgColor)
            ctx.setLineWidth(0.5 * scale)
            ctx.strokeEllipse(in: rect)
            ctx.restoreGState()
        }
    }

    private static func savePNG(_ image: CGImage, to url: URL) {
        let rep = NSBitmapImageRep(cgImage: image)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
    }

    // MARK: - Pristine Mock Dataset Construction

    static func setupMockData(store: ProjectStore) {
        let now = Date()

        // 1. Clean Developer Projects (Focusing on :3000, :5173*, :8000, :5432, :6379)
        let mockProjects = [
            Project(
                id: "nextjs-frontend",
                name: "nextjs-frontend",
                directory: "/Users/developer/Projects/nextjs-frontend",
                listeners: [makeProc(name: "node", pid: 3001, port: 3000, loopback: true, memory: 184_000_000)],
                helpers: [],
                ports: [ListeningPort(port: 3000, loopbackOnly: true)],
                memoryBytes: 184_000_000
            ),
            Project(
                id: "vite-react-admin",
                name: "vite-react-admin",
                directory: "/Users/developer/Projects/vite-react-admin",
                listeners: [makeProc(name: "vite", pid: 5174, port: 5173, loopback: false, memory: 96_000_000)],
                helpers: [],
                ports: [ListeningPort(port: 5173, loopbackOnly: false)], // Exposed (*)
                memoryBytes: 96_000_000
            ),
            Project(
                id: "fastapi-core",
                name: "fastapi-core",
                directory: "/Users/developer/Projects/fastapi-core",
                listeners: [makeProc(name: "uvicorn", pid: 8001, port: 8000, loopback: true, memory: 124_000_000)],
                helpers: [],
                ports: [ListeningPort(port: 8000, loopbackOnly: true)],
                memoryBytes: 124_000_000
            ),
            Project(
                id: "postgres-db",
                name: "postgres-db",
                directory: "/opt/homebrew/var/postgresql@16",
                listeners: [makeProc(name: "postgres", pid: 5433, port: 5432, loopback: true, memory: 72_000_000)],
                helpers: [],
                ports: [ListeningPort(port: 5432, loopbackOnly: true)],
                memoryBytes: 72_000_000
            ),
            Project(
                id: "redis-server",
                name: "redis-server",
                directory: "/opt/homebrew/var/db/redis",
                listeners: [makeProc(name: "redis-server", pid: 6380, port: 6379, loopback: true, memory: 28_000_000)],
                helpers: [],
                ports: [ListeningPort(port: 6379, loopbackOnly: true)],
                memoryBytes: 28_000_000
            ),
            Project(
                id: "qdrant-vector",
                name: "qdrant-vector",
                directory: "/Users/developer/Projects/qdrant-vector",
                listeners: [makeProc(name: "qdrant", pid: 6334, port: 6333, loopback: true, memory: 136_000_000)],
                helpers: [],
                ports: [ListeningPort(port: 6333, loopbackOnly: true)],
                memoryBytes: 136_000_000
            ),
            Project(
                id: "spring-cloud-gateway",
                name: "spring-cloud-gateway",
                directory: "/Users/developer/Projects/spring-cloud-gateway",
                listeners: [makeProc(name: "java", pid: 8081, port: 8080, loopback: false, memory: 340_000_000)],
                helpers: [],
                ports: [ListeningPort(port: 8080, loopbackOnly: false)], // Exposed (*)
                memoryBytes: 340_000_000
            ),
            Project(
                id: "graphql-mesh",
                name: "graphql-mesh",
                directory: "/Users/developer/Projects/graphql-mesh",
                listeners: [makeProc(name: "node", pid: 4001, port: 4000, loopback: true, memory: 108_000_000)],
                helpers: [],
                ports: [ListeningPort(port: 4000, loopbackOnly: true)],
                memoryBytes: 108_000_000
            )
        ]

        // 2. Favorites (Workspaces)
        WorkspaceStore.shared.applyMockFavorites([
            Favorite(
                name: "nextjs-frontend",
                directory: "/Users/developer/Projects/nextjs-frontend",
                command: "npm run dev",
                commandSource: .detected,
                lastPorts: [3000]
            ),
            Favorite(
                name: "vite-react-admin",
                directory: "/Users/developer/Projects/vite-react-admin",
                command: "pnpm dev --host",
                commandSource: .detected,
                lastPorts: [5173]
            ),
            Favorite(
                name: "fastapi-core",
                directory: "/Users/developer/Projects/fastapi-core",
                command: "uvicorn main:app --reload",
                commandSource: .detected,
                lastPorts: [8000]
            )
        ])

        // 3. System Memory Stats (36 GB M3 Pro)
        let totalMem: UInt64 = 38_654_705_664 // 36 GB
        let usedMem: UInt64 = 22_763_320_000  // ~21.2 GB (59%)
        let mockSys = SystemMemoryStats(
            total: totalMem,
            appMemory: 14_800_000_000,
            wired: 3_450_000_000,
            compressed: 4_513_320_000,
            cachedFiles: 11_800_000_000,
            swapUsed: 524_288_000,
            swapTotal: 2_147_483_648,
            pressure: .normal
        )

        // 4. Top Apps
        let mockApps = [
            AppUsage(name: "Google Chrome", memoryBytes: 4_509_715_200, processCount: 38),
            AppUsage(name: "Xcode", memoryBytes: 3_428_599_040, processCount: 16),
            AppUsage(name: "Visual Studio Code", memoryBytes: 1_832_735_283, processCount: 18),
            AppUsage(name: "Docker Desktop", memoryBytes: 1_503_238_553, processCount: 8),
            AppUsage(name: "Antigravity", memoryBytes: 1_048_576_000, processCount: 7),
            AppUsage(name: "Terminal", memoryBytes: 320_000_000, processCount: 4),
            AppUsage(name: "Figma", memoryBytes: 280_000_000, processCount: 3)
        ]

        // 5. Disk Volumes
        let mockVolumes = [
            DiskVolume(
                path: "/",
                name: "Macintosh HD",
                kind: .startup,
                total: 4_000_000_000_000,
                available: 3_580_000_000_000,
                format: "APFS",
                connection: "Apple Fabric"
            )
        ]

        // 6. Thermals & Fan Telemetry (Dual fans at 5,400 RPM, CPU 72°C)
        let mockThermals = ThermalSnapshot(
            fans: [
                FanReading(index: 0, actualRPM: 5400, targetRPM: 5400, minRPM: 2317, maxRPM: 6800, mode: .system),
                FanReading(index: 1, actualRPM: 5400, targetRPM: 5400, minRPM: 2317, maxRPM: 6800, mode: .system)
            ],
            groups: [
                .cpu: 72.0,
                .gpu: 45.0,
                .memory: 42.0,
                .ssd: 31.0,
                .battery: 28.2,
                .power: 41.0,
                .ambient: 34.0
            ]
        )

        // 7. Memory Doctor Daemon Bloat
        let mockBloatItem = DaemonDiagnosisItem(
            daemon: .quickLook,
            pids: [2901],
            memoryBytes: 398_458_880,
            status: .bloated,
            isLaunchdDisabled: false,
            processCount: 1
        )
        let mockDiagnosis = MemoryDiagnosisReport(
            items: [mockBloatItem],
            reclaimableBytes: 398_458_880,
            scannedAt: now
        )

        // 8. Rolling Memory Trend History (Past hour, 30 samples)
        var samples: [MemorySample] = []
        for i in 0..<30 {
            let time = now.addingTimeInterval(-Double(29 - i) * 120)
            let wave = sin(Double(i) * 0.35) * 450_000_000
            let used = UInt64(Double(usedMem) + wave)
            let dev = mockProjects.prefix(4).map { ProjectSample(id: $0.id, name: $0.name, bytes: $0.memoryBytes) }
            samples.append(MemorySample(date: time, systemUsed: used, projects: Array(dev)))
        }
        var h = MemoryHistory(window: 3600, minInterval: 10)
        for s in samples { h.append(s) }

        // 9. Chromium Multi-Configuration Instances
        let mockChrome = [
            ChromeInstance(
                pid: 1101,
                config: ChromeConfig(
                    browser: .chrome,
                    userDataDir: "/Users/developer/Library/Application Support/Google/Chrome/Profile 1",
                    debugPort: nil,
                    proxyServer: nil,
                    startURL: nil,
                    extraFlags: []
                ),
                memoryBytes: 1_280_000_000,
                processCount: 24,
                helperPIDs: [1102, 1103]
            ),
            ChromeInstance(
                pid: 1104,
                config: ChromeConfig(
                    browser: .chrome,
                    userDataDir: "/Users/developer/Library/Application Support/Google/Chrome/Profile 2",
                    debugPort: 9222,
                    proxyServer: "http://127.0.0.1:7890",
                    startURL: nil,
                    extraFlags: []
                ),
                memoryBytes: 940_000_000,
                processCount: 16,
                helperPIDs: [1105]
            ),
            ChromeInstance(
                pid: 1106,
                config: ChromeConfig(
                    browser: .brave,
                    userDataDir: "/Users/developer/Library/Application Support/BraveSoftware/Brave-Browser/Default",
                    debugPort: nil,
                    proxyServer: "http://127.0.0.1:7897",
                    startURL: nil,
                    extraFlags: []
                ),
                memoryBytes: 680_000_000,
                processCount: 12,
                helperPIDs: []
            )
        ]

        var scanState = ProjectStore.ScanState()
        scanState.projects = mockProjects
        scanState.chrome = mockChrome
        scanState.listeningPorts = Set([3000, 5173, 8000, 5432, 6379, 6333, 8080, 4000])
        scanState.apps = mockApps
        scanState.system = mockSys
        scanState.volumes = mockVolumes
        scanState.thermals = mockThermals
        scanState.thermalState = .nominal
        scanState.history = h
        scanState.lastScan = now
        scanState.memoryDiagnosis = mockDiagnosis

        store.applyMockState(scanState)

        // 10. Battery Reading (80% Tahoe limit, 0 mA passthrough, AC power)
        var batteryReading = BatteryReading()
        batteryReading.currentPercent = 80
        batteryReading.powerSource = .acPower
        batteryReading.isCharging = false
        batteryReading.isCharged = false
        batteryReading.amperage = 0
        batteryReading.watts = 0.0
        let isEn = L10n.shared.language == .english

        batteryReading.adapterWatts = 68
        batteryReading.adapterName = isEn ? "Apple 70W USB-C Power Adapter" : "Apple 70W USB-C 电源适配器"
        batteryReading.temperatureCelsius = 28.2
        batteryReading.health = .normal
        batteryReading.healthPercent = 98
        batteryReading.cycleCount = 42
        batteryReading.designCapacity = 6075
        batteryReading.maxCapacity = 5953
        BatteryStore.shared.applyMockReading(batteryReading, mode: .limit(maxPercent: 80), helper: .ready)

        // 11. Clash / Mihomo Daemon Snapshot
        let clashSnap = ClashStatusSnapshot(
            isRunning: true,
            clientKind: .mihomoParty,
            mode: .rule,
            mixedPort: 7890,
            socksPort: 7891,
            isTunEnabled: true,
            uploadBytesPerSec: 124 * 1024,
            downloadBytesPerSec: 1840 * 1024,
            totalUploadBytes: 420 * 1024 * 1024,
            totalDownloadBytes: 3120 * 1024 * 1024,
            activeConnectionCount: 14,
            controllerEndpoint: "127.0.0.1:9097"
        )
        ClashStore.shared.applyMockSnapshot(clashSnap)

        // 12. Disk Cleaner Rows (18.6 GB cleanable)
        let targetMap = Dictionary(uniqueKeysWithValues: DiskCleaner.defaultTargets.map { ($0.id, $0) })
        let mockCleanupRows: [CleanupStore.Row] = [
            CleanupStore.Row(target: targetMap["tmp"] ?? DiskCleaner.defaultTargets[0], bytes: 3_435_973_836),
            CleanupStore.Row(target: targetMap["user-logs"] ?? DiskCleaner.defaultTargets[1], bytes: 1_503_238_553),
            CleanupStore.Row(target: targetMap["user-trash"] ?? DiskCleaner.defaultTargets[2], bytes: 5_153_960_755),
            CleanupStore.Row(target: targetMap["chrome-cache"] ?? DiskCleaner.defaultTargets[3], bytes: 2_791_728_742),
            CleanupStore.Row(target: targetMap["app-caches"] ?? DiskCleaner.defaultTargets[4], bytes: 7_086_696_038)
        ]
        CleanupStoreHolder.shared.applyMockRows(mockCleanupRows)

        // 13. AI Agent Chats Rollups (6.6 GB across Claude Code, Cursor, Windsurf, Copilot, Trae, Antigravity)
        let mockSummaries = [
            AgentEditorSummary(
                editor: .claudeCode,
                totalBytes: 2_576_980_377, // 2.4 GB
                databaseCount: 48,
                conversationCount: 48,
                workspaceBytes: 1_800_000_000,
                globalBytes: 776_980_377,
                cacheBytes: 0,
                orphanedCount: 0,
                lastModified: now.addingTimeInterval(-3600)
            ),
            AgentEditorSummary(
                editor: .cursor,
                totalBytes: 1_932_735_283, // 1.8 GB
                databaseCount: 86,
                conversationCount: 120,
                workspaceBytes: 1_500_000_000,
                globalBytes: 432_735_283,
                cacheBytes: 0,
                orphanedCount: 2,
                lastModified: now.addingTimeInterval(-7200)
            ),
            AgentEditorSummary(
                editor: .windsurf,
                totalBytes: 1_030_792_151, // 960 MB
                databaseCount: 38,
                conversationCount: 52,
                workspaceBytes: 800_000_000,
                globalBytes: 230_792_151,
                cacheBytes: 0,
                orphanedCount: 1,
                lastModified: now.addingTimeInterval(-10800)
            ),
            AgentEditorSummary(
                editor: .vscode,
                totalBytes: 687_194_767, // 640 MB
                databaseCount: 64,
                conversationCount: 110,
                workspaceBytes: 500_000_000,
                globalBytes: 187_194_767,
                cacheBytes: 0,
                orphanedCount: 0,
                lastModified: now.addingTimeInterval(-14400)
            ),
            AgentEditorSummary(
                editor: .trae,
                totalBytes: 450_971_520, // 420 MB
                databaseCount: 22,
                conversationCount: 28,
                workspaceBytes: 350_000_000,
                globalBytes: 100_971_520,
                cacheBytes: 0,
                orphanedCount: 1,
                lastModified: now.addingTimeInterval(-18000)
            ),
            AgentEditorSummary(
                editor: .antigravity,
                totalBytes: 408_021_893, // 380 MB
                databaseCount: 24,
                conversationCount: 36,
                workspaceBytes: 300_000_000,
                globalBytes: 108_021_893,
                cacheBytes: 0,
                orphanedCount: 0,
                lastModified: now.addingTimeInterval(-21600)
            )
        ]
        AgentChatStore.shared.applyMockData(summaries: mockSummaries, entries: [])

        // 14. Packages & Global CLI Tools (Clean official open source tools)
        let mockTools = [
            LocalPackageItem(
                id: "bun",
                name: "bun",
                installedVersion: "1.1.20",
                declaredVersion: nil,
                ecosystem: .node,
                scope: .globalCli,
                summary: isEn ? "Ultra-fast all-in-one JavaScript & TypeScript toolkit and package manager" : "极速全功能 JavaScript/TypeScript 运行时与包管理器",
                installPath: "/Users/developer/.bun/bin/bun",
                executablePath: "/Users/developer/.bun/bin/bun",
                fileSizeBytes: 98_000_000,
                isFeatured: true,
                categoryTag: isEn ? "Package Manager" : "包管理"
            ),
            LocalPackageItem(
                id: "docker",
                name: "docker",
                installedVersion: "27.0.3",
                declaredVersion: nil,
                ecosystem: .homebrew,
                scope: .globalCli,
                summary: isEn ? "Enterprise platform for building, sharing, and running container applications" : "工业级容器应用构建、共享与运行平台",
                installPath: "/usr/local/bin/docker",
                executablePath: "/usr/local/bin/docker",
                fileSizeBytes: 84_000_000,
                isFeatured: true,
                categoryTag: isEn ? "Containers" : "开发构建"
            ),
            LocalPackageItem(
                id: "uv",
                name: "uv",
                installedVersion: "0.2.14",
                declaredVersion: nil,
                ecosystem: .python,
                scope: .globalCli,
                summary: isEn ? "An extremely fast Python package manager and resolver written in Rust" : "Rust 编写的超高速 Python 包管理器与环境解析器",
                installPath: "/Users/developer/.cargo/bin/uv",
                executablePath: "/Users/developer/.cargo/bin/uv",
                fileSizeBytes: 32_000_000,
                isFeatured: true,
                categoryTag: isEn ? "Package Manager" : "包管理"
            ),
            LocalPackageItem(
                id: "ripgrep",
                name: "ripgrep",
                installedVersion: "14.1.0",
                declaredVersion: nil,
                ecosystem: .rust,
                scope: .globalCli,
                summary: isEn ? "Fast line-oriented search tool based on Rust regex engine" : "基于 Rust 正则引擎的超高速递归行文本搜索工具",
                installPath: "/opt/homebrew/bin/rg",
                executablePath: "/opt/homebrew/bin/rg",
                fileSizeBytes: 18_000_000,
                isFeatured: true,
                categoryTag: isEn ? "CLI Tools" : "终端效率"
            ),
            LocalPackageItem(
                id: "ffmpeg",
                name: "ffmpeg",
                installedVersion: "7.0.1",
                declaredVersion: nil,
                ecosystem: .homebrew,
                scope: .globalCli,
                summary: isEn ? "Leading multimedia framework to decode, encode, and transcode audio & video" : "音视频录制、格式转换与多媒体流媒体处理套件",
                installPath: "/opt/homebrew/bin/ffmpeg",
                executablePath: "/opt/homebrew/bin/ffmpeg",
                fileSizeBytes: 110_000_000,
                isFeatured: true,
                categoryTag: isEn ? "Media" : "独立软件"
            ),
            LocalPackageItem(
                id: "gh",
                name: "gh",
                installedVersion: "2.52.0",
                declaredVersion: nil,
                ecosystem: .go,
                scope: .globalCli,
                summary: isEn ? "GitHub official command line tool for workflows and team collaboration" : "GitHub 官方命令行工作流协同管理工具",
                installPath: "/opt/homebrew/bin/gh",
                executablePath: "/opt/homebrew/bin/gh",
                fileSizeBytes: 42_000_000,
                isFeatured: true,
                categoryTag: isEn ? "Collaboration" : "开发协作"
            ),
            LocalPackageItem(
                id: "pnpm",
                name: "pnpm",
                installedVersion: "9.5.0",
                declaredVersion: nil,
                ecosystem: .node,
                scope: .globalCli,
                summary: isEn ? "Fast, disk space efficient package manager using content-addressable storage" : "基于内容寻址与硬链接的快速、节省磁盘空间的包管理器",
                installPath: "/Users/developer/.nvm/versions/node/v20.15.0/bin/pnpm",
                executablePath: "/Users/developer/.nvm/versions/node/v20.15.0/bin/pnpm",
                fileSizeBytes: 24_000_000,
                isFeatured: true,
                categoryTag: isEn ? "Package Manager" : "包管理"
            ),
            LocalPackageItem(
                id: "cargo-tauri",
                name: "cargo-tauri",
                installedVersion: "2.0.0",
                declaredVersion: nil,
                ecosystem: .rust,
                scope: .globalCli,
                summary: isEn ? "Build lightweight, blazingly fast cross-platform desktop apps with web frontends" : "使用 Web 前端技术构建极小、极快跨平台桌面应用的工具链",
                installPath: "/Users/developer/.cargo/bin/cargo-tauri",
                executablePath: "/Users/developer/.cargo/bin/cargo-tauri",
                fileSizeBytes: 68_000_000,
                isFeatured: true,
                categoryTag: isEn ? "Frameworks" : "开发构建"
            )
        ]

        let mockCaches = [
            PackageCacheRepoSummary(
                id: "homebrew-cache",
                name: isEn ? "Homebrew Bottle & Download Cache" : "Homebrew 下载与 Bottle 缓存",
                ecosystem: .homebrew,
                rootPath: "/Users/developer/Library/Caches/Homebrew",
                fileSizeBytes: 3_865_470_566,
                itemCount: 48,
                description: isEn ? "Precompiled binary bottles and git repository cache" : "预编译二进制 Bottle 安装包与 Git 源码归档缓存"
            ),
            PackageCacheRepoSummary(
                id: "npm-cache",
                name: isEn ? "npm Global Module Cache" : "npm 官方模块下载缓存",
                ecosystem: .node,
                rootPath: "/Users/developer/.npm/_cacache",
                fileSizeBytes: 2_147_483_648,
                itemCount: 320,
                description: isEn ? "Global tarball archive and integrity index data" : "全局 npm tarball 包体与 integrity 散列索引数据"
            ),
            PackageCacheRepoSummary(
                id: "cargo-cache",
                name: isEn ? "Rust Cargo Registry & Crate Cache" : "Rust Cargo 注册源与 Crate 缓存",
                ecosystem: .rust,
                rootPath: "/Users/developer/.cargo/registry",
                fileSizeBytes: 1_610_612_736,
                itemCount: 180,
                description: isEn ? "crates.io metadata index and unpacked dependency sources" : "crates.io 索引元数据与解压后的 Rust crate 依赖源码"
            ),
            PackageCacheRepoSummary(
                id: "pip-cache",
                name: isEn ? "Python pip Wheel Cache" : "Python pip 预编译 Wheel 缓存",
                ecosystem: .python,
                rootPath: "/Users/developer/Library/Caches/pip",
                fileSizeBytes: 1_288_490_188,
                itemCount: 94,
                description: isEn ? "Precompiled wheel packages and HTTP cache from PyPI" : "从 PyPI 下载的预构建 .whl 二进制模块与 http 响应缓存"
            )
        ]
        PackageStore.shared.applyMockData(tools: mockTools, caches: mockCaches)
    }

    private static func makeProc(
        name: String,
        pid: Int32,
        port: UInt16,
        loopback: Bool,
        memory: UInt64
    ) -> ProcessSnapshot {
        ProcessSnapshot(
            pid: pid,
            ppid: 1,
            name: name,
            memoryBytes: memory,
            ports: [ListeningPort(port: port, loopbackOnly: loopback)]
        )
    }

    private static func sleep(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
