import Foundation

/// Export / import file for favorites, browser presets, popover layout and preferences.
public struct Backup: Codable, Sendable {
    public static let currentVersion = 1
    public static let format = "pharos-backup"

    public var format: String
    public var version: Int
    public var exportedAt: Date
    public var favorites: [Favorite]
    public var browserPresets: [ChromePreset]
    /// Optional so backups made before popover customization still import.
    public var popoverLayout: PopoverLayout?
    public var generalSettings: GeneralSettingsBackup?
    public var appearanceSettings: AppearanceSettingsBackup?
    public var hardwareSettings: HardwareSettingsBackup?
    public var moduleSettings: ModuleSettingsBackup?

    public init(
        favorites: [Favorite],
        browserPresets: [ChromePreset],
        popoverLayout: PopoverLayout? = nil,
        generalSettings: GeneralSettingsBackup? = nil,
        appearanceSettings: AppearanceSettingsBackup? = nil,
        hardwareSettings: HardwareSettingsBackup? = nil,
        moduleSettings: ModuleSettingsBackup? = nil,
        exportedAt: Date = Date()
    ) {
        format = Self.format
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.favorites = favorites
        self.browserPresets = browserPresets
        self.popoverLayout = popoverLayout
        self.generalSettings = generalSettings
        self.appearanceSettings = appearanceSettings
        self.hardwareSettings = hardwareSettings
        self.moduleSettings = moduleSettings
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return try e.encode(self)
    }

    public enum ReadError: Error, Equatable { case notABackup, newerVersion(Int) }

    public static func decode(_ data: Data) throws -> Backup {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        guard let b = try? d.decode(Backup.self, from: data), b.format == format else { throw ReadError.notABackup }
        guard b.version <= currentVersion else { throw ReadError.newerVersion(b.version) }
        return b
    }

    /// What an import adds. Existing entries win: a favorite is the same if its
    /// folder matches, a preset if its browser + profile folder match. Imported
    /// entries get fresh ids so they can't collide with local ones.
    public struct Merge: Sendable {
        public var favorites: [Favorite]
        public var presets: [ChromePreset]
        public var skipped: Int
    }

    public func merge(into favorites: [Favorite], presets: [ChromePreset]) -> Merge {
        var knownDirs = Set(favorites.map(\.directory))
        var knownProfiles = Set(presets.map { "\($0.config.browser.rawValue):\($0.config.profileKey)" })
        var skipped = 0
        var newFavorites: [Favorite] = []
        for var f in self.favorites {
            guard knownDirs.insert(f.directory).inserted else { skipped += 1; continue }
            f.id = UUID().uuidString
            newFavorites.append(f)
        }
        var newPresets: [ChromePreset] = []
        for var p in browserPresets {
            guard knownProfiles.insert("\(p.config.browser.rawValue):\(p.config.profileKey)").inserted else { skipped += 1; continue }
            p.id = UUID().uuidString
            newPresets.append(p)
        }
        return Merge(favorites: newFavorites, presets: newPresets, skipped: skipped)
    }
}

public struct GeneralSettingsBackup: Codable, Sendable, Equatable {
    public var appLanguage: String?
    public var refreshSeconds: Int?
    public var showSystemProcesses: Bool?
    public var menuBarText: String?
    public var maxProjectsCapacity: Int?
    public var maxPortsCapacity: Int?
    public var popoverHotkey: String?
    public var notifyMemory: Bool?
    public var notifyDisk: Bool?
    public var notifyFavoriteExit: Bool?

    public init(
        appLanguage: String? = nil,
        refreshSeconds: Int? = nil,
        showSystemProcesses: Bool? = nil,
        menuBarText: String? = nil,
        maxProjectsCapacity: Int? = nil,
        maxPortsCapacity: Int? = nil,
        popoverHotkey: String? = nil,
        notifyMemory: Bool? = nil,
        notifyDisk: Bool? = nil,
        notifyFavoriteExit: Bool? = nil
    ) {
        self.appLanguage = appLanguage
        self.refreshSeconds = refreshSeconds
        self.showSystemProcesses = showSystemProcesses
        self.menuBarText = menuBarText
        self.maxProjectsCapacity = maxProjectsCapacity
        self.maxPortsCapacity = maxPortsCapacity
        self.popoverHotkey = popoverHotkey
        self.notifyMemory = notifyMemory
        self.notifyDisk = notifyDisk
        self.notifyFavoriteExit = notifyFavoriteExit
    }
}

public struct AppearanceSettingsBackup: Codable, Sendable, Equatable {
    public var gauge3DAcceleration: Bool?
    public var popoverGaussianBlur: Bool?
    public var trafficLightGlassTransparency: Double?
    public var showInspector: Bool?
    public var fanViewMode: String?

    public init(
        gauge3DAcceleration: Bool? = nil,
        popoverGaussianBlur: Bool? = nil,
        trafficLightGlassTransparency: Double? = nil,
        showInspector: Bool? = nil,
        fanViewMode: String? = nil
    ) {
        self.gauge3DAcceleration = gauge3DAcceleration
        self.popoverGaussianBlur = popoverGaussianBlur
        self.trafficLightGlassTransparency = trafficLightGlassTransparency
        self.showInspector = showInspector
        self.fanViewMode = fanViewMode
    }
}

public struct HardwareSettingsBackup: Codable, Sendable, Equatable {
    public var batteryTargetLimit: Int?
    public var batteryLimitEnabled: Bool?
    public var batteryPersistentGuard: Bool?
    public var batterySyncMagSafe: Bool?
    public var fanFixedRPM: Int?

    public init(
        batteryTargetLimit: Int? = nil,
        batteryLimitEnabled: Bool? = nil,
        batteryPersistentGuard: Bool? = nil,
        batterySyncMagSafe: Bool? = nil,
        fanFixedRPM: Int? = nil
    ) {
        self.batteryTargetLimit = batteryTargetLimit
        self.batteryLimitEnabled = batteryLimitEnabled
        self.batteryPersistentGuard = batteryPersistentGuard
        self.batterySyncMagSafe = batterySyncMagSafe
        self.fanFixedRPM = fanFixedRPM
    }
}

public struct ModuleSettingsBackup: Codable, Sendable, Equatable {
    public var terminalApp: String?
    public var agentEditorLayout: String?
    public var agentChartCollapsed: Bool?
    public var customAgentAppPaths: [String]?
    public var tempRetentionHours: Int?
    public var hiddenBrowsers: [String]?
    public var defaultBrowser: String?

    public init(
        terminalApp: String? = nil,
        agentEditorLayout: String? = nil,
        agentChartCollapsed: Bool? = nil,
        customAgentAppPaths: [String]? = nil,
        tempRetentionHours: Int? = nil,
        hiddenBrowsers: [String]? = nil,
        defaultBrowser: String? = nil
    ) {
        self.terminalApp = terminalApp
        self.agentEditorLayout = agentEditorLayout
        self.agentChartCollapsed = agentChartCollapsed
        self.customAgentAppPaths = customAgentAppPaths
        self.tempRetentionHours = tempRetentionHours
        self.hiddenBrowsers = hiddenBrowsers
        self.defaultBrowser = defaultBrowser
    }
}
