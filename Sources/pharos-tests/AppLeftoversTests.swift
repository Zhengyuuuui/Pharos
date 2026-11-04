import Foundation
import PharosCore

func testAppLeftoversWhitelist() {
    expect(AppLeftoversScanner.isWhitelisted("com.apple.safari"), "com.apple prefix whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("com.apple.finder"), "finder whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("apple"), "apple whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("pharos"), "pharos whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("local.pharos.fand"), "local.pharos whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("docker"), "docker cli whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("git"), "git whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("homebrew"), "homebrew whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("ollama"), "ollama whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("apsd"), "system daemon apsd whitelisted")

    // Core developer, browser & system directories
    expect(AppLeftoversScanner.isWhitelisted("code"), "Code (VS Code) whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("clouddocs"), "CloudDocs whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("mobilesync"), "MobileSync whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("google"), "Google whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("google/chrome"), "Google/Chrome whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("bravesoftware"), "BraveSoftware whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("microsoft edge"), "Microsoft Edge whitelisted")
    expect(AppLeftoversScanner.isWhitelisted("jetbrains"), "JetBrains whitelisted")

    // Unknown app should NOT be whitelisted
    expect(!AppLeftoversScanner.isWhitelisted("com.random.uninstalledapp"), "random app not whitelisted")
    expect(!AppLeftoversScanner.isWhitelisted("oldabandonedgame"), "random game not whitelisted")
}

func testAppLeftoversScanningAndCleaning() {
    let tempHome = NSTemporaryDirectory() + "pharos-leftovers-\(UUID().uuidString)"
    let appSupport = tempHome + "/Library/Application Support"
    let savedState = tempHome + "/Library/Saved Application State"
    defer { try? FileManager.default.removeItem(atPath: tempHome) }

    try? FileManager.default.createDirectory(atPath: appSupport + "/InstalledApp", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: appSupport + "/UninstalledApp", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: appSupport + "/Code", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: appSupport + "/CloudDocs", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: appSupport + "/MobileSync", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: savedState + "/com.uninstalled.app.savedState", withIntermediateDirectories: true)

    // Put some dummy data (> 1KB) so scanner picks them up
    FileManager.default.createFile(atPath: appSupport + "/InstalledApp/db.sqlite", contents: Data(repeating: 1, count: 2048))
    FileManager.default.createFile(atPath: appSupport + "/UninstalledApp/data.bin", contents: Data(repeating: 2, count: 4096))
    FileManager.default.createFile(atPath: appSupport + "/Code/settings.json", contents: Data(repeating: 3, count: 2048))
    FileManager.default.createFile(atPath: appSupport + "/CloudDocs/meta.bin", contents: Data(repeating: 4, count: 2048))
    FileManager.default.createFile(atPath: appSupport + "/MobileSync/backup.bin", contents: Data(repeating: 5, count: 2048))
    FileManager.default.createFile(atPath: savedState + "/com.uninstalled.app.savedState/state.plist", contents: Data(repeating: 6, count: 2048))

    let installed = [
        AppLeftoversScanner.InstalledAppInfo(name: "InstalledApp", bundleId: "com.installed.app", path: "/Applications/InstalledApp.app")
    ]

    let leftovers = AppLeftoversScanner.scanLeftovers(installedApps: installed, home: tempHome)

    // UninstalledApp and com.uninstalled.app.savedState should be detected, InstalledApp, Code, CloudDocs, MobileSync should be ignored
    expectEq(leftovers.count, 2, "detected 2 orphaned leftovers")
    expect(leftovers.contains { $0.appName == "UninstalledApp" }, "detected UninstalledApp leftover")
    expect(leftovers.contains { $0.appName == "com.uninstalled.app" }, "detected savedState leftover")
    expect(!leftovers.contains { $0.appName == "InstalledApp" }, "InstalledApp excluded")
    expect(!leftovers.contains { $0.appName == "Code" }, "Code excluded by whitelist")
    expect(!leftovers.contains { $0.appName == "CloudDocs" }, "CloudDocs excluded by whitelist")
    expect(!leftovers.contains { $0.appName == "MobileSync" }, "MobileSync excluded by whitelist")

    // Test safe deletion
    if let uninstalledItem = leftovers.first(where: { $0.appName == "UninstalledApp" }) {
        let deleted = (try? AppLeftoversScanner.deleteLeftover(uninstalledItem, toTrash: false, home: tempHome)) ?? false
        expect(deleted, "deleteLeftover succeeded")
        expect(!FileManager.default.fileExists(atPath: uninstalledItem.path), "uninstalled directory removed")
    }
}
