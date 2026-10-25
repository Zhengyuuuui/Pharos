import Darwin
import Foundation

/// Scans the size of common cache/temp directories and cleans them.
///
/// Every target has a fixed path and a fixed rule (delete children only, never
/// the directory itself — apps expect their cache dir to exist). Scanning is
/// read-only; deleting is the user-initiated write action. Files newer than a
/// target's age window are skipped by both scan and clean, so anything still in
/// active use is left alone.
public enum DiskCleaner {
    // MARK: - Targets

    /// How targets are grouped in the UI. `temp` holds the scratch dirs that AI
    /// agents and build tools write into constantly — the ones worth cleaning
    /// every day or two; the rest are long-lived caches cleaned rarely.
    public enum Group: String, CaseIterable, Sendable {
        case temp, systemLogs, trashBins, browserCaches, appCaches, apple, packages
    }

    /// One cleanable directory. Cleaning removes eligible files inside it,
    /// never the directory itself.
    public struct Target: Identifiable, Hashable, Sendable {
        public let id: String
        /// Absolute path (empty = not applicable on this machine).
        public let path: String
        /// Untranslated key; the view maps it through L10n.
        public let title: String
        public let group: Group
        /// Skip files modified within this many seconds. nil = include everything.
        public let maxAge: TimeInterval?

        public init(id: String, path: String, title: String, group: Group = .packages,
                    maxAgeDays: Int? = nil) {
            self.init(id: id, path: path, title: title, group: group,
                      maxAge: maxAgeDays.map { TimeInterval($0) * 86_400 })
        }

        public init(id: String, path: String, title: String, group: Group, maxAge: TimeInterval?) {
            self.id = id
            self.path = path
            self.title = title
            self.group = group
            self.maxAge = maxAge
        }

        public var maxAgeDays: Int? { maxAge.map { Int($0 / 86_400) } }

        /// Same target with a different retention window (user setting).
        public func withMaxAge(_ seconds: TimeInterval?) -> Target {
            Target(id: id, path: path, title: title, group: group, maxAge: seconds)
        }
    }

    /// A detailed direct sub-item (file or sub-directory) inside a Target directory.
    public struct SubItem: Identifiable, Hashable, Sendable {
        public var id: String { path }
        public let name: String
        public let path: String
        public let size: UInt64
        public let isDirectory: Bool
        public let mtime: Date?

        public init(name: String, path: String, size: UInt64, isDirectory: Bool, mtime: Date?) {
            self.name = name
            self.path = path
            self.size = size
            self.isDirectory = isDirectory
            self.mtime = mtime
        }
    }

    public static let home = NSHomeDirectory()

