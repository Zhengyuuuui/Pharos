import Darwin
import Foundation

/// Scans and cleans Homebrew download caches and obsolete Cellar/Cask versions.
///
/// Over time, Homebrew stores:
/// - Downloaded bottle tarballs in `~/Library/Caches/Homebrew/downloads`
/// - Old formula versions in `/opt/homebrew/Cellar/<formula>/<old_version>`
/// - Old cask versions in `/opt/homebrew/Caskroom/<cask>/<old_version>`
///
/// HomebrewCleaner safely detects outdated versions and caches, calculates sizes,
/// and allows releasing gigabytes of disk space without affecting active tools.
public enum HomebrewCleaner {

    public enum ItemType: String, Sendable, CaseIterable {
        case downloadCache = "Download Cache"
        case oldCellarVersion = "Old Formula Version"
        case oldCaskVersion = "Old Cask Version"

        public var localizedKey: String {
            switch self {
            case .downloadCache: return "homebrewDownloadCache"
            case .oldCellarVersion: return "homebrewOldCellarVersion"
            case .oldCaskVersion: return "homebrewOldCaskVersion"
            }
        }
    }

    public struct HomebrewCleanItem: Identifiable, Hashable, Sendable {
        public var id: String { path }
        public let name: String
        public let type: ItemType
        public let path: String
        public let size: UInt64
        public let version: String?
        public let lastModified: Date?

        public init(
            name: String,
            type: ItemType,
            path: String,
            size: UInt64,
            version: String?,
            lastModified: Date?
        ) {
            self.name = name
            self.type = type
            self.path = path
            self.size = size
            self.version = version
            self.lastModified = lastModified
        }
    }

    // MARK: - Prefix Discovery

    /// Resolves Homebrew installation prefix (/opt/homebrew for Apple Silicon, /usr/local for Intel).
    public static func brewPrefix() -> String? {
        if let env = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"],
           FileManager.default.fileExists(atPath: env) {
            return env
        }
        if FileManager.default.fileExists(atPath: "/opt/homebrew") {
            return "/opt/homebrew"
        }
        if FileManager.default.fileExists(atPath: "/usr/local/Cellar") {
            return "/usr/local"
        }
        return nil
    }

    // MARK: - Scanning

