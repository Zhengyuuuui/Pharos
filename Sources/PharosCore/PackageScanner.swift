import Darwin
import Foundation

/// 本地依赖包与命令行工具扫描解析器 (纯逻辑、无 UI 依赖、可全量单测)
public enum PackageScanner {
    // MARK: - Safe POSIX File Stat Helper

    public static func safeStat(at path: String) -> (size: UInt64, mtime: Date, isSymlink: Bool, isDir: Bool)? {
        var st = stat()
        let ret = path.withCString { lstat($0, &st) }
        guard ret == 0 else { return nil }
        let mode = st.st_mode & S_IFMT
        let isSymlink = (mode == S_IFLNK)
        let isDir = (mode == S_IFDIR)
        let mtimeSec = TimeInterval(st.st_mtimespec.tv_sec) + TimeInterval(st.st_mtimespec.tv_nsec) / 1_000_000_000.0
        return (UInt64(st.st_size), Date(timeIntervalSince1970: mtimeSec), isSymlink, isDir)
    }

    // MARK: - Directory Size Cache (mtime + lockfile fingerprint)

    private struct DirSizeCacheEntry: Sendable {
        let dirMtime: TimeInterval
        let lockfileMtime: TimeInterval
        let size: UInt64
        let count: Int
    }

    private final class DirSizeCacheStorage: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [String: DirSizeCacheEntry] = [:]

        func get(path: String, dirMtime: TimeInterval, lockfileMtime: TimeInterval) -> (size: UInt64, count: Int)? {
            lock.lock()
            defer { lock.unlock() }
            guard let entry = entries[path],
                  entry.dirMtime == dirMtime,
                  entry.lockfileMtime == lockfileMtime else {
                return nil
            }
            return (entry.size, entry.count)
        }

        func set(path: String, dirMtime: TimeInterval, lockfileMtime: TimeInterval, size: UInt64, count: Int) {
            lock.lock()
            entries[path] = DirSizeCacheEntry(dirMtime: dirMtime, lockfileMtime: lockfileMtime, size: size, count: count)
            lock.unlock()
        }

        func remove(path: String) {
            lock.lock()
            entries.removeValue(forKey: path)
            lock.unlock()
        }

