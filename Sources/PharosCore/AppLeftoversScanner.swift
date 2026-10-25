import Darwin
import Foundation

/// Scans for leftover application files (data directories left behind after an app is uninstalled).
///
/// Apps on macOS often store persistent configurations, databases, and cached assets in:
/// - `~/Library/Application Support/`
/// - `~/Library/Saved Application State/`
/// - `~/Library/Containers/`
/// - `~/Library/WebKit/`
/// - `~/Library/HTTPStorages/`
///
/// When an app is dragged to Trash, macOS leaves these behind. AppLeftoversScanner
/// identifies installed apps across `/Applications`, `/System/Applications`, `~/Applications`,
/// cross-references against candidate paths, applies a comprehensive Apple & developer
/// whitelist, and reports orphaned storage with sizes.
public enum AppLeftoversScanner {

    public enum Category: String, Sendable, CaseIterable {
        case applicationSupport = "Application Support"
        case savedState = "Saved State"
        case containers = "Containers"
        case webKit = "WebKit"
        case httpStorages = "HTTP Storages"
    }

    public struct LeftoverItem: Identifiable, Hashable, Sendable {
        public var id: String { path }
        public let appName: String
        public let bundleId: String?
        public let category: Category
        public let path: String
        public let size: UInt64
        public let lastModified: Date?

        public init(appName: String, bundleId: String?, category: Category, path: String, size: UInt64, lastModified: Date?) {
            self.appName = appName
            self.bundleId = bundleId
            self.category = category
            self.path = path
            self.size = size
            self.lastModified = lastModified
        }
    }

    public struct InstalledAppInfo: Sendable {
        public let name: String
        public let bundleId: String?
        public let path: String

        public init(name: String, bundleId: String?, path: String) {
            self.name = name
            self.bundleId = bundleId
            self.path = path
        }
    }

    // MARK: - Whitelist

    /// Well-known system frameworks, CLI tools, system daemons, and runtimes that do not reside in /Applications.
    public static let knownSystemAndCliIdentifiers: Set<String> = [
        // System and Apple services
        "apple", "com.apple", "cloudkit", "addressbook", "callhistory", "crashreporter",
        "icloud", "facetime", "maps", "quicklook", "messages", "photos", "safari",
        "siri", "spotlight", "syncservices", "voicememos", "weather", "dock", "finder",
        "systemsettings", "textinput", "knowledge", "biome", "accounts", "reminders",
        "notes", "mail", "calendar", "fontbook", "keychain", "security", "bluetooth",
        "accessibility", "speech", "spindump", "audiocomponent", "coredata",

        // Developer tools, CLIs, package managers & runtimes
        "pharos", "local.pharos",
        "git", "homebrew", "brew", "ollama", "docker", "colima",
        "npm", "nvm", "pnpm", "yarn", "bun",
        "cargo", "rustup", "go", "pip", "uv", "poetry", "conda", "miniforge3",
        "virtualenv", "virtualenvs",
        "bash", "zsh", "fish", "tmux", "gnupg", "gpg", "ssh",
        "claude", "aider", "opencode", "trae", "cursor", "vscode", "visual studio code",
        "windsurf", "sublime text", "neovim", "vim", "emacs",
        "xcode", "simulator", "developer", "instruments",
        "android", "androidstudio", "flutter", "java", "openjdk", "gradle", "maven"
    ]

    // MARK: - Installed Apps Discovery

