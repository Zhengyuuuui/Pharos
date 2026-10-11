import AppKit
import UsageBarCore

/// Scans cache-target sizes in the background and runs cleans (all, one group,
/// or one row). Scanning is lazy: it only runs while the cleanup page is on
/// screen, so the directory walks cost nothing during normal monitoring.
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
    }

    /// Outcome of the most recent clean, shown as a banner.
    struct Report {
        let result: DiskCleaner.CleanResult
        let scope: Scope
    }

    /// Retention choices for the temp group, in hours. 0 = delete everything
    /// the rules allow (files in use still fail to unlink and are skipped).
    static let tempRetentionChoices = [0, 1, 6, 24, 72]

    @Published private(set) var rows: [Row] = []
    @Published private(set) var isScanning = false
    @Published private(set) var cleaning: Scope?
    @Published private(set) var report: Report?
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
    var isBusy: Bool { isScanning || isCleaning }

    func viewAppeared() {
        guard rows.isEmpty, !isBusy else { return }
        scan()
    }

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

    /// Clean, then rescan inside the same busy window so the rows never show
    /// stale sizes and buttons re-enable only once the numbers are current.
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
