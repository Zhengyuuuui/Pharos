import Foundation
import AppKit
import PharosCore

public enum ProjectDepFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case prod
    case dev
    case missing

    public var id: String { rawValue }
}

@MainActor
final class PackageStore: ObservableObject {
    static let shared = PackageStore()

    // MARK: - Published Data State
    @Published private(set) var globalCliTools: [LocalPackageItem] = [] {
        didSet { recomputeFilteredCli() }
    }
    @Published private(set) var cacheRepos: [PackageCacheRepoSummary] = []
    @Published private(set) var detectedProjects: [ProjectDependencySummary] = []
    @Published var selectedProjectSummary: ProjectDependencySummary? = nil {
        didSet { recomputeFilteredProject() }
    }
    @Published private(set) var isScanning = false
    @Published var lastScanTime: Date? = nil

    // MARK: - Filters & Selection
    @Published var onlyFeatured: Bool = false {
        didSet { recomputeFilteredCli() }
    }
    @Published var selectedEcosystem: PackageEcosystem? = nil {
        didSet { recomputeFilteredCli() }
    }
    @Published var cliSearchQuery: String = "" {
        didSet { recomputeFilteredCli() }
    }
    @Published var projectSearchQuery: String = "" {
        didSet { recomputeFilteredProject() }
    }
    @Published var projectFilter: ProjectDepFilter = .all {
        didSet { recomputeFilteredProject() }
    }
    @Published var selectedCliId: String? = nil

    // MARK: - Filtered Views
    @Published private(set) var filteredCliTools: [LocalPackageItem] = []
    @Published private(set) var featuredShelfTools: [LocalPackageItem] = []
    @Published private(set) var filteredProjectPackages: [LocalPackageItem] = []

    // MARK: - Metric Summaries
    var globalCliCount: Int { globalCliTools.count }
    var featuredCliTools: [LocalPackageItem] { globalCliTools.filter(\.isFeatured) }
    var featuredCliCount: Int { featuredCliTools.count }
    var totalCacheSize: UInt64 { cacheRepos.reduce(0) { $0 + $1.fileSizeBytes } }
    var totalCacheCount: Int { cacheRepos.count }

    func cliCount(for eco: PackageEcosystem) -> Int {
        globalCliTools.filter { $0.ecosystem == eco }.count
    }

    private init() {
        scanAll()
    }