    /// Scans for cleanable Homebrew caches and obsolete versions.
    public static func scanCleanables(
        prefix: String? = brewPrefix(),
        home: String = NSHomeDirectory()
    ) -> [HomebrewCleanItem] {
        var results: [HomebrewCleanItem] = []

        // 1. Download caches (~/Library/Caches/Homebrew/downloads or ~/Library/Caches/Homebrew)
        let homebrewCacheDir = ((home as NSString).appendingPathComponent("Library") as NSString)
            .appendingPathComponent("Caches/Homebrew")
        if FileManager.default.fileExists(atPath: homebrewCacheDir) {
            let downloadsDir = (homebrewCacheDir as NSString).appendingPathComponent("downloads")
            let scanDir = FileManager.default.fileExists(atPath: downloadsDir) ? downloadsDir : homebrewCacheDir
            if let entries = try? FileManager.default.contentsOfDirectory(atPath: scanDir) {
                for entry in entries {
                    if entry.hasPrefix(".") { continue }
                    let fullPath = (scanDir as NSString).appendingPathComponent(entry)
                    var st = stat()
                    guard lstat(fullPath, &st) == 0 else { continue }
                    let isDir = (st.st_mode & S_IFMT) == S_IFDIR
                    let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))

                    let itemSize: UInt64
                    if isDir {
                        let (dirSize, _) = PackageScanner.directorySize(at: fullPath, maxFiles: 5000)
                        itemSize = dirSize
                    } else {
                        itemSize = UInt64(st.st_size)
                    }

                    if itemSize > 1024 {
                        results.append(HomebrewCleanItem(
                            name: entry,
                            type: .downloadCache,
                            path: fullPath,
                            size: itemSize,
                            version: nil,
                            lastModified: mtime
                        ))
                    }
                }
            }
        }

        // 2. Old Cellar formula versions
        if let p = prefix {
            let cellarDir = (p as NSString).appendingPathComponent("Cellar")
            results.append(contentsOf: scanOldVersions(parentDir: cellarDir, type: .oldCellarVersion, prefix: p))

            // 3. Old Caskroom cask versions
            let caskroomDir = (p as NSString).appendingPathComponent("Caskroom")
            results.append(contentsOf: scanOldVersions(parentDir: caskroomDir, type: .oldCaskVersion, prefix: p))
        }

        return results.sorted { $0.size > $1.size }
    }

    private static func scanOldVersions(parentDir: String, type: ItemType, prefix: String) -> [HomebrewCleanItem] {
        guard FileManager.default.fileExists(atPath: parentDir),
              let formulaDirs = try? FileManager.default.contentsOfDirectory(atPath: parentDir) else {
            return []
        }

        var oldItems: [HomebrewCleanItem] = []

        for formula in formulaDirs {
            if formula.hasPrefix(".") { continue }
            let formulaPath = (parentDir as NSString).appendingPathComponent(formula)
            guard let versionEntries = try? FileManager.default.contentsOfDirectory(atPath: formulaPath) else {
                continue
            }

            let validVersions = versionEntries.filter { !$0.hasPrefix(".") }
            // If only 1 version exists, it is active and cannot be cleaned!
            guard validVersions.count > 1 else { continue }

            // Find active version by checking symlink in opt/<formula>
            let optLink = ((prefix as NSString).appendingPathComponent("opt") as NSString).appendingPathComponent(formula)
            var activeVersion: String? = nil
            if let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: optLink) {
                activeVersion = (dest as NSString).lastPathComponent
            }

            // Gather stats for all versions
            var versionTuples: [(name: String, path: String, mtime: Date, size: UInt64)] = []
            for ver in validVersions {
                let verPath = (formulaPath as NSString).appendingPathComponent(ver)
                var st = stat()
                guard lstat(verPath, &st) == 0 else { continue }
                let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
                let (size, _) = PackageScanner.directorySize(at: verPath, maxFiles: 10_000)
                versionTuples.append((name: ver, path: verPath, mtime: mtime, size: size))
            }

            // Sort versions by mtime descending (most recent first)
            versionTuples.sort { $0.mtime > $1.mtime }

            // Determine which versions are obsolete
            for tuple in versionTuples {
                // If this is the active version link destination, keep it!
                if let active = activeVersion, tuple.name == active {
                    continue
                }
                // If activeVersion was unknown, keep the newest version (first in sorted list)
                if activeVersion == nil && tuple.name == versionTuples.first?.name {
                    continue
                }

                // This is an obsolete previous version!
                oldItems.append(HomebrewCleanItem(
                    name: formula,
                    type: type,
                    path: tuple.path,
                    size: tuple.size,
                    version: tuple.name,
                    lastModified: tuple.mtime
                ))
            }
        }

        return oldItems
    }

    // MARK: - Cleaning

    /// Deletes a cleanable Homebrew item safely.
    @discardableResult
    public static func cleanItem(
        _ item: HomebrewCleanItem,
        prefix: String? = brewPrefix(),
        home: String = NSHomeDirectory()
    ) throws -> Bool {
        let path = item.path
        let brewCache = ((home as NSString).appendingPathComponent("Library") as NSString).appendingPathComponent("Caches/Homebrew")
        var allowedPrefixes = [brewCache, "/opt/homebrew/Cellar", "/opt/homebrew/Caskroom", "/usr/local/Cellar", "/usr/local/Caskroom"]
        if let p = prefix {
            allowedPrefixes.append((p as NSString).appendingPathComponent("Cellar"))
            allowedPrefixes.append((p as NSString).appendingPathComponent("Caskroom"))
        }

        var isAllowed = false
        for allowed in allowedPrefixes {
            if path.hasPrefix(allowed + "/") || path == allowed {
                isAllowed = true
                break
            }
        }
        guard isAllowed, !path.contains("..") else { return false }
        guard FileManager.default.fileExists(atPath: path) else { return false }

        try FileManager.default.removeItem(atPath: path)
        return true
    }

    /// Batch cleans items.
    public static func cleanAll(_ items: [HomebrewCleanItem]) -> (freedBytes: UInt64, removedCount: Int, failedCount: Int) {
        var freed: UInt64 = 0
        var removed = 0
        var failed = 0

        for item in items {
            do {
                if try cleanItem(item) {
                    freed += item.size
                    removed += 1
                } else {
                    failed += 1
                }
            } catch {
                failed += 1
            }
        }

        return (freed, removed, failed)
    }
}
