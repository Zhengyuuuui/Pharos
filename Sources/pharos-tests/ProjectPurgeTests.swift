import Foundation
import PharosCore

func testProjectPurgeScanningAndPurging() {
    let tempRoot = NSTemporaryDirectory() + "pharos-purge-\(UUID().uuidString)"
    let nodeProject = tempRoot + "/web-app"
    let rustProject = tempRoot + "/rust-cli"
    defer { try? FileManager.default.removeItem(atPath: tempRoot) }

    try? FileManager.default.createDirectory(atPath: nodeProject + "/node_modules/lodash", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: rustProject + "/target/debug", withIntermediateDirectories: true)

    // Create files > 100KB
    let dummy120KB = Data(repeating: 1, count: 120 * 1024)
    FileManager.default.createFile(atPath: nodeProject + "/node_modules/lodash/index.js", contents: dummy120KB)
    FileManager.default.createFile(atPath: rustProject + "/target/debug/app.o", contents: dummy120KB)

    // Set mtime to 30 days ago for nodeProject to test dormancy
    let thirtyDaysAgo = Date(timeIntervalSinceNow: -30 * 86_400)
    try? FileManager.default.setAttributes([.modificationDate: thirtyDaysAgo], ofItemAtPath: nodeProject + "/node_modules")

    let bundles = ProjectPurgeScanner.scanPurgeableBundles(
        searchRoots: [tempRoot],
        maxDepth: 3,
        dormantDays: 14,
        minSizeThreshold: 50 * 1024
    )

    expectEq(bundles.count, 2, "found both node_modules and target")
    guard let nodeBundle = bundles.first(where: { $0.bundleType == .nodeModules }),
          let rustBundle = bundles.first(where: { $0.bundleType == .rustTarget }) else {
        expect(false, "expected bundles not found")
        return
    }

    expect(nodeBundle.isDormant, "30-day-old node_modules is flagged dormant")
    expect(!rustBundle.isDormant, "freshly created target is not dormant")

    // Test single purge
    let singleFreed = (try? ProjectPurgeScanner.purgeBundle(rustBundle)) ?? false
    expect(singleFreed, "single bundle purge succeeded")
    expect(!FileManager.default.fileExists(atPath: rustBundle.bundlePath), "target directory removed")

    // Test batch purge
    let (freed, count, failed) = ProjectPurgeScanner.purgeBundles([nodeBundle])
    expect(freed >= 120 * 1024, "freed >= 120KB")
    expectEq(count, 1, "purged 1 bundle")
    expectEq(failed, 0, "0 failed")
    expect(!FileManager.default.fileExists(atPath: nodeBundle.bundlePath), "node_modules removed")
}
