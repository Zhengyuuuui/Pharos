import AppKit
import PharosCore

/// Scans cache-target sizes, app leftovers, project purge bundles, and dev/AI stores in the background.
/// Scanning is lazy: runs on demand or when the cleanup page appears.
@MainActor
final class CleanupStore: ObservableObject {
    struct Row: Identifiable {
        let target: DiskCleaner.Target
        var bytes: UInt64?

        var id: String { target.id }
    }

    enum Scope: Equatable {
        case all
        case group(DiskCleaner.Group)
        case row(String)
        case subItem(String)
        case leftovers
        case projectPurge
        case homebrew
        case aiModel(String)
        case toolchain(String)
    }

    /// Outcome of the most recent clean, shown as a banner.
    struct Report {
        let result: DiskCleaner.CleanResult
        let scope: Scope
    }

    /// Retention choices for the temp group, in hours. 0 = delete everything
    /// the rules allow (files in use still fail to unlink and are skipped).
    static let tempRetentionChoices = [0, 1, 6, 24, 72]

    // MARK: - Published Properties

    @Published private(set) var rows: [Row] = []
    @Published private(set) var isScanning = false
    @Published private(set) var cleaning: Scope?
    @Published private(set) var report: Report?

    // Sub-item breakdown per target
    @Published private(set) var subItemsCache: [String: [DiskCleaner.SubItem]] = [:]
    @Published private(set) var loadingSubItemIds: Set<String> = []
    @Published var expandedRowIds: Set<String> = []

    // App Leftovers
    @Published private(set) var leftoverItems: [AppLeftoversScanner.LeftoverItem] = []
    @Published private(set) var isScanningLeftovers = false

    // Project Purge (npkill)
    @Published private(set) var purgeableBundles: [ProjectPurgeScanner.PurgeableBundle] = []
    @Published private(set) var isScanningPurges = false

    // Dev & AI Tools
    @Published private(set) var homebrewItems: [HomebrewCleaner.HomebrewCleanItem] = []
    @Published private(set) var isScanningHomebrew = false

    @Published private(set) var aiModels: [AIModelCleaner.AIModelItem] = []
    @Published private(set) var isScanningAIModels = false

    @Published private(set) var toolchainItems: [ContainerAndToolchainCleaner.ToolchainItem] = []
    @Published private(set) var isScanningToolchain = false

    // Full Disk Access (FDA) & First-Launch One-Time Guidance
    @Published private(set) var hasFullDiskAccess: Bool = DiskPermissions.hasFullDiskAccess
    @Published private(set) var hasPromptedFirstLaunchDiskPermission: Bool
    private static let promptedPermissionKey = "pharos.hasPromptedFirstLaunchDiskPermission"

    var shouldShowFirstLaunchPermissionBanner: Bool {
        !hasFullDiskAccess && !hasPromptedFirstLaunchDiskPermission
    }

    func refreshPermissionStatus() {
        hasFullDiskAccess = DiskPermissions.hasFullDiskAccess
    }

    func dismissFirstLaunchPermissionPrompt() {
        hasPromptedFirstLaunchDiskPermission = true
        UserDefaults.standard.set(true, forKey: Self.promptedPermissionKey)
    }

