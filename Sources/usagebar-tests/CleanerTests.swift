import Foundation
import UsageBarCore

func testCleanerTargetsAndPaths() {
    expect(DiskCleaner.darwinUserDir(isCache: false).hasPrefix("/var/folders/"), "user temp dir resolved from kernel")
    expect(DiskCleaner.darwinUserDir(isCache: true).hasPrefix("/var/folders/"), "user cache dir resolved from kernel")
    expect(DiskCleaner.defaultTargets.count > 10, "default target list present")
    expect(DiskCleaner.defaultTargets.allSatisfy { $0.path == "" || $0.path.hasPrefix("/") },
           "target paths are absolute")
    let ids = DiskCleaner.defaultTargets.map(\.id)
    expect(Set(ids).count == ids.count, "target ids unique")

    let appCaches = DiskCleaner.defaultTargets.first { $0.id == "app-caches" }
    expectEq(appCaches?.path, DiskCleaner.home + "/Library/Caches", "app caches target path")
    expectEq(appCaches?.maxAgeDays, 7, "app caches keep week-old window")
    let nested = DiskCleaner.defaultTargets.filter { $0.path.hasPrefix((appCaches?.path ?? "\0") + "/") }
    expect(nested.count >= 4, "several dev caches live under app caches")
    expectEq(DiskCleaner.nestedPaths(under: appCaches!, in: DiskCleaner.defaultTargets).count,
             nested.count, "app caches excludes all nested rows")
}

func testCleanerGroups() {
    let temp = DiskCleaner.targets(in: .temp)
    expectEq(temp.map(\.id), ["tmp", "var-tmp", "user-temp", "user-cache"], "temp group = the AI scratch dirs")
    expect(temp.allSatisfy { $0.maxAgeDays == 1 }, "temp group defaults to a 1-day window")
    expect(temp.allSatisfy { !$0.path.hasSuffix("/") }, "no trailing slash (root-keep check relies on it)")
    expect(temp.first { $0.id == "user-temp" }?.path.hasSuffix("/T") == true, "var/folders …/T")
    expect(temp.first { $0.id == "user-cache" }?.path.hasSuffix("/C") == true, "var/folders …/C")
    expect(DiskCleaner.Group.allCases.allSatisfy { !DiskCleaner.targets(in: $0).isEmpty }, "every group has rows")
    expectEq(DiskCleaner.Group.allCases.reduce(0) { $0 + DiskCleaner.targets(in: $1).count },
             DiskCleaner.defaultTargets.count, "every target is in exactly one group")

    let t = temp[0].withMaxAge(3600)
    expectEq(t.maxAge, 3600, "retention override")
    expectEq(t.id, temp[0].id, "override keeps identity")
    expectEq(t.withMaxAge(nil).maxAge, nil, "override to no window")
}

/// Hour-level retention: a 2-hour-old file passes a 1-hour window, a fresh one doesn't.
func testHourRetention() {
    let base = NSTemporaryDirectory() + "usagebar-hours-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: base + "/agent/run", withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: base) }
    let old = base + "/agent/run/old.log", fresh = base + "/agent/fresh.log"
    FileManager.default.createFile(atPath: old, contents: Data(repeating: 1, count: 11))
    FileManager.default.createFile(atPath: fresh, contents: Data(repeating: 2, count: 22))
    try? FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -7200)], ofItemAtPath: old)

    let target = DiskCleaner.Target(id: "h", path: base, title: "h", group: .temp, maxAge: 3600)
    expectEq(DiskCleaner.size(of: target), UInt64(11), "only the 2h-old file counts")
    let r = DiskCleaner.clean([target])
    expectEq(r.freedBytes, UInt64(11), "freed the old file")
    expect(!FileManager.default.fileExists(atPath: base + "/agent/run"), "emptied subfolder pruned")
    expect(FileManager.default.fileExists(atPath: fresh), "fresh file kept")
    expect(FileManager.default.fileExists(atPath: base + "/agent"), "folder with fresh content kept")

    // Root given with a trailing slash (as confstr returns it) must still be kept.
    let slashed = DiskCleaner.Target(id: "s", path: base + "/", title: "s", group: .temp, maxAge: nil)
    _ = DiskCleaner.clean([slashed])
    expect(FileManager.default.fileExists(atPath: base), "target root kept even with trailing slash")
}

/// Build a temp tree: root/a.txt (10 B), root/sub/b.txt (20 B), root/link → a.txt.
private func makeTree() -> (root: String, tearDown: () -> Void) {
    let base = NSTemporaryDirectory() + "usagebar-cleaner-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: base + "/sub", withIntermediateDirectories: true)
    let a = base + "/a.txt", b = base + "/sub/b.txt"
    FileManager.default.createFile(atPath: a, contents: Data(repeating: 1, count: 10))
    FileManager.default.createFile(atPath: b, contents: Data(repeating: 2, count: 20))
    try? FileManager.default.removeItem(atPath: base + "/link")
    try? FileManager.default.createSymbolicLink(atPath: base + "/link", withDestinationPath: "a.txt")
    return (base, { try? FileManager.default.removeItem(atPath: base) })
}

