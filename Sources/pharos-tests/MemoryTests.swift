import Foundation
import PharosCore

func testSystemMemoryMath() {
    let s = SystemMemoryStats.from(pageSize: 16384, internalPages: 1000, purgeablePages: 100,
                                   externalPages: 300, wiredPages: 200, compressorPages: 50,
                                   total: 16384 * 4000)
    expectEq(s.appMemory, 900 * 16384, "app = internal - purgeable")
    expectEq(s.cachedFiles, 400 * 16384, "cached = external + purgeable")
    expectEq(s.used, (900 + 200 + 50) * 16384, "used = app + wired + compressed")
    expectEq(s.free, (4000 - 1150 - 400) * 16384, "free = total - used - cached")
    expectEq(s.available, s.cachedFiles + s.free, "available = cached + free")
    expect(abs(s.usedFraction - 1150.0 / 4000.0) < 1e-9, "used fraction")

    let weird = SystemMemoryStats.from(pageSize: 1, internalPages: 1, purgeablePages: 5,
                                       externalPages: 0, wiredPages: 0, compressorPages: 0, total: 10)
    expectEq(weird.appMemory, 0, "purgeable > internal doesn't underflow")

    let live = SystemMemory.read()
    expect(live != nil, "live vm stats")
    if let live {
        expect(live.total > 1 << 30, "total > 1 GB")
        expect(live.used > 0 && live.used <= live.total, "used within total")
    }
}

func testAppGrouper() {
    expectEq(AppGrouper.appName(path: "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/x",
                                fallback: "x"), "Google Chrome", "nested helper → outer app")
    expectEq(AppGrouper.appName(path: "/opt/homebrew/bin/node", fallback: "node"), "node", "plain binary → fallback")
    expectEq(AppGrouper.appName(path: nil, fallback: "launchd"), "launchd", "nil path")

    let ps = [
        ProcessSnapshot(pid: 1, ppid: 0, name: "Chrome", executablePath: "/Applications/Chrome.app/Contents/MacOS/Chrome", memoryBytes: 100),
        ProcessSnapshot(pid: 2, ppid: 1, name: "Helper", executablePath: "/Applications/Chrome.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper", memoryBytes: 300),
        ProcessSnapshot(pid: 3, ppid: 0, name: "node", executablePath: "/opt/homebrew/bin/node", memoryBytes: 250),
        ProcessSnapshot(pid: 4, ppid: 0, name: "node", executablePath: "/opt/homebrew/bin/node", memoryBytes: 50),
    ]
    let apps = AppGrouper.group(ps)
    expectEq(apps.map(\.name), ["Chrome", "node"], "sorted by memory desc")
    expectEq(apps[0].memoryBytes, 400, "chrome summed")
    expectEq(apps[0].processCount, 2, "chrome count")
    expectEq(apps[1].memoryBytes, 300, "node summed")
}

func testMemoryHistory() {
    var h = MemoryHistory(window: 60, minInterval: 10)
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let a = ProjectSample(id: "a", name: "A", bytes: 100)
    let b = ProjectSample(id: "b", name: "B", bytes: 50)
    let c = ProjectSample(id: "c", name: "C", bytes: 10)

    h.append(MemorySample(date: t0, systemUsed: 1, projects: [a]))
    h.append(MemorySample(date: t0.addingTimeInterval(3), systemUsed: 2, projects: [a, b]))
    expectEq(h.samples.count, 1, "burst collapses")
    expectEq(h.samples[0].systemUsed, 2, "collapsed keeps latest values")
    expectEq(h.samples[0].date, t0, "collapsed keeps original timestamp")

    h.append(MemorySample(date: t0.addingTimeInterval(30), systemUsed: 3, projects: [a, b, c]))
    h.append(MemorySample(date: t0.addingTimeInterval(80), systemUsed: 4, projects: [b, c]))
    expectEq(h.samples.map(\.systemUsed), [3, 4], "window trims old samples")
    expectEq(h.samples.last?.devTotal, 60, "dev total")

    let (names, points) = h.projectSeries(limit: 1, otherName: "Other")
    expectEq(names, ["B", "Other"], "top-1 + other")
    expectEq(points.count, 4, "dense: series × samples")
    let otherFirst = points.first { $0.series == "Other" && $0.date == h.samples[0].date }
    expectEq(otherFirst?.bytes, 110, "other folds A + C")

    let empty = MemoryHistory().projectSeries(limit: 5, otherName: "x")
    expect(empty.names.isEmpty && empty.points.isEmpty, "empty history")
}