    // MARK: - Scanning
    func scanAll() {
        guard !isScanning else { return }
        isScanning = true

        Task.detached(priority: .userInitiated) { [weak self] in
            let clis = PackageScanner.scanGlobalCliTools()
            let caches = PackageScanner.scanCacheRepositories()

            // 探索已知活跃项目与 ~/Documents
            let docRoots = PackageScanner.discoverProjectPaths(maxDepth: 3)
            var summaries: [ProjectDependencySummary] = []
            for path in docRoots {
                if let summary = PackageScanner.scanProjectDependencies(projectPath: path) {
                    summaries.append(summary)
                }
            }

            let finalSummaries = summaries
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.globalCliTools = clis
                self.cacheRepos = caches
                self.detectedProjects = finalSummaries.sorted { $0.name.lowercased() < $1.name.lowercased() }
                if self.selectedProjectSummary == nil {
                    self.selectedProjectSummary = self.detectedProjects.first
                }
                self.lastScanTime = Date()
                self.isScanning = false
                self.recomputeFilteredCli()
                self.recomputeFilteredProject()
            }
        }
    }

    func scanProject(at path: String) {
        Task.detached(priority: .userInitiated) { [weak self] in
            let summary = PackageScanner.scanProjectDependencies(projectPath: path)
            await MainActor.run { [weak self] in
                guard let self, let summary else { return }
                if let idx = self.detectedProjects.firstIndex(where: { $0.rootPath == summary.rootPath }) {
                    self.detectedProjects[idx] = summary
                } else {
                    self.detectedProjects.append(summary)
                }
                self.selectedProjectSummary = summary
            }
        }
    }

    // MARK: - Filtering Logic
    private func recomputeFilteredCli() {
        var items = globalCliTools
        if onlyFeatured {
            items = items.filter(\.isFeatured)
        }
        if let eco = selectedEcosystem {
            items = items.filter { $0.ecosystem == eco }
        }
        let q = cliSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            items = items.filter {
                $0.name.lowercased().contains(q) ||
                ($0.summary?.lowercased().contains(q) ?? false) ||
                ($0.categoryTag?.lowercased().contains(q) ?? false) ||
                $0.installPath.lowercased().contains(q) ||
                ($0.executablePath?.lowercased().contains(q) ?? false)
            }
        }
        filteredCliTools = items

        // Precompute shelf items (only featured, deduplicated aliases)
        var shelf = globalCliTools.filter(\.isFeatured)
        if let eco = selectedEcosystem {
            shelf = shelf.filter { $0.ecosystem == eco }
        }
        if !q.isEmpty {
            shelf = shelf.filter {
                $0.name.lowercased().contains(q) ||
                ($0.summary?.lowercased().contains(q) ?? false) ||
                ($0.categoryTag?.lowercased().contains(q) ?? false)
            }
        }
        let secondaryAliases: Set<String> = [
            "cbc", "codebuddy-code", "cbc-prewarm",
            "cf-wrangler", "wrangler2",
            "rea-agents",
            "bunx",
            "pnpx",
            "yarnpkg",
            "uvx"
        ]
        let hasPrimary = Set(shelf.map(\.name))
        featuredShelfTools = shelf.filter { item in
            if secondaryAliases.contains(item.name) {
                switch item.name {
                case "cbc", "codebuddy-code", "cbc-prewarm": return !hasPrimary.contains("codebuddy")
                case "cf-wrangler", "wrangler2": return !hasPrimary.contains("wrangler")
                case "rea-agents": return !hasPrimary.contains("rea")
                case "bunx": return !hasPrimary.contains("bun")
                case "pnpx": return !hasPrimary.contains("pnpm")
                case "yarnpkg": return !hasPrimary.contains("yarn")
                case "uvx": return !hasPrimary.contains("uv")
                default: return true
                }
            }
            return true
        }
    }

    private func recomputeFilteredProject() {
        guard let summary = selectedProjectSummary else {
            filteredProjectPackages = []
            return
        }
        var pkgs = summary.packages

        switch projectFilter {
        case .all:
            break
        case .prod:
            pkgs = pkgs.filter { !$0.isDevDependency }
        case .dev:
            pkgs = pkgs.filter { $0.isDevDependency }
        case .missing:
            pkgs = pkgs.filter { $0.healthStatus == .missing }
        }

        let q = projectSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            pkgs = pkgs.filter {
                $0.name.lowercased().contains(q) ||
                ($0.summary?.lowercased().contains(q) ?? false) ||
                ($0.license?.lowercased().contains(q) ?? false)
            }
        }
        filteredProjectPackages = pkgs
    }

    // MARK: - Actions
    func revealInFinder(path: String) {
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        } else {
            let parent = (path as NSString).deletingLastPathComponent
            if FileManager.default.fileExists(atPath: parent) {
                NSWorkspace.shared.selectFile(parent, inFileViewerRootedAtPath: "")
            }
        }
    }

    func testInTerminal(command: String, in directory: String? = nil) {
        let workDir = directory ?? NSHomeDirectory()
        let title = "Pharos: \(command)"
        let script = LaunchScript.contents(
            directory: workDir,
            command: "\(command) --help",
            title: title,
            shell: nil,
            interactiveLogin: true
        )

        let tempScriptUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-test-\(UUID().uuidString).command")
        do {
            try LaunchScript.write(script, to: tempScriptUrl)
            NSWorkspace.shared.open(tempScriptUrl)
        } catch {
            print("Failed to run test script in terminal: \(error)")
        }
    }

    func uninstallInTerminal(item: LocalPackageItem) {
        let cmd = item.uninstallCommand
        let title = "Pharos: Uninstall \(item.name)"
        let script = LaunchScript.contents(
            directory: NSHomeDirectory(),
            command: cmd,
            title: title,
            shell: nil,
            interactiveLogin: true
        )

        let tempScriptUrl = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pharos-uninstall-\(UUID().uuidString).command")
        do {
            try LaunchScript.write(script, to: tempScriptUrl)
            NSWorkspace.shared.open(tempScriptUrl)
        } catch {
            print("Failed to run uninstall script in terminal: \(error)")
        }
    }
}