func testCleanerSizeScan() {
    let (root, done) = makeTree()
    defer { done() }
    let target = DiskCleaner.Target(id: "t", path: root, title: "t")

    expectEq(DiskCleaner.size(of: target), UInt64(30), "size sums regular files only (symlinks 0)")
}

func testCleanerAgeRule() {
    let (root, done) = makeTree()
    defer { done() }
    // Everything was just created → older than "now - 1 day" is false → skipped.
    let fresh = DiskCleaner.Target(id: "f", path: root, title: "f", maxAgeDays: 1)
    expectEq(DiskCleaner.size(of: fresh), UInt64(0), "1-day window skips fresh files")

    // nil cutoff → everything counts.
    let all = DiskCleaner.Target(id: "a", path: root, title: "a")
    expectEq(DiskCleaner.size(of: all), UInt64(30), "nil window includes everything")

    // A file older than the window is counted.
    let old = (root as NSString).appendingPathComponent("old.txt")
    FileManager.default.createFile(atPath: old, contents: Data(repeating: 9, count: 5))
    let past = Date(timeIntervalSinceNow: -3 * 24 * 3600)
    try? FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: old)
    let window = DiskCleaner.Target(id: "w", path: root, title: "w", maxAgeDays: 1)
    expectEq(DiskCleaner.size(of: window), UInt64(5), "only the 3-day-old file passes the 1-day window")
}

func testCleanAndReport() {
    let (root, done) = makeTree()
    defer { done() }
    let target = DiskCleaner.Target(id: "t", path: root, title: "t")

    let result = DiskCleaner.clean([target])
    expectEq(result.removedCount, 2, "removed a.txt and sub/b.txt (symlink untouched, dirs pruned)")
    expectEq(result.freedBytes, UInt64(30), "freed bytes counted")
    expectEq(result.failedCount, 0, "nothing failed")
    expectEq(result.perTarget["t"], UInt64(30), "per-target freed bytes")

    expect(!FileManager.default.fileExists(atPath: root + "/a.txt"), "file gone")
    expect(!FileManager.default.fileExists(atPath: root + "/sub"), "emptied dir pruned")
    expect((try? FileManager.default.destinationOfSymbolicLink(atPath: root + "/link")) != nil, "symlink untouched")
    expect(FileManager.default.fileExists(atPath: root), "root directory itself is kept")
    expectEq(DiskCleaner.size(of: target), UInt64(0), "root empty after clean")
}

func testCleanSkipsFreshFiles() {
    let (root, done) = makeTree()
    defer { done() }
    // Everything is fresh → 1-day window skips it all → untouched.
    let target = DiskCleaner.Target(id: "t", path: root, title: "t", maxAgeDays: 1)

    let result = DiskCleaner.clean([target])
    expectEq(result.removedCount, 0, "fresh files are skipped")
    expect(FileManager.default.fileExists(atPath: root + "/a.txt"), "file still on disk")
    expect(FileManager.default.fileExists(atPath: root + "/sub/b.txt"), "nested file still on disk")
}

/// The exact /tmp scenario: a freshly-modified directory containing an old file.
/// Scan counts the old file; clean must delete it (per-file mtime), not skip the
/// whole dir because the dir node itself is fresh.
func testCleanOldFileInsideFreshDir() {
    let (root, done) = makeTree()
    defer { done() }
    let target = DiskCleaner.Target(id: "t", path: root, title: "t", maxAgeDays: 1)
    // Fresh dir keeps its new mtime; inside it an old file the scan counts.
    let old = root + "/sub/old.bin"
    FileManager.default.createFile(atPath: old, contents: Data(repeating: 9, count: 50))
    try? FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -3 * 24 * 3600)], ofItemAtPath: old)

    expectEq(DiskCleaner.size(of: target), UInt64(50), "scan counts old file inside fresh dir")
    let result = DiskCleaner.clean([target])
    expectEq(result.freedBytes, UInt64(50), "clean deletes it (scan/clean same rule)")
    expect(!FileManager.default.fileExists(atPath: old), "old file gone")
    expect(FileManager.default.fileExists(atPath: root + "/sub/b.txt"), "fresh sibling file kept")
    expect(FileManager.default.fileExists(atPath: root + "/sub"), "dir with fresh content kept")
}