func testMemoryDoctorDiagnosis() {
    let mb: UInt64 = 1024 * 1024
    let gb: UInt64 = 1024 * 1024 * 1024

    let procs = [
        // mediaAnalysis: 200MB + 150MB = 350MB (> 300MB -> .bloated)
        ProcessSnapshot(pid: 101, ppid: 1, name: "mediaanalysisd",
                        executablePath: "/System/Library/PrivateFrameworks/MediaAnalysis.framework/Versions/A/mediaanalysisd",
                        memoryBytes: 200 * mb),
        ProcessSnapshot(pid: 102, ppid: 1, name: "mediaanalysisd-access",
                        executablePath: "/System/Library/PrivateFrameworks/MediaAnalysis.framework/Versions/A/mediaanalysisd-access",
                        memoryBytes: 150 * mb),

        // photoAnalysis: 1.2 GB (> 1GB -> .critical)
        ProcessSnapshot(pid: 201, ppid: 1, name: "photoanalysisd",
                        executablePath: "/System/Library/PrivateFrameworks/PhotoAnalysis.framework/Versions/A/photoanalysisd",
                        memoryBytes: UInt64(1.2 * Double(gb))),

        // wallpaper: 450 MB (> 400MB -> .bloated)
        ProcessSnapshot(pid: 301, ppid: 1, name: "WallpaperVideoExtension",
                        executablePath: "/System/Library/ExtensionKit/Extensions/WallpaperVideoExtension.appex/Contents/MacOS/WallpaperVideoExtension",
                        memoryBytes: 450 * mb),

        // spotlight: corespotlightd (250MB) + mdworker_shared (200MB) = 450MB (> 400MB -> .bloated)
        ProcessSnapshot(pid: 401, ppid: 1, name: "corespotlightd",
                        executablePath: "/System/Library/Frameworks/CoreSpotlight.framework/corespotlightd",
                        memoryBytes: 250 * mb),
        ProcessSnapshot(pid: 402, ppid: 1, name: "mdworker_shared",
                        executablePath: "/System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Versions/A/Support/mdworker_shared",
                        memoryBytes: 200 * mb),

        // openAndSavePanel: 120 MB (> 100MB -> .bloated)
        ProcessSnapshot(pid: 501, ppid: 1, name: "openAndSavePanelService",
                        executablePath: "/System/Library/Frameworks/AppKit.framework/Versions/C/XPCServices/com.apple.appkit.xpc.openAndSavePanelService.xpc/Contents/MacOS/com.apple.appkit.xpc.openAndSavePanelService",
                        memoryBytes: 120 * mb),

        // quickLook: 80 MB (< 200MB -> .healthy)
        ProcessSnapshot(pid: 601, ppid: 1, name: "QuickLookUIService",
                        executablePath: "/System/Library/Frameworks/QuickLook.framework/Versions/A/XPCServices/QuickLookUIService.xpc/Contents/MacOS/QuickLookUIService",
                        memoryBytes: 80 * mb),

        // iconServices: 50 MB (< 200MB -> .healthy)
        ProcessSnapshot(pid: 701, ppid: 1, name: "iconservicesagent",
                        executablePath: "/System/Library/CoreServices/iconservicesagent",
                        memoryBytes: 50 * mb),

        // intelligencePlatform: 320 MB (> 300MB -> .bloated)
        ProcessSnapshot(pid: 801, ppid: 1, name: "intelligenceplatformd",
                        executablePath: "/usr/libexec/intelligenceplatformd",
                        memoryBytes: 320 * mb),

        // suggest: 100 MB (< 250MB -> .healthy)
        ProcessSnapshot(pid: 901, ppid: 1, name: "suggestd",
                        executablePath: "/System/Library/PrivateFrameworks/CoreSuggestions.framework/suggestd",
                        memoryBytes: 100 * mb),

        // Unrelated process: node dev server
        ProcessSnapshot(pid: 9999, ppid: 1, name: "node",
                        executablePath: "/opt/homebrew/bin/node",
                        memoryBytes: 500 * mb),
    ]

    let report = MemoryDoctor.diagnose(processes: procs, disabledDaemons: [.mediaAnalysis])

    expect(report.hasBloat, "report has bloated daemons")
    expectEq(report.criticalCount, 1, "photoanalysisd is critical")
    expectEq(report.bloatedCount, 6, "photoanalysisd + mediaAnalysis + wallpaper + spotlight + openAndSavePanel + intelligencePlatform = 6 bloated or critical")

    let photo = report.items.first { $0.daemon == .photoAnalysis }
    expect(photo != nil, "photoanalysisd item found")
    expectEq(photo?.status, .critical, "photoanalysisd is critical (>1GB)")
    expectEq(photo?.pids, [201], "photoanalysisd PID")
    expect(!photo!.isLaunchdDisabled, "photoAnalysis not disabled")

    let media = report.items.first { $0.daemon == .mediaAnalysis }
    expect(media != nil, "mediaAnalysis item found")
    expectEq(media?.status, .bloated, "mediaAnalysis is bloated (350MB > 300MB)")
    expectEq(media?.pids, [101, 102], "mediaAnalysis aggregated both PIDs")
    expectEq(media?.memoryBytes, 350 * mb, "mediaAnalysis aggregated memory")
    expect(media!.isLaunchdDisabled, "mediaAnalysis is launchd-disabled")

    let wallpaper = report.items.first { $0.daemon == .wallpaper }
    expectEq(wallpaper?.status, .bloated, "wallpaper is bloated")

    let quickLook = report.items.first { $0.daemon == .quickLook }
    expectEq(quickLook?.status, .healthy, "quickLook is healthy (80MB < 200MB)")

    let iconServices = report.items.first { $0.daemon == .iconServices }
    expectEq(iconServices?.status, .healthy, "iconServices is healthy (50MB < 200MB)")

    let suggest = report.items.first { $0.daemon == .suggest }
    expectEq(suggest?.status, .healthy, "suggest is healthy (100MB < 250MB)")

    var expectedReclaimable: UInt64 = 0
    expectedReclaimable += photo?.memoryBytes ?? 0
    expectedReclaimable += media?.memoryBytes ?? 0
    expectedReclaimable += wallpaper?.memoryBytes ?? 0
    expectedReclaimable += report.items.first { $0.daemon == .spotlight }?.memoryBytes ?? 0
    expectedReclaimable += report.items.first { $0.daemon == .openAndSavePanel }?.memoryBytes ?? 0
    expectedReclaimable += report.items.first { $0.daemon == .intelligencePlatform }?.memoryBytes ?? 0

    expectEq(report.reclaimableBytes, expectedReclaimable, "reclaimable bytes sum")
    expect(report.reclaimableBytes > 2 * gb, "reclaimable bytes exceeds 2GB")

    // Test clean/empty diagnosis
    let cleanReport = MemoryDoctor.diagnose(processes: [
        ProcessSnapshot(pid: 1, ppid: 0, name: "launchd", memoryBytes: 10 * mb)
    ])
    expect(!cleanReport.hasBloat, "clean report has no bloat")
    expectEq(cleanReport.reclaimableBytes, 0, "clean report reclaimable is 0")
}