    /// The default target list. Temp group first: it's the one cleaned often.
    public static let defaultTargets: [Target] = [
        // Scratch dirs AI agents / CLIs / build tools write into all the time.
        Target(id: "tmp", path: "/private/tmp", title: "systemTemp", group: .temp, maxAgeDays: 1),
        Target(id: "var-tmp", path: "/private/var/tmp", title: "varTemp", group: .temp, maxAgeDays: 1),
        Target(id: "user-temp", path: darwinUserDir(isCache: false), title: "userTemp", group: .temp, maxAgeDays: 1),
        Target(id: "user-cache", path: darwinUserDir(isCache: true), title: "userCache", group: .temp, maxAgeDays: 1),

        // System & Application Logs, Crash Diagnostics
        Target(id: "user-logs", path: home + "/Library/Logs", title: "userLogs", group: .systemLogs, maxAgeDays: 7),
        Target(id: "diagnostic-reports", path: "/Library/Logs/DiagnosticReports", title: "diagnosticReports", group: .systemLogs, maxAgeDays: 7),

        // Trash Bins
        Target(id: "user-trash", path: home + "/.Trash", title: "userTrash", group: .trashBins, maxAgeDays: nil),

        // Browser Caches (Chromium Code Cache, WebKit, etc.)
        Target(id: "chrome-cache", path: home + "/Library/Caches/Google/Chrome", title: "chromeCache", group: .browserCaches, maxAgeDays: 7),
        Target(id: "edge-cache", path: home + "/Library/Caches/Microsoft Edge", title: "edgeCache", group: .browserCaches, maxAgeDays: 7),
        Target(id: "brave-cache", path: home + "/Library/Caches/BraveSoftware", title: "braveCache", group: .browserCaches, maxAgeDays: 7),
        Target(id: "safari-cache", path: home + "/Library/Caches/com.apple.Safari", title: "safariCache", group: .browserCaches, maxAgeDays: 7),

        // General Application Caches
        Target(id: "app-caches", path: home + "/Library/Caches", title: "appCaches", group: .appCaches, maxAgeDays: 7),

        // Xcode / Apple toolchain.
        Target(id: "xcode-derived", path: home + "/Library/Developer/Xcode/DerivedData", title: "xcodeDerived", group: .apple),
        Target(id: "xcode-archives", path: home + "/Library/Developer/Xcode/Archives", title: "xcodeArchives", group: .apple),
        Target(id: "xcode-device-support", path: home + "/Library/Developer/Xcode/iOS DeviceSupport", title: "xcodeDeviceSupport", group: .apple),
        Target(id: "simulator-caches", path: home + "/Library/Developer/CoreSimulator/Caches", title: "simulatorCaches", group: .apple),
        // Nested inside ~/Library/Caches: excluded from the app-caches row so
        // sizes don't double count, but get their own rows.
        Target(id: "spm", path: home + "/Library/Caches/org.swift.swiftpm", title: "spm", group: .apple),
        Target(id: "cocoapods", path: home + "/Library/Caches/CocoaPods", title: "cocoapods", group: .apple),

        // Package managers / language toolchains.
        Target(id: "npm", path: home + "/.npm/_cacache", title: "npm"),
        Target(id: "pnpm-store", path: home + "/Library/pnpm/store", title: "pnpm"),
        Target(id: "uv", path: home + "/.cache/uv", title: "uv"),
        Target(id: "pip", path: home + "/Library/Caches/pip", title: "pip"),
        Target(id: "gradle-caches", path: home + "/.gradle/caches", title: "gradle"),
        Target(id: "maven", path: home + "/.m2/repository", title: "maven"),
        Target(id: "cargo-registry", path: home + "/.cargo/registry/cache", title: "cargo"),
        Target(id: "rustup-toolchains", path: home + "/.rustup/toolchains", title: "rustup"),
        Target(id: "go-build", path: home + "/Library/Caches/go-build", title: "goBuild"),
        Target(id: "go-mod", path: home + "/Library/Caches/go-mod", title: "goMod"),
        Target(id: "homebrew", path: home + "/Library/Caches/Homebrew", title: "homebrew"),
    ]

    /// Targets nested under `target`'s path (by path prefix). A parent target
    /// must never scan into or delete another row's subtree: it would double
    /// count and delete a directory that row promises to keep.
    public static func nestedPaths(under target: Target, in targets: [Target]) -> Set<String> {
        guard !target.path.isEmpty else { return [] }
        return Set(targets.filter {
            $0.id != target.id && !$0.path.isEmpty && $0.path.hasPrefix(target.path + "/")
        }.map(\.path))
    }

    /// DARWIN_USER_TEMP_DIR / DARWIN_USER_CACHE_DIR — per-user, per-Mac paths
    /// under /var/folders, resolved from the kernel (confstr), never guessed.
    public static func darwinUserDir(isCache: Bool) -> String {
        // _CS_DARWIN_USER_TEMP_DIR = 65537, _CS_DARWIN_USER_CACHE_DIR = 65538
        let id: Int32 = isCache ? 65538 : 65537
        let len = confstr(id, nil, 0)
        guard len > 0 else { return "" }
        var buf = [UInt8](repeating: 0, count: Int(len))
        let n = buf.withUnsafeMutableBytes { confstr(id, $0.baseAddress, $0.count) }
        guard n > 0 else { return "" }
        var path = String(decoding: buf.prefix(Int(n) - 1), as: UTF8.self) // drop trailing NUL
        // confstr returns ".../T/"; a trailing slash would break the
        // `root + "/"` prefix checks that keep the target dir itself.
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }

    /// Targets of one group, in list order.
    public static func targets(in group: Group, from list: [Target] = defaultTargets) -> [Target] {
        list.filter { $0.group == group }
    }

