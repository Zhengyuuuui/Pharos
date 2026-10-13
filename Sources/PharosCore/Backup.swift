import Foundation

/// Export / import file for favorites and browser presets.
public struct Backup: Codable, Sendable {
    public static let currentVersion = 1
    public static let format = "pharos-backup"

    public var format: String
    public var version: Int
    public var exportedAt: Date
    public var favorites: [Favorite]
    public var browserPresets: [ChromePreset]

    public init(favorites: [Favorite], browserPresets: [ChromePreset], exportedAt: Date = Date()) {
        format = Self.format
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.favorites = favorites
        self.browserPresets = browserPresets
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