/// Running apps own sockets/FIFOs in temp dirs; cleaning must not touch them
/// even when old — deleting the path would break the running process.
func testCleanLeavesSpecialFilesAlone() {
    let base = NSTemporaryDirectory() + "usagebar-sock-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: base) }

    let fifo = base + "/app.fifo"
    expectEq(mkfifo(fifo, 0o644), Int32(0), "mkfifo for probe")
    let link = base + "/link"
    try? FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: "/etc/hosts")

    let target = DiskCleaner.Target(id: "s", path: base, title: "s") // no age window
    expectEq(DiskCleaner.size(of: target), UInt64(0), "special files and symlinks not counted")
    let result = DiskCleaner.clean([target])
    expect(FileManager.default.fileExists(atPath: fifo), "fifo untouched")
    expect((try? FileManager.default.destinationOfSymbolicLink(atPath: link)) != nil, "symlink untouched")
    expectEq(result.failedCount, 0, "special files skipped, not counted as failed")
    expectEq(result.removedCount, 0, "nothing to remove")
}

/// The reported /tmp bug: scan showed bytes that clean could never delete
/// (entries inside directories the user can't write, e.g. root-owned dirs).
/// Undeletable files must be excluded from both scan and clean.
func testUndeletableFilesNotCounted() {
    let base = NSTemporaryDirectory() + "usagebar-ro-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: base + "/locked", withIntermediateDirectories: true)
    let file = base + "/locked/old.bin"
    FileManager.default.createFile(atPath: file, contents: Data(repeating: 3, count: 70))
    chmod(base + "/locked", 0o555)
    defer {
        chmod(base + "/locked", 0o755)
        try? FileManager.default.removeItem(atPath: base)
    }

    let target = DiskCleaner.Target(id: "r", path: base, title: "r")
    expectEq(DiskCleaner.size(of: target), UInt64(0), "file in unwritable dir not counted")
    let result = DiskCleaner.clean([target])
    expectEq(result.failedCount, 0, "not attempted, so no failure")
    expect(FileManager.default.fileExists(atPath: file), "file left in place")
}

/// Per-row clean of a parent must not delete nested-row subtrees (their own,
/// looser rules would be violated), while single files around them go.
func testCleanOneHonorsExclusions() {
    let base = NSTemporaryDirectory() + "usagebar-nested-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: base + "/Caches/Go", withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: base) }
    FileManager.default.createFile(atPath: base + "/Caches/Go/g.bin", contents: Data(repeating: 7, count: 40))
    FileManager.default.createFile(atPath: base + "/Caches/other.bin", contents: Data(repeating: 8, count: 60))
    let parent = DiskCleaner.Target(id: "p", path: base + "/Caches", title: "p")
    let child = DiskCleaner.Target(id: "c", path: base + "/Caches/Go", title: "c")

    // Single-row clean with the full row list as context (what cleanOne does
    // with defaultTargets in the app).
    let result = DiskCleaner.clean([parent], context: [parent, child])
    expect(FileManager.default.fileExists(atPath: base + "/Caches/Go/g.bin"), "nested row's file kept")
    expect(!FileManager.default.fileExists(atPath: base + "/Caches/other.bin"), "own file removed")
    expectEq(result.freedBytes, UInt64(60), "freed = own files only")
}

func testCleanMissingAndNested() {
    // Missing directory: scan 0, clean no-op, no crash.
    let missing = DiskCleaner.Target(id: "m", path: "/nonexistent/usagebar", title: "m")
    expectEq(DiskCleaner.size(of: missing), UInt64(0), "missing dir scans as 0")
    let r = DiskCleaner.clean([missing])
    expectEq(r.removedCount, 0, "missing dir cleans as no-op")

    // Excluded subtrees survive a parent clean.
    let base = NSTemporaryDirectory() + "usagebar-nested-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: base + "/Caches/Go", withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: base) }
    FileManager.default.createFile(atPath: base + "/Caches/Go/g.bin", contents: Data(repeating: 7, count: 40))
    FileManager.default.createFile(atPath: base + "/Caches/other.bin", contents: Data(repeating: 8, count: 60))
    let parent = DiskCleaner.Target(id: "p", path: base + "/Caches", title: "p")
    let child = DiskCleaner.Target(id: "c", path: base + "/Caches/Go", title: "c")

    let sizes = DiskCleaner.sizes(of: [parent, child])
    expectEq(sizes[parent], UInt64(60), "parent size excludes nested child row")
    expectEq(sizes[child], UInt64(40), "child row scans its own subtree")

    let result = DiskCleaner.clean([parent, child])
    expect(!FileManager.default.fileExists(atPath: base + "/Caches/Go/g.bin"), "child row cleans its own files")
    expect(FileManager.default.fileExists(atPath: base + "/Caches/Go"), "nested target dir kept")
    expect(!FileManager.default.fileExists(atPath: base + "/Caches/other.bin"), "non-nested sibling removed")
    expectEq(result.freedBytes, UInt64(100), "both rows report their own freed bytes (no overlap)")
    expectEq(result.perTarget["c"], UInt64(40), "per-target freed: child row")
    expectEq(result.perTarget["p"], UInt64(60), "per-target freed: parent row")
}
