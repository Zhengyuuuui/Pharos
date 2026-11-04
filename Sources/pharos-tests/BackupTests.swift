import Foundation
import PharosCore

func testBackup() {
    let fav = Favorite(name: "web", directory: "/Users/me/web", command: "pnpm run dev", commandSource: .detected,
                       lastPorts: [3000], addedAt: Date(timeIntervalSince1970: 1_700_000_000))
    let preset = ChromePreset(name: "edge", config: ChromeConfig(browser: .edge, userDataDir: "/Users/me/e", debugPort: 9500))
    let backup = Backup(favorites: [fav], browserPresets: [preset], exportedAt: Date(timeIntervalSince1970: 1_700_000_000))

    let data = try? backup.encoded()
    let back = data.flatMap { try? Backup.decode($0) }
    expectEq(back?.favorites, [fav], "favorites round-trip")
    expectEq(back?.browserPresets, [preset], "presets round-trip incl. browser")

    var threw: Backup.ReadError?
    do { _ = try Backup.decode(Data(#"{"hello":1}"#.utf8)) } catch { threw = error as? Backup.ReadError }
    expectEq(threw, .notABackup, "random JSON rejected")
    let future = String(decoding: data ?? Data(), as: UTF8.self).replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 9")
    do { _ = try Backup.decode(Data(future.utf8)) } catch { threw = error as? Backup.ReadError }
    expectEq(threw, .newerVersion(9), "newer backup version rejected")

    let other = Favorite(name: "api", directory: "/Users/me/api", command: "make run", commandSource: .custom)
    let incoming = Backup(favorites: [fav, other], browserPresets: [preset])
    let m = incoming.merge(into: [fav], presets: [preset])
    expectEq(m.favorites.map(\.directory), ["/Users/me/api"], "only new folders added")
    expectEq(m.presets.count, 0, "same browser + profile skipped")
    expectEq(m.skipped, 2, "skipped count")
    expect(m.favorites.first?.id != other.id, "imported entries get fresh ids")

    var custom = PopoverLayout.standard
    custom.insert(.favorites, into: .overview, before: .memory)
    let withLayout = try? Backup(favorites: [], browserPresets: [], popoverLayout: custom).encoded()
    expectEq(withLayout.flatMap { try? Backup.decode($0) }?.popoverLayout, custom, "popover layout round-trips")
    let old = String(decoding: data ?? Data(), as: UTF8.self)
    expectEq((try? Backup.decode(Data(old.utf8)))?.popoverLayout, nil, "backups without a layout still import")

    let gen = GeneralSettingsBackup(appLanguage: "zh-Hans", refreshSeconds: 10, showSystemProcesses: true, menuBarText: "both", maxProjectsCapacity: 50, maxPortsCapacity: 100, popoverHotkey: "optCmdP", notifyMemory: true, notifyDisk: false, notifyFavoriteExit: true)
    let app = AppearanceSettingsBackup(gauge3DAcceleration: false, popoverGaussianBlur: true, trafficLightGlassTransparency: 0.8, showInspector: false, fanViewMode: "bars")
    let hw = HardwareSettingsBackup(batteryTargetLimit: 85, batteryLimitEnabled: true, batteryPersistentGuard: true, batterySyncMagSafe: false, fanFixedRPM: 4200)
    let mod = ModuleSettingsBackup(terminalApp: "warp", agentEditorLayout: "list", agentChartCollapsed: true, customAgentAppPaths: ["/Applications/MyEditor.app"], tempRetentionHours: 48, hiddenBrowsers: ["brave"], defaultBrowser: "edge")
    let fullBackup = Backup(favorites: [fav], browserPresets: [preset], popoverLayout: custom, generalSettings: gen, appearanceSettings: app, hardwareSettings: hw, moduleSettings: mod)
    let fullData = try? fullBackup.encoded()
    let decodedFull = fullData.flatMap { try? Backup.decode($0) }
    expectEq(decodedFull?.generalSettings, gen, "generalSettings round-trips")
    expectEq(decodedFull?.appearanceSettings, app, "appearanceSettings round-trips")
    expectEq(decodedFull?.hardwareSettings, hw, "hardwareSettings round-trips")
    expectEq(decodedFull?.moduleSettings, mod, "moduleSettings round-trips")

    let localLayout = PopoverLayout(overview: [.memory, .disk], projects: [.projects])
    let importedLayout = PopoverLayout(overview: [.memory, .thermals], projects: [.browsers, .projects])
    let mergedLayout = localLayout.merging(imported: importedLayout)
    expectEq(mergedLayout.overview, [.memory, .disk, .thermals], "overview incrementally merged without reordering")
    expectEq(mergedLayout.projects, [.projects, .browsers], "projects incrementally merged without reordering")
}