    // MARK: - Scanning

    /// Sum of file sizes under the target (children only) that pass its age rule.
    /// Missing directory → 0. Symlinks count as 0. Sibling context is always
    /// `defaultTargets`, so a bare scan of `app-caches` already skips nested rows.
    public static func size(of target: Target) -> UInt64 {
        size(of: target, excluding: nestedPaths(under: target, in: defaultTargets))
    }

    /// Per-target sizes with sibling-aware exclusions within `targets`.
    public static func sizes(of targets: [Target]) -> [Target: UInt64] {
        var result: [Target: UInt64] = [:]
        for t in targets { result[t] = size(of: t, excluding: nestedPaths(under: t, in: targets)) }
        return result
    }

    // MARK: - Cleaning

    public struct CleanResult: Sendable, Equatable {
        public var freedBytes: UInt64
        public var removedCount: Int
        public var failedCount: Int
        /// Freed bytes per target id, so per-row UI can show what each row freed.
        public var perTarget: [String: UInt64]

        public init(freedBytes: UInt64 = 0, removedCount: Int = 0, failedCount: Int = 0,
                    perTarget: [String: UInt64] = [:]) {
            self.freedBytes = freedBytes
            self.removedCount = removedCount
            self.failedCount = failedCount
            self.perTarget = perTarget
        }
    }

    /// Deletes files that pass each target's age rule, keeping the directories.
    /// Semantics match the size scan exactly (per-file mtime): old files are
    /// unlinked, fresh files stay, directories that become empty are pruned with
    /// `rmdir` (which refuses non-empty dirs, so anything still in use survives).
    /// Special files (sockets, FIFOs, devices) are never touched — a running
    /// app's unix socket must keep its path. Unlink failures (root-owned entries
    /// in sticky /tmp, open files) count in `failedCount` instead of aborting.
    /// `context` supplies sibling rows for nested-path exclusion (`cleanOne`).
    public static func clean(_ targets: [Target], context: [Target]? = nil) -> CleanResult {
        let siblings = context ?? targets
        var result = CleanResult()
        for target in targets {
            let excluded = nestedPaths(under: target, in: siblings)
            sweep(target.path, cutoff: cutoff(for: target), excluding: excluded,
                  targetId: target.id, into: &result)
        }
        return result
    }

    /// Clean a single target while still honoring the sibling rows of
    /// `defaultTargets` (e.g. cleaning `~/Library/Caches` alone must not touch
    /// the nested SwiftPM/pip/Go rows, whose own age rules are looser).
    public static func cleanOne(_ target: Target) -> CleanResult {
        clean([target], context: defaultTargets)
    }

    // MARK: - Detailed SubItem Breakdown

    /// Explores the direct sub-items (folders or files) inside `target.path`, calculating
    /// each item's eligible size (honoring maxAge cutoff and sibling exclusions).
    /// Returns items sorted by size descending, capped at `limit`.
    public static func subItems(of target: Target, limit: Int = 15, context: [Target] = defaultTargets) -> [SubItem] {
        guard !target.path.isEmpty, FileManager.default.fileExists(atPath: target.path) else { return [] }
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: target.path) else { return [] }
        let excluded = nestedPaths(under: target, in: context)
        let cut = cutoff(for: target)
        let uid = getuid()
        var items: [SubItem] = []