        func clear() {
            lock.lock()
            entries.removeAll()
            lock.unlock()
        }
    }

    private static let dirSizeCache = DirSizeCacheStorage()

    /// 清空目录体积内存缓存（供单测或强制重算使用）
    public static func clearDirectorySizeCache() {
        dirSizeCache.clear()
    }

    /// 提取项目根目录下所有声明文件与锁文件的最大修改时间戳
    public static func projectLockfileMtime(root: String) -> TimeInterval {
        let candidates = [
            "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "bun.lockb", "bun.lock", "package.json",
            "requirements.txt", "pyproject.toml", "uv.lock", "poetry.lock", "Pipfile.lock", "Pipfile",
            "Package.resolved", "Package.swift",
            "Cargo.lock", "Cargo.toml",
            "pom.xml", "build.gradle"
        ]
        var maxMtime: TimeInterval = 0
        for file in candidates {
            let p = (root as NSString).appendingPathComponent(file)
            if let st = safeStat(at: p) {
                let t = st.mtime.timeIntervalSince1970
                if t > maxMtime { maxMtime = t }
            }
        }
        return maxMtime
    }

    /// 带 mtime 指纹缓存的目录体积查询；当 computeIfMissing 为 false 时仅查缓存不执行递归遍历
    public static func cachedDirectorySize(
        at dir: String,
        maxFiles: Int = 100_000,
        lockfileMtime: TimeInterval = 0,
        computeIfMissing: Bool = true
    ) -> (size: UInt64, count: Int)? {
        let standardized = (dir as NSString).standardizingPath
        guard let s = safeStat(at: standardized), s.isDir else { return nil }
        let dirMtime = s.mtime.timeIntervalSince1970

        if let cached = dirSizeCache.get(path: standardized, dirMtime: dirMtime, lockfileMtime: lockfileMtime) {
            return cached
        }
        guard computeIfMissing else { return nil }

        let computed = directorySize(at: standardized, maxFiles: maxFiles)
        dirSizeCache.set(
            path: standardized,
            dirMtime: dirMtime,
            lockfileMtime: lockfileMtime,
            size: computed.size,
            count: computed.count
        )
        return computed
    }

    /// 快速计算目录体积与文件总数 (安全只读、跳过深层软链接与特殊文件)
    public static func directorySize(at dir: String, maxFiles: Int = 100_000) -> (size: UInt64, count: Int) {
        guard let s = safeStat(at: dir), s.isDir else { return (0, 0) }
        var total: UInt64 = 0
        var count: Int = 0

        let url = URL(fileURLWithPath: dir)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else { return (0, 0) }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
               values.isRegularFile == true,
               let size = values.fileSize {
                total += UInt64(size)
                count += 1
                if count >= maxFiles { break }
            }
        }
        return (total, count)
    }


    /// 开发者常见项目存放根目录候选列表 (自动探测存在性)
    /// 默认情况下若尚未获得完全磁盘访问权限 (FDA)，则跳过受 macOS TCC 弹窗保护的 Desktop/Documents 目录，
    /// 避免用户切换或点击子页面时触发突兀的系统权限弹窗。
    public static func defaultSearchRoots(
        home: String = NSHomeDirectory(),
        includeProtectedUserFolders: Bool = DiskPermissions.hasFullDiskAccess
    ) -> [String] {
        let candidates = [
            "Developer",
            "Projects",
            "Workspace",
            "workspaces",
            "code",
            "dev",
            "src",
            "git"
        ]
        var roots: [String] = []
        for folder in candidates {
            let p = (home as NSString).appendingPathComponent(folder)
            if FileManager.default.fileExists(atPath: p) {
                roots.append(p)
            }
        }

        if includeProtectedUserFolders {
            for folder in ["Desktop", "Documents"] {
                let p = (home as NSString).appendingPathComponent(folder)
                if FileManager.default.fileExists(atPath: p) {
                    roots.append(p)
                }
            }
        }

        if roots.isEmpty {
            let devPath = (home as NSString).appendingPathComponent("Developer")
            if FileManager.default.fileExists(atPath: devPath) {
                return [devPath]
            }
            return [(home as NSString).appendingPathComponent("Documents")]
        }
        return roots
    }

    /// 快速探索开发者常见项目目录 (支持 Node、Python、Swift、Rust 等)
    public static func discoverProjectPaths(
        searchRoots: [String] = defaultSearchRoots(),
        maxDepth: Int = 3
    ) -> [String] {
        var found: [String] = []
        let skipDirs: Set<String> = [
            "node_modules", ".git", ".venv", "venv", "env", ".build", "dist", "build", "target", "Pods", "DerivedData", "Library", "Applications",
            "@types", "typings", ".next", ".nuxt", ".output", "vendor", "coverage"
        ]

        func search(dir: String, depth: Int) {
            guard depth <= maxDepth else { return }
            guard !dir.contains("/node_modules/") else { return }
            guard let children = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
            let dirName = (dir as NSString).lastPathComponent
            if !dirName.hasPrefix("@") {
                let hasManifest = children.contains("package.json") ||
                                  children.contains("node_modules") ||
                                  children.contains("pyproject.toml") ||
                                  children.contains("requirements.txt") ||
                                  children.contains("Pipfile") ||
                                  children.contains(".venv") ||
                                  children.contains("venv") ||
                                  children.contains("Package.swift") ||
                                  children.contains("Package.resolved") ||
                                  children.contains(".build") ||
                                  children.contains("Cargo.toml") ||
                                  children.contains("Cargo.lock") ||
                                  children.contains("pom.xml") ||
                                  children.contains("build.gradle")
                if hasManifest {
                    found.append(dir)
                }
            }
            for child in children where !child.hasPrefix(".") && !child.hasPrefix("@") && !skipDirs.contains(child) {
                let sub = (dir as NSString).appendingPathComponent(child)
                var st = stat()
                if sub.withCString({ lstat($0, &st) }) == 0 && (st.st_mode & S_IFMT) == S_IFDIR {
                    search(dir: sub, depth: depth + 1)
                }
            }
        }

        for root in searchRoots {
            if FileManager.default.fileExists(atPath: root) {
                search(dir: root, depth: 1)
            }
        }
        return found
    }

    // MARK: - Internal Helpers

    /// 简单的版本偏离检测 (例如声明 "^18.0.0" 但安装了 "19.0.0")
    static func isVersionMismatched(declared: String, installed: String) -> Bool {
        let decClean = declared.trimmingCharacters(in: CharacterSet(charactersIn: "^~>=<v "))
        let instClean = installed.trimmingCharacters(in: CharacterSet(charactersIn: "v "))
        let decMajor = decClean.split(separator: ".").first
        let instMajor = instClean.split(separator: ".").first
        if let d = decMajor, let i = instMajor, !d.isEmpty, !i.isEmpty {
            return d != i
        }
        return false
    }

    // MARK: - Dependency Bundle Clean / Delete
    /// 将项目的主依赖目录移入废纸篓或删除（释放磁盘空间）
    @discardableResult
    public static func deleteProjectDependencyBundle(at bundlePath: String, projectRoot: String) throws -> Bool {
        guard !bundlePath.isEmpty, bundlePath != projectRoot, bundlePath.hasPrefix(projectRoot + "/") else {
            return false
        }
        guard FileManager.default.fileExists(atPath: bundlePath) else {
            return false
        }
        let url = URL(fileURLWithPath: bundlePath)
        defer {
            dirSizeCache.remove(path: (bundlePath as NSString).standardizingPath)
        }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            try FileManager.default.removeItem(atPath: bundlePath)
            return true
        }
    }
}

