import Foundation
import PharosCore

func testHomebrewMultiVersionAndCache() {
    let tempPrefix = NSTemporaryDirectory() + "pharos-brew-\(UUID().uuidString)"
    let cellar = tempPrefix + "/Cellar/node"
    let optNode = tempPrefix + "/opt/node"
    defer { try? FileManager.default.removeItem(atPath: tempPrefix) }

    try? FileManager.default.createDirectory(atPath: cellar + "/20.10.0", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: cellar + "/22.1.0", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: tempPrefix + "/opt", withIntermediateDirectories: true)

    // Symlink opt/node to 22.1.0 (active version)
    try? FileManager.default.createSymbolicLink(atPath: optNode, withDestinationPath: "../Cellar/node/22.1.0")

    FileManager.default.createFile(atPath: cellar + "/20.10.0/node", contents: Data(repeating: 1, count: 2048))
    FileManager.default.createFile(atPath: cellar + "/22.1.0/node", contents: Data(repeating: 2, count: 4096))

    let cleanables = HomebrewCleaner.scanCleanables(prefix: tempPrefix, home: tempPrefix)

    // 20.10.0 should be marked obsolete, 22.1.0 kept
    let oldCellar = cleanables.filter { $0.type == .oldCellarVersion }
    expectEq(oldCellar.count, 1, "found 1 obsolete version")
    expectEq(oldCellar.first?.version, "20.10.0", "obsolete version is 20.10.0")

    // Test cleaning the obsolete version
    if let oldItem = oldCellar.first {
        let cleaned = (try? HomebrewCleaner.cleanItem(oldItem, prefix: tempPrefix, home: tempPrefix)) ?? false
        expect(cleaned, "cleanItem succeeded")
        expect(!FileManager.default.fileExists(atPath: oldItem.path), "old version removed")
        expect(FileManager.default.fileExists(atPath: cellar + "/22.1.0"), "active version kept")
    }
}
