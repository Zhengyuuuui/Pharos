import Darwin
import Foundation

/// Fast scanner and batch purger for developer project build artifacts and dependencies (npkill style).
///
/// Recursively scans developer workspaces for heavy project build and dependency bundles:
/// - `node_modules` (Node.js / JavaScript)
/// - `target` (Rust Cargo)
/// - `.build` (SwiftPM)
/// - `.venv`, `venv` (Python virtual environments)
/// - `.next`, `.nuxt`, `.output` (Modern frontend SSR builds)
/// - `dist`, `build` (Compiled web or native distribution artifacts)
/// - `Pods`, `DerivedData` (CocoaPods & Xcode project artifacts)
///
/// Flags dormant projects (e.g. untouched for > 14 days) and provides single-click
/// or batch purging using safe macOS trash or deletion.
public enum ProjectPurgeScanner {

    public enum BundleType: String, Sendable, CaseIterable {
        case nodeModules = "node_modules"
        case rustTarget = "target"
        case swiftBuild = ".build"
        case pythonVenv = ".venv"
        case venv = "venv"
        case nextBuild = ".next"
        case nuxtBuild = ".nuxt"
        case outputDir = ".output"
        case dist = "dist"
        case build = "build"
        case cocoaPods = "Pods"
        case derivedData = "DerivedData"

        public var displayName: String {
            switch self {
            case .nodeModules: return "Node Modules"
            case .rustTarget: return "Cargo Target"
            case .swiftBuild: return "SwiftPM Build"
            case .pythonVenv, .venv: return "Python Virtualenv"
            case .nextBuild: return "Next.js Build"
            case .nuxtBuild: return "Nuxt Build"
            case .outputDir: return "SSR Output"
            case .dist: return "Distribution (dist)"
            case .build: return "Build Artifacts"
            case .cocoaPods: return "CocoaPods"
            case .derivedData: return "Derived Data"
            }
        }
    }

    public struct PurgeableBundle: Identifiable, Hashable, Sendable {
        public var id: String { bundlePath }
        public let projectPath: String
        public let projectName: String
        public let bundleType: BundleType
        public let bundlePath: String
        public let size: UInt64
        public let lastModified: Date?
        public let isDormant: Bool // Untouched for > dormantThresholdDays

        public init(
            projectPath: String,
            projectName: String,
            bundleType: BundleType,
            bundlePath: String,
            size: UInt64,
            lastModified: Date?,
            isDormant: Bool
        ) {
            self.projectPath = projectPath
            self.projectName = projectName
            self.bundleType = bundleType
            self.bundlePath = bundlePath
            self.size = size
            self.lastModified = lastModified
            self.isDormant = isDormant
        }
    }

    // MARK: - Scanning

    /// Scans developer directories for purgeable build and dependency bundles.
    ///
    /// - Parameters:
    ///   - searchRoots: Directories to start search from (defaults to `PackageScanner.defaultSearchRoots()`)
    ///   - maxDepth: Directory recursion depth limit
    ///   - dormantDays: Number of days without modification to classify as dormant (default: 14)
    ///   - minSizeThreshold: Minimum bundle size in bytes to include (default: 100 KB)
    public static func scanPurgeableBundles(
        searchRoots: [String] = PackageScanner.defaultSearchRoots(),
        maxDepth: Int = 4,
        dormantDays: Int = 14,
        minSizeThreshold: UInt64 = 100 * 1024
    ) -> [PurgeableBundle] {
        var results: [PurgeableBundle] = []
        let dormantCutoff = Date(timeIntervalSinceNow: -TimeInterval(dormantDays) * 86_400)

        let targetNames: [String: BundleType] = [
            "node_modules": .nodeModules,
            "target": .rustTarget,
            ".build": .swiftBuild,
            ".venv": .pythonVenv,
            "venv": .venv,
            ".next": .nextBuild,
            ".nuxt": .nuxtBuild,
            ".output": .outputDir,
            "dist": .dist,
            "build": .build,
            "Pods": .cocoaPods,
            "DerivedData": .derivedData
        ]

        let skipDirectoryNames: Set<String> = [
            ".git", ".svn", ".hg", "Library", "Applications", "System", ".Trash",
            ".cache", "Caches", ".rustup", ".cargo", ".npm", ".gradle", ".m2"
        ]

        func walk(dir: String, currentDepth: Int) {
            guard currentDepth <= maxDepth else { return }
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }

            for item in contents {
                if item.hasPrefix(".") && !targetNames.keys.contains(item) {
                    continue
                }
                if skipDirectoryNames.contains(item) {
                    continue
                }

                let fullPath = (dir as NSString).appendingPathComponent(item)
                var st = stat()
                guard lstat(fullPath, &st) == 0 else { continue }
                guard (st.st_mode & S_IFMT) == S_IFDIR else { continue }

                // Check if this directory is a purgeable target
                if let bundleType = targetNames[item] {
                    // Avoid nested bundles (e.g. node_modules inside another node_modules)
                    if dir.contains("/node_modules/") || dir.contains("/target/") {
                        continue
                    }

                    // For 'dist' or 'build', ensure it looks like a code project by checking siblings
                    if bundleType == .dist || bundleType == .build {
                        let hasProjectSibling = contents.contains("package.json") ||
                                                contents.contains("Cargo.toml") ||
                                                contents.contains("Makefile") ||
                                                contents.contains("CMakeLists.txt") ||
                                                contents.contains("setup.py") ||
                                                contents.contains("pyproject.toml") ||
                                                contents.contains("tsconfig.json")
                        guard hasProjectSibling else {
                            // Traverse inside instead of treating as purgeable
                            walk(dir: fullPath, currentDepth: currentDepth + 1)
                            continue
                        }
                    }

                    // Calculate bundle size and mtime
                    let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
                    let (size, _) = PackageScanner.directorySize(at: fullPath, maxFiles: 30_000)

                    if size >= minSizeThreshold {
                        let isDormant = mtime < dormantCutoff
                        let projectName = (dir as NSString).lastPathComponent
                        results.append(PurgeableBundle(
                            projectPath: dir,
                            projectName: projectName,
                            bundleType: bundleType,
                            bundlePath: fullPath,
                            size: size,
                            lastModified: mtime,
                            isDormant: isDormant
                        ))
                    }
                    // Do not recurse inside a detected bundle
                    continue
                }

                // Normal directory: recurse deeper
                walk(dir: fullPath, currentDepth: currentDepth + 1)
            }
        }

        for root in searchRoots {
            walk(dir: root, currentDepth: 1)
        }

        // Sort by size descending
        return results.sorted { $0.size > $1.size }
    }

    // MARK: - Safe Purging

    /// Purges a single project bundle safely.
    @discardableResult
    public static func purgeBundle(_ bundle: PurgeableBundle) throws -> Bool {
        try PackageScanner.deleteProjectDependencyBundle(at: bundle.bundlePath, projectRoot: bundle.projectPath)
    }

    /// Batch purges multiple project bundles.
    public static func purgeBundles(_ bundles: [PurgeableBundle]) -> (freedBytes: UInt64, purgedCount: Int, failedCount: Int) {
        var freed: UInt64 = 0
        var purged = 0
        var failed = 0

        for bundle in bundles {
            do {
                let success = try purgeBundle(bundle)
                if success {
                    freed += bundle.size
                    purged += 1
                } else {
                    failed += 1
                }
            } catch {
                failed += 1
            }
        }

        return (freed, purged, failed)
    }
}