    /// Scans standard application directories for installed applications.
    public static func scanInstalledApps(
        customSearchPaths: [String]? = nil,
        home: String = NSHomeDirectory()
    ) -> [InstalledAppInfo] {
        let appDirs = customSearchPaths ?? [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/Applications/Utilities",
            (home as NSString).appendingPathComponent("Applications")
        ]

        var apps: [InstalledAppInfo] = []
        for dir in appDirs {
            guard FileManager.default.fileExists(atPath: dir) else { continue }
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents {
                guard item.hasSuffix(".app") else { continue }
                let appPath = (dir as NSString).appendingPathComponent(item)
                let nameWithoutExt = String(item.dropLast(4))

                // Parse Info.plist for bundle identifier if present
                let plistPath = ((appPath as NSString).appendingPathComponent("Contents") as NSString).appendingPathComponent("Info.plist")
                var bundleId: String? = nil
                if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                    bundleId = plist["CFBundleIdentifier"] as? String
                }

                apps.append(InstalledAppInfo(name: nameWithoutExt, bundleId: bundleId, path: appPath))
            }
        }
        return apps
    }

    // MARK: - Leftovers Scanning

    /// Scans candidate directories for leftovers of uninstalled applications.
    public static func scanLeftovers(
        installedApps: [InstalledAppInfo]? = nil,
        home: String = NSHomeDirectory(),
        maxFilesPerDirectory: Int = 10_000
    ) -> [LeftoverItem] {
        let installed = installedApps ?? scanInstalledApps(home: home)
        let installedNames = Set(installed.map { $0.name.lowercased() })
        let installedBundleIds = Set(installed.compactMap { $0.bundleId?.lowercased() })

        var leftovers: [LeftoverItem] = []

        // 1. Application Support
        let appSupportDir = ((home as NSString).appendingPathComponent("Library") as NSString).appendingPathComponent("Application Support")
        leftovers.append(contentsOf: scanFolderForLeftovers(
            directory: appSupportDir,
            category: .applicationSupport,
            installedNames: installedNames,
            installedBundleIds: installedBundleIds,
            maxFiles: maxFilesPerDirectory
        ))

        // 2. Saved Application State
        let savedStateDir = ((home as NSString).appendingPathComponent("Library") as NSString).appendingPathComponent("Saved Application State")
        leftovers.append(contentsOf: scanFolderForLeftovers(
            directory: savedStateDir,
            category: .savedState,
            installedNames: installedNames,
            installedBundleIds: installedBundleIds,
            suffixToStrip: ".savedState",
            maxFiles: maxFilesPerDirectory
        ))

        // 3. Containers
        let containersDir = ((home as NSString).appendingPathComponent("Library") as NSString).appendingPathComponent("Containers")
        leftovers.append(contentsOf: scanFolderForLeftovers(
            directory: containersDir,
            category: .containers,
            installedNames: installedNames,
            installedBundleIds: installedBundleIds,
            maxFiles: maxFilesPerDirectory
        ))

        // 4. WebKit
        let webKitDir = ((home as NSString).appendingPathComponent("Library") as NSString).appendingPathComponent("WebKit")
        leftovers.append(contentsOf: scanFolderForLeftovers(
            directory: webKitDir,
            category: .webKit,
            installedNames: installedNames,
            installedBundleIds: installedBundleIds,
            maxFiles: maxFilesPerDirectory
        ))

        // 5. HTTPStorages
        let httpStoragesDir = ((home as NSString).appendingPathComponent("Library") as NSString).appendingPathComponent("HTTPStorages")
        leftovers.append(contentsOf: scanFolderForLeftovers(
            directory: httpStoragesDir,
            category: .httpStorages,
            installedNames: installedNames,
            installedBundleIds: installedBundleIds,
            maxFiles: maxFilesPerDirectory
        ))

        // Sort descending by size
        return leftovers.sorted { $0.size > $1.size }
    }

    private static func scanFolderForLeftovers(
        directory: String,
        category: Category,
        installedNames: Set<String>,
        installedBundleIds: Set<String>,
        suffixToStrip: String? = nil,
        maxFiles: Int
    ) -> [LeftoverItem] {
        guard FileManager.default.fileExists(atPath: directory),
              let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return []
        }

        var results: [LeftoverItem] = []

        for entry in entries {
            if entry.hasPrefix(".") { continue }

            var identifier = entry
            if let suffix = suffixToStrip, identifier.hasSuffix(suffix) {
                identifier = String(identifier.dropLast(suffix.count))
            }
            let lower = identifier.lowercased()

            // Check if whitelisted
            if isWhitelisted(lower) {
                continue
            }

            // Check if matching any installed app name or bundle id
            if installedNames.contains(lower) {
                continue
            }
            if installedBundleIds.contains(lower) {
                continue
            }

            // Name matching:
            // Matches exact name, name with .app suffix, or name separated by whitespace/punctuation
            var isInstalled = false
            for appName in installedNames {
                if lower == appName ||
                   lower == appName + ".app" ||
                   lower.hasPrefix(appName + " ") ||
                   lower.hasSuffix(" " + appName) ||
                   lower.hasPrefix(appName + "-") ||
                   lower.hasSuffix("-" + appName) {
                    isInstalled = true
                    break
                }
            }
            if isInstalled { continue }

            // Bundle ID matching:
            // e.g. entry is "com.google.Chrome" or "Chrome", matching bundleId "com.google.chrome"
            for bundleId in installedBundleIds {
                if lower == bundleId ||
                   bundleId.hasSuffix("." + lower) ||
                   bundleId.contains("." + lower + ".") ||
                   lower.hasPrefix(bundleId + ".") {
                    isInstalled = true
                    break
                }
            }
            if isInstalled { continue }

            // Candidate leftover! Calculate size and stat
            let fullPath = (directory as NSString).appendingPathComponent(entry)
            var st = stat()
            guard lstat(fullPath, &st) == 0 else { continue }
            let isDir = (st.st_mode & S_IFMT) == S_IFDIR
            let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))

            var itemSize: UInt64 = 0
            if isDir {
                let (dirSize, _) = PackageScanner.directorySize(at: fullPath, maxFiles: maxFiles)
                itemSize = dirSize
            } else {
                itemSize = UInt64(st.st_size)
            }

            // Only report items with non-zero or meaningful size (> 1KB) to avoid empty placeholder noise
            if itemSize > 1024 {
                let displayName = suffixToStrip != nil ? identifier : entry
                let inferredBundleId = entry.contains(".") ? entry : nil
                results.append(LeftoverItem(
                    appName: displayName,
                    bundleId: inferredBundleId,
                    category: category,
                    path: fullPath,
                    size: itemSize,
                    lastModified: mtime
                ))
            }
        }

        return results
    }

    /// Determines whether an entry name or bundle identifier is protected by system/developer whitelist.
    public static func isWhitelisted(_ lower: String) -> Bool {
        // Direct apple / system prefixes
        if lower.hasPrefix("com.apple.") || lower.hasPrefix("apple.") || lower == "apple" {
            return true
        }

        // Match against known system and CLI identifiers
        for known in knownSystemAndCliIdentifiers {
            if lower == known || lower.hasPrefix(known + ".") || lower.hasPrefix(known + "-") || lower.hasSuffix("." + known) {
                return true
            }
        }

        // macOS system daemons typically end in "d" (e.g. apsd, cloudd, spindump, notifyd, cfprefsd)
        let systemDaemons: Set<String> = [
            "apsd", "cloudd", "sharingd", "trustd", "nsurlsessiond", "callservicesd",
            "bird", "identityservicesd", "commcenter", "assistantd", "rapportd", "powerd"
        ]
        if systemDaemons.contains(lower) {
            return true
        }

        return false
    }

    // MARK: - Safe Leftover Deletion

    /// Safely deletes a leftover item. By default moves to Trash.
    /// Strictly verifies that the target path is inside user's Library subfolders.
    @discardableResult
    public static func deleteLeftover(_ item: LeftoverItem, toTrash: Bool = true, home: String = NSHomeDirectory()) throws -> Bool {
        let path = item.path
        let userLibrary = (home as NSString).appendingPathComponent("Library")

        // Strict boundary check: must be inside ~/Library/<category>
        guard path.hasPrefix(userLibrary + "/"), !path.contains("..") else {
            return false
        }

        // Verify the path exists
        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }

        let url = URL(fileURLWithPath: path)
        if toTrash {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                return true
            } catch {
                try FileManager.default.removeItem(atPath: path)
                return true
            }
        } else {
            try FileManager.default.removeItem(atPath: path)
            return true
        }
    }
}