    func openFullDiskAccessSettings() {
        dismissFirstLaunchPermissionPrompt()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    @Published var tempRetentionHours: Int {
        didSet {
            guard tempRetentionHours != oldValue else { return }
            UserDefaults.standard.set(tempRetentionHours, forKey: Self.retentionKey)
            scan()
        }
    }

    private static let retentionKey = "tempRetentionHours"

    init() {
        let saved = UserDefaults.standard.object(forKey: Self.retentionKey) as? Int
        tempRetentionHours = saved.flatMap { Self.tempRetentionChoices.contains($0) ? $0 : nil } ?? 24
        hasPromptedFirstLaunchDiskPermission = UserDefaults.standard.bool(forKey: Self.promptedPermissionKey)
        hasFullDiskAccess = DiskPermissions.hasFullDiskAccess
    }

    /// Default targets with the user's temp retention applied.
    var targets: [DiskCleaner.Target] {
        let seconds = TimeInterval(tempRetentionHours) * 3600
        return DiskCleaner.defaultTargets.map {
            $0.group == .temp ? $0.withMaxAge(seconds > 0 ? seconds : nil) : $0
        }
    }

    func rows(in group: DiskCleaner.Group) -> [Row] {
        rows.filter { $0.target.group == group }
            .sorted { ($0.bytes ?? 0) > ($1.bytes ?? 0) }
    }

    func bytes(in group: DiskCleaner.Group) -> UInt64 {
        rows.reduce(0) { $0 + ($1.target.group == group ? ($1.bytes ?? 0) : 0) }
    }

    var totalBytes: UInt64 { rows.reduce(0) { $0 + ($1.bytes ?? 0) } }
    var isCleaning: Bool { cleaning != nil }
    var isBusy: Bool { isScanning || isCleaning || isScanningLeftovers || isScanningPurges || isScanningHomebrew || isScanningAIModels || isScanningToolchain }

    func viewAppeared() {
        if rows.isEmpty, !isBusy {
            scan()
        }
    }

    // MARK: - Standard Targets Clean

    func scan() {
        guard !isBusy else { return }
        isScanning = true
        Task { [weak self] in
            await self?.rescan()
            self?.isScanning = false
        }
    }

    func cleanAll() {
        let list = targets
        run(.all) { DiskCleaner.clean(list) }
    }

    func clean(group: DiskCleaner.Group) {
        let list = targets
        let members = DiskCleaner.targets(in: group, from: list)
        run(.group(group)) { DiskCleaner.clean(members, context: list) }
    }

    func cleanOne(id: String) {
        let list = targets
        guard let target = list.first(where: { $0.id == id }) else { return }
        run(.row(id)) { DiskCleaner.clean([target], context: list) }
    }

    // MARK: - Sub-Items Inspection

    func toggleSubItems(for target: DiskCleaner.Target) {
        if expandedRowIds.contains(target.id) {
            expandedRowIds.remove(target.id)
        } else {
            expandedRowIds.insert(target.id)
            if subItemsCache[target.id] == nil {
                fetchSubItems(for: target)
            }
        }
    }

    func fetchSubItems(for target: DiskCleaner.Target) {
        guard !loadingSubItemIds.contains(target.id) else { return }
        loadingSubItemIds.insert(target.id)
        let list = targets
        Task { [weak self] in
            let items = await Task.detached(priority: .utility) {
                DiskCleaner.subItems(of: target, limit: 15, context: list)
            }.value
            guard let self else { return }
            self.subItemsCache[target.id] = items
            self.loadingSubItemIds.remove(target.id)
        }
    }

    func cleanSubItem(_ subItem: DiskCleaner.SubItem, under target: DiskCleaner.Target) {
        guard !isBusy else { return }
        let scope = Scope.subItem(subItem.id)
        cleaning = scope
        report = nil
        let list = targets
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                DiskCleaner.cleanSubItem(subItem, under: target, context: list)
            }.value
            guard let self else { return }
            await self.rescan()
            self.fetchSubItems(for: target)
            self.report = Report(result: result, scope: scope)
            self.cleaning = nil
        }
    }

    // MARK: - App Leftovers Scanning & Cleaning

    func scanLeftovers() {
        guard !isScanningLeftovers else { return }
        isScanningLeftovers = true
        Task { [weak self] in
            let items = await Task.detached(priority: .utility) {
                AppLeftoversScanner.scanLeftovers()
            }.value
            guard let self else { return }
            self.leftoverItems = items
            self.isScanningLeftovers = false
        }
    }

    func deleteLeftover(_ item: AppLeftoversScanner.LeftoverItem) {
        Task { [weak self] in
            _ = try? AppLeftoversScanner.deleteLeftover(item, toTrash: true)
            guard let self else { return }
            self.leftoverItems.removeAll { $0.id == item.id }
        }
    }

    func deleteAllLeftovers() {
        let current = leftoverItems
        Task { [weak self] in
            for item in current {
                _ = try? AppLeftoversScanner.deleteLeftover(item, toTrash: true)
            }
            guard let self else { return }
            self.leftoverItems.removeAll()
        }
    }

    // MARK: - Project Purge Scanning & Cleaning

    func scanProjectPurges() {
        guard !isScanningPurges else { return }
        isScanningPurges = true
        Task { [weak self] in
            let bundles = await Task.detached(priority: .utility) {
                ProjectPurgeScanner.scanPurgeableBundles(dormantDays: 14)
            }.value
            guard let self else { return }
            self.purgeableBundles = bundles
            self.isScanningPurges = false
        }
    }

    func purgeBundle(_ bundle: ProjectPurgeScanner.PurgeableBundle) {
        Task { [weak self] in
            _ = try? ProjectPurgeScanner.purgeBundle(bundle)
            guard let self else { return }
            self.purgeableBundles.removeAll { $0.id == bundle.id }
        }
    }

    func purgeAllDormantBundles() {
        let dormant = purgeableBundles.filter { $0.isDormant }
        Task { [weak self] in
            _ = ProjectPurgeScanner.purgeBundles(dormant)
            guard let self else { return }
            self.purgeableBundles.removeAll { $0.isDormant }
        }
    }

    // MARK: - Homebrew Scanning & Cleaning

    func scanHomebrew() {
        guard !isScanningHomebrew else { return }
        isScanningHomebrew = true
        Task { [weak self] in
            let items = await Task.detached(priority: .utility) {
                HomebrewCleaner.scanCleanables()
            }.value
            guard let self else { return }
            self.homebrewItems = items
            self.isScanningHomebrew = false
        }
    }

    func cleanHomebrewItem(_ item: HomebrewCleaner.HomebrewCleanItem) {
        Task { [weak self] in
            _ = try? HomebrewCleaner.cleanItem(item)
            guard let self else { return }
            self.homebrewItems.removeAll { $0.id == item.id }
        }
    }

    func cleanAllHomebrew() {
        let current = homebrewItems
        Task { [weak self] in
            _ = HomebrewCleaner.cleanAll(current)
            guard let self else { return }
            self.homebrewItems.removeAll()
        }
    }

    // MARK: - AI Models Scanning & Cleaning

    func scanAIModels() {
        guard !isScanningAIModels else { return }
        isScanningAIModels = true
        Task { [weak self] in
            let models = await Task.detached(priority: .utility) {
                AIModelCleaner.scanAIModels()
            }.value
            guard let self else { return }
            self.aiModels = models
            self.isScanningAIModels = false
        }
    }

    func deleteAIModel(_ item: AIModelCleaner.AIModelItem) {
        Task { [weak self] in
            _ = try? AIModelCleaner.deleteModel(item)
            guard let self else { return }
            self.aiModels.removeAll { $0.id == item.id }
        }
    }

    // MARK: - Container & Toolchain Scanning & Cleaning

    func scanToolchain() {
        guard !isScanningToolchain else { return }
        isScanningToolchain = true
        Task { [weak self] in
            let items = await Task.detached(priority: .utility) {
                ContainerAndToolchainCleaner.scanToolchainItems()
            }.value
            guard let self else { return }
            self.toolchainItems = items
            self.isScanningToolchain = false
        }
    }

    func cleanToolchainItem(_ item: ContainerAndToolchainCleaner.ToolchainItem) {
        Task { [weak self] in
            _ = try? ContainerAndToolchainCleaner.cleanToolchainItem(item)
            guard let self else { return }
            self.toolchainItems.removeAll { $0.id == item.id }
        }
    }

    // MARK: - Rescan Core

    private func run(_ scope: Scope, _ work: @escaping @Sendable () -> DiskCleaner.CleanResult) {
        guard !isBusy else { return }
        cleaning = scope
        report = nil
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated, operation: work).value
            guard let self else { return }
            await self.rescan()
            self.report = Report(result: result, scope: scope)
            self.cleaning = nil
        }
    }

    private func rescan() async {
        let list = targets
        let sizes = await Task.detached(priority: .utility) {
            DiskCleaner.sizes(of: list)
        }.value
        rows = list.map { Row(target: $0, bytes: sizes[$0] ?? 0) }
    }
}