        for entry in entries {
            let fullPath = (target.path as NSString).appendingPathComponent(entry)
            guard !excluded.contains(fullPath) else { continue }
            var st = stat()
            guard lstat(fullPath, &st) == 0 else { continue }
            let isDir = (st.st_mode & S_IFMT) == S_IFDIR
            let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))

            var itemSize: UInt64 = 0
            if isDir {
                forEachEligibleFile(fullPath, cutoff: cut, excluding: excluded, uid: uid) { _, childStat in
                    itemSize += UInt64(childStat.st_size)
                }
            } else if (st.st_mode & S_IFMT) == S_IFREG {
                if passes(cut, mtime), st.st_uid == uid {
                    itemSize = UInt64(st.st_size)
                }
            }

            if itemSize > 0 {
                items.append(SubItem(name: entry, path: fullPath, size: itemSize, isDirectory: isDir, mtime: mtime))
            }
        }

        items.sort { $0.size > $1.size }
        if items.count > limit {
            return Array(items.prefix(limit))
        }
        return items
    }

    /// Cleans a specific single sub-item under `target`, keeping sibling exclusions safe.
    public static func cleanSubItem(_ subItem: SubItem, under target: Target, context: [Target] = defaultTargets) -> CleanResult {
        var result = CleanResult()
        let excluded = nestedPaths(under: target, in: context)
        let cut = cutoff(for: target)
        if subItem.isDirectory {
            sweep(subItem.path, cutoff: cut, excluding: excluded, targetId: target.id, into: &result)
            // If the subfolder itself became empty after sweep, prune it
            _ = rmdir(subItem.path)
        } else {
            if unlink(subItem.path) == 0 {
                result.freedBytes += subItem.size
                result.removedCount += 1
                result.perTarget[target.id] = subItem.size
            } else {
                result.failedCount += 1
            }
        }
        return result
    }

    // MARK: - Internals

    private static func size(of target: Target, excluding: Set<String>) -> UInt64 {
        guard !target.path.isEmpty, DiskPermissions.isPathReadable(target.path) else { return 0 }
        var total: UInt64 = 0
        forEachEligibleFile(target.path, cutoff: cutoff(for: target), excluding: excluding,
                            uid: getuid()) { _, st in total += UInt64(st.st_size) }
        return total
    }

    private static func cutoff(for target: Target) -> Date? {
        target.maxAge.map { Date(timeIntervalSinceNow: -$0) }
    }

    private static func passes(_ cutoff: Date?, _ modified: Date?) -> Bool {
        guard let cutoff else { return true }
        guard let modified else { return false } // unknown mtime → don't risk deleting
        return modified < cutoff
    }

    /// The single eligibility rule shared by scan and clean, so the size shown
    /// is exactly what a clean can free: regular files only (never symlinks,
    /// sockets, FIFOs), older than the cutoff, owned by this user, in a
    /// directory this user can write. Root-owned entries in sticky /tmp fail
    /// those checks and are neither counted nor attempted.
    private static func forEachEligibleFile(_ dir: String, cutoff: Date?, excluding: Set<String>,
                                            uid: uid_t, _ body: (String, stat) -> Void) {
        guard let children = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
        let dirWritable = access(dir, W_OK) == 0
        for child in children {
            let path = (dir as NSString).appendingPathComponent(child)
            var st = stat()
            guard lstat(path, &st) == 0 else { continue }
            switch st.st_mode & S_IFMT {
            case S_IFDIR:
                guard !excluding.contains(path) else { continue }
                forEachEligibleFile(path, cutoff: cutoff, excluding: excluding, uid: uid, body)
            case S_IFREG:
                guard dirWritable, st.st_uid == uid else { continue }
                let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
                guard passes(cutoff, mtime) else { continue }
                body(path, st)
            default:
                continue
            }
        }
    }

    /// Unlinks eligible files, then prunes directories that became empty.
    /// `rmdir` refuses non-empty dirs, so anything still holding fresh or
    /// foreign files survives untouched.
    private static func sweep(_ rawRoot: String, cutoff: Date?, excluding: Set<String>,
                              targetId: String, into result: inout CleanResult) {
        var root = rawRoot
        while root.count > 1, root.hasSuffix("/") { root.removeLast() }
        guard root.count > 1 else { return }
        var touchedDirs = Set<String>()
        forEachEligibleFile(root, cutoff: cutoff, excluding: excluding, uid: getuid()) { path, st in
            if unlink(path) == 0 {
                result.freedBytes += UInt64(st.st_size)
                result.removedCount += 1
                result.perTarget[targetId, default: 0] += UInt64(st.st_size)
                touchedDirs.insert((path as NSString).deletingLastPathComponent)
            } else {
                result.failedCount += 1
            }
        }
        // Deepest first; walk up but never remove the target root itself.
        for dir in touchedDirs.sorted(by: { $0.count > $1.count }) {
            var current = dir
            while current != root, current.hasPrefix(root + "/"), rmdir(current) == 0 {
                current = (current as NSString).deletingLastPathComponent
            }
        }
    }
}
