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
