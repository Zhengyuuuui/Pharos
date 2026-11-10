import AppKit
import Foundation
import PharosCore
import UniformTypeIdentifiers

/// Export / import of favorites and browser presets via save / open panels.
/// Only touches the file the user picks.
@MainActor
enum BackupActions {
    /// Result message for the settings banner.
    static func export() -> String? {
        let l10n = L10n.shared
        let appDelegate = NSApp.delegate as? AppDelegate
        let favorites = WorkspaceStore.shared.favorites
        let presets = ChromeStore.shared.presets
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let day = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        panel.nameFieldStringValue = "Pharos-backup-\(day).json"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            let refreshSeconds = appDelegate?.store.refreshSeconds ?? (UserDefaults.standard.integer(forKey: "refreshSeconds") > 0 ? UserDefaults.standard.integer(forKey: "refreshSeconds") : 5)
            let showSystemProcesses = appDelegate?.store.showSystem ?? UserDefaults.standard.bool(forKey: "showSystemProcesses")
            let general = GeneralSettingsBackup(
                appLanguage: L10n.shared.language.rawValue,
                refreshSeconds: refreshSeconds,
                showSystemProcesses: showSystemProcesses,
                menuBarText: MenuBarSettings.shared.text.rawValue,
                maxProjectsCapacity: MenuBarSettings.shared.maxProjects,
                maxPortsCapacity: MenuBarSettings.shared.maxPorts,
                popoverHotkey: MenuBarSettings.shared.hotkey.rawValue,
                notifyMemory: Notifier.shared.memory,
                notifyDisk: Notifier.shared.disk,
                notifyFavoriteExit: Notifier.shared.favoriteExit,
                menuBarMetrics: MenuBarSettings.shared.enabledMetrics.map(\.rawValue),
                menuBarRingMetric: MenuBarSettings.shared.ringMetric.rawValue,
                menuBarShowLabels: MenuBarSettings.shared.showMetricLabels,
                menuBarSeparator: MenuBarSettings.shared.separatorStyle.rawValue,
                notifyThermal: Notifier.shared.thermal,
                notifyBloat: Notifier.shared.bloat,
                notifyAppUpdate: Notifier.shared.appUpdate,
                notifyDiskThreshold: Notifier.shared.diskThreshold
            )
            let appearance = AppearanceSettingsBackup(
                gauge3DAcceleration: UserDefaults.standard.object(forKey: "pharos.gauge3DAcceleration") as? Bool ?? true,
                popoverGaussianBlur: UserDefaults.standard.object(forKey: "pharos.popoverGaussianBlur") as? Bool ?? true,
                trafficLightGlassTransparency: UserDefaults.standard.object(forKey: "pharos.trafficLightGlassTransparency") as? Double ?? 0.75,
                showInspector: UserDefaults.standard.object(forKey: "pharos.showInspector") as? Bool ?? true,
                fanViewMode: UserDefaults.standard.string(forKey: "pharos.fanViewMode") ?? "gauge"
            )
            let hardware = HardwareSettingsBackup(
                batteryTargetLimit: BatteryStore.shared.targetLimit,
                batteryLimitEnabled: UserDefaults.standard.bool(forKey: "batteryLimitEnabled"),
                batteryPersistentGuard: BatteryStore.shared.persistentGuard,
                batterySyncMagSafe: BatteryStore.shared.syncMagSafe,
                batteryHysteresisMargin: BatteryStore.shared.hysteresisMargin,
                fanFixedRPM: FanStore.shared.fixedRPM
            )
            let module = ModuleSettingsBackup(
                terminalApp: WorkspaceStore.shared.terminal.rawValue,
                agentEditorLayout: AgentChatStore.shared.editorLayout.rawValue,
                agentChartCollapsed: AgentChatStore.shared.chartCollapsed,
                customAgentAppPaths: AgentChatStore.shared.customAgentAppPaths,
                tempRetentionHours: CleanupStoreHolder.shared.tempRetentionHours,
                hiddenBrowsers: Array(ChromeStore.shared.hiddenBrowsers).map(\.rawValue).sorted(),
                defaultBrowser: ChromeStore.shared.defaultBrowser.rawValue
            )
            let backup = Backup(
                favorites: favorites,
                browserPresets: presets,
                popoverLayout: PopoverLayoutStore.shared.layout,
                generalSettings: general,
                appearanceSettings: appearance,
                hardwareSettings: hardware,
                moduleSettings: module
            )
            try backup.encoded().write(to: url, options: .atomic)
            return l10n.exported(favorites.count, presets.count)
        } catch {
            return l10n.backupFailed(error.localizedDescription)
        }
    }

    static func importFile() -> String? {
        let l10n = L10n.shared
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            let appDelegate = NSApp.delegate as? AppDelegate
            let backup = try Backup.decode(Data(contentsOf: url))
            let m = backup.merge(into: WorkspaceStore.shared.favorites, presets: ChromeStore.shared.presets)
            WorkspaceStore.shared.add(m.favorites)
            ChromeStore.shared.add(m.presets)
            if let layout = backup.popoverLayout {
                PopoverLayoutStore.shared.update { $0 = $0.merging(imported: layout) }
            }
            if let g = backup.generalSettings {
                if let lang = g.appLanguage, let l = AppLanguage(rawValue: lang) { L10n.shared.language = l }
                if let r = g.refreshSeconds {
                    UserDefaults.standard.set(r, forKey: "refreshSeconds")
                    appDelegate?.store.refreshSeconds = r
                }
                if let s = g.showSystemProcesses {
                    UserDefaults.standard.set(s, forKey: "showSystemProcesses")
                    appDelegate?.store.showSystem = s
                }
                if let t = g.menuBarText, let m = MenuBarText(rawValue: t) { MenuBarSettings.shared.text = m }
                if let mp = g.maxProjectsCapacity { MenuBarSettings.shared.maxProjects = mp }
                if let mp = g.maxPortsCapacity { MenuBarSettings.shared.maxPorts = mp }
                if let hk = g.popoverHotkey, let k = PopoverHotkey(rawValue: hk) { MenuBarSettings.shared.hotkey = k }
                if let mem = g.notifyMemory { Notifier.shared.memory = mem }
                if let d = g.notifyDisk { Notifier.shared.disk = d }
                if let f = g.notifyFavoriteExit { Notifier.shared.favoriteExit = f }
                if let metrics = g.menuBarMetrics {
                    MenuBarSettings.shared.enabledMetrics = metrics.compactMap(MenuBarMetric.init)
                }
                if let rm = g.menuBarRingMetric, let metric = MenuBarMetric(rawValue: rm) {
                    MenuBarSettings.shared.ringMetric = metric
                }
                if let labels = g.menuBarShowLabels {
                    MenuBarSettings.shared.showMetricLabels = labels
                }
                if let sep = g.menuBarSeparator, let separator = MenuBarSeparator(rawValue: sep) {
                    MenuBarSettings.shared.separatorStyle = separator
                }
                if let th = g.notifyThermal { Notifier.shared.thermal = th }
                if let bl = g.notifyBloat { Notifier.shared.bloat = bl }
                if let au = g.notifyAppUpdate { Notifier.shared.appUpdate = au }
                if let dt = g.notifyDiskThreshold { Notifier.shared.diskThreshold = dt }
            }
            if let a = backup.appearanceSettings {
                if let g = a.gauge3DAcceleration { UserDefaults.standard.set(g, forKey: "pharos.gauge3DAcceleration") }
                if let b = a.popoverGaussianBlur { UserDefaults.standard.set(b, forKey: "pharos.popoverGaussianBlur") }
                if let t = a.trafficLightGlassTransparency { UserDefaults.standard.set(t, forKey: "pharos.trafficLightGlassTransparency") }
                if let s = a.showInspector { UserDefaults.standard.set(s, forKey: "pharos.showInspector") }
                if let f = a.fanViewMode { UserDefaults.standard.set(f, forKey: "pharos.fanViewMode") }
            }
            if let h = backup.hardwareSettings {
                if let limit = h.batteryTargetLimit { BatteryStore.shared.targetLimit = limit }
                if let enabled = h.batteryLimitEnabled {
                    if enabled {
                        BatteryStore.shared.resumeLimit()
                    } else {
                        BatteryStore.shared.setSystemMode()
                    }
                }
                if let pg = h.batteryPersistentGuard { BatteryStore.shared.persistentGuard = pg }
                if let sm = h.batterySyncMagSafe { BatteryStore.shared.syncMagSafe = sm }
                if let hm = h.batteryHysteresisMargin { BatteryStore.shared.hysteresisMargin = hm }
                if let rpm = h.fanFixedRPM { FanStore.shared.fixedRPM = rpm }
            }
            if let mod = backup.moduleSettings {
                if let term = mod.terminalApp, let t = TerminalApp(rawValue: term) { WorkspaceStore.shared.terminal = t }
                if let layout = mod.agentEditorLayout, let l = AgentEditorLayout(rawValue: layout) { AgentChatStore.shared.editorLayout = l }
                if let collapsed = mod.agentChartCollapsed { AgentChatStore.shared.chartCollapsed = collapsed }
                if let paths = mod.customAgentAppPaths {
                    var current = AgentChatStore.shared.customAgentAppPaths
                    for p in paths where !current.contains(p) { current.append(p) }
                    AgentChatStore.shared.customAgentAppPaths = current
                }
                if let ret = mod.tempRetentionHours { CleanupStoreHolder.shared.tempRetentionHours = ret }
                if let hidden = mod.hiddenBrowsers {
                    let set = Set(hidden.compactMap(ChromiumBrowser.init))
                    ChromeStore.shared.hiddenBrowsers.formUnion(set)
                }
                if let def = mod.defaultBrowser, let b = ChromiumBrowser(rawValue: def) { ChromeStore.shared.defaultBrowser = b }
            }
            return l10n.imported(m.favorites.count, m.presets.count, m.skipped)
        } catch let e as Backup.ReadError {
            switch e {
            case .notABackup: return l10n.backupInvalid
            case .newerVersion: return l10n.backupFailed(l10n.backupInvalid)
            }
        } catch {
            return l10n.backupFailed(error.localizedDescription)
        }
    }
}
