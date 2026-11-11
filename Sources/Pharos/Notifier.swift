import Combine
import Foundation
import PharosCore
import UserNotifications

enum ActiveAlertLevel: String, Sendable, Equatable {
    case warning
    case critical
}

/// Represents an active, unresolved real-time system issue shown as an in-app banner.
struct ActiveAlertBanner: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let level: ActiveAlertLevel
    let targetItem: MainWindowView.SidebarItem

    init(
        id: String,
        icon: String,
        title: String,
        subtitle: String,
        level: ActiveAlertLevel = .warning,
        targetItem: MainWindowView.SidebarItem
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.level = level
        self.targetItem = targetItem
    }
}

/// Intelligent local notifications and active in-app alerts (no network/tracking).
/// Conforms to UNUserNotificationCenterDelegate for immediate foreground banners, sound, and deep-link click navigation.
@MainActor
final class Notifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    @Published var memory: Bool { didSet { save(memory, Keys.memory); requestIfNeeded() } }
    @Published var disk: Bool { didSet { save(disk, Keys.disk); requestIfNeeded() } }
    @Published var favoriteExit: Bool { didSet { save(favoriteExit, Keys.favoriteExit); requestIfNeeded() } }
    @Published var thermal: Bool { didSet { save(thermal, Keys.thermal); requestIfNeeded() } }
    @Published var bloat: Bool { didSet { save(bloat, Keys.bloat); requestIfNeeded() } }
    @Published var appUpdate: Bool { didSet { save(appUpdate, Keys.appUpdate); requestIfNeeded() } }
    @Published var diskThreshold: Double { didSet { saveDouble(diskThreshold, Keys.diskThreshold) } }

    /// Set when macOS has notifications turned off for Pharos in System Settings.
    @Published private(set) var denied = false

    /// Real-time unresolved alerts for in-app alert strip display.
    @Published private(set) var activeInAppAlerts: [ActiveAlertBanner] = []

    /// Feedback pulse when test notification is triggered.
    @Published private(set) var testNotificationDelivered = false

    private enum Keys {
        static let memory = "notifyMemory"
        static let disk = "notifyDisk"
        static let favoriteExit = "notifyFavoriteExit"
        static let thermal = "notifyThermal"
        static let bloat = "notifyBloat"
        static let appUpdate = "notifyAppUpdate"
        static let diskThreshold = "notifyDiskThreshold"
        static let migratedV2 = "pharos.notificationsMigratedV2"
    }

    private var state = AlertState()
    private var dismissedInAppAlertIDs: Set<String> = []
    private var cancellable: AnyCancellable?
    private weak var store: ProjectStore?

    private override init() {
        let d = UserDefaults.standard
        let isMigrated = d.bool(forKey: Keys.migratedV2)

        let initialMemory: Bool
        let initialDisk: Bool
        let initialFavoriteExit: Bool
        let initialThermal: Bool
        let initialBloat: Bool
        let initialAppUpdate: Bool
        let initialDiskThreshold: Double

        if !isMigrated {
            // Fresh install or v3.2.0 upgrade: enable core guard notifications by default
            initialMemory = true
            initialDisk = true
            initialFavoriteExit = true
            initialThermal = true
            initialBloat = true
            initialAppUpdate = true
            initialDiskThreshold = 0.90
        } else {
            initialMemory = d.object(forKey: Keys.memory) as? Bool ?? true
            initialDisk = d.object(forKey: Keys.disk) as? Bool ?? true
            initialFavoriteExit = d.object(forKey: Keys.favoriteExit) as? Bool ?? true
            initialThermal = d.object(forKey: Keys.thermal) as? Bool ?? true
            initialBloat = d.object(forKey: Keys.bloat) as? Bool ?? true
            initialAppUpdate = d.object(forKey: Keys.appUpdate) as? Bool ?? true
            let savedThreshold = d.double(forKey: Keys.diskThreshold)
            initialDiskThreshold = savedThreshold > 0.50 ? savedThreshold : 0.90
        }

        memory = initialMemory
        disk = initialDisk
        favoriteExit = initialFavoriteExit
        thermal = initialThermal
        bloat = initialBloat
        appUpdate = initialAppUpdate
        diskThreshold = initialDiskThreshold

        super.init()

        if !isMigrated {
            d.set(initialMemory, forKey: Keys.memory)
            d.set(initialDisk, forKey: Keys.disk)
            d.set(initialFavoriteExit, forKey: Keys.favoriteExit)
            d.set(initialThermal, forKey: Keys.thermal)
            d.set(initialBloat, forKey: Keys.bloat)
            d.set(initialAppUpdate, forKey: Keys.appUpdate)
            d.set(initialDiskThreshold, forKey: Keys.diskThreshold)
            d.set(true, forKey: Keys.migratedV2)
        }
    }

    func resetSettings() {
        memory = true
        disk = true
        favoriteExit = true
        thermal = true
        bloat = true
        appUpdate = true
        diskThreshold = 0.90
    }

    func enableAll() {
        memory = true
        disk = true
        favoriteExit = true
        thermal = true
        bloat = true
        appUpdate = true
        requestIfNeeded()
    }

    var anyEnabled: Bool {
        memory || disk || favoriteExit || thermal || bloat || appUpdate
    }

    func start(observing store: ProjectStore) {
        self.store = store
        cancellable = store.$state
            .map(\.lastScan)
            .removeDuplicates()
            .sink { [weak self] _ in Task { @MainActor in self?.evaluate() } }

        guard Bundle.main.bundleIdentifier != nil, Bundle.main.bundleURL.pathExtension == "app" else {
            return
        }

        UNUserNotificationCenter.current().delegate = self
        refreshAuthorization()
    }

    // MARK: - UNUserNotificationCenterDelegate (Foreground Popups & Direct Click)

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Force prominent banner and sound even if Pharos is the active frontmost app
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        Task { @MainActor in
            Notifier.shared.handleNotificationClick(identifier: identifier)
        }
        completionHandler()
    }

    func handleNotificationClick(identifier: String) {
        AppDelegate.shared?.showMainWindow()

        if identifier.hasPrefix("memory") || identifier.hasPrefix("bloat") {
            WindowRouter.shared.request = .systemMemory
        } else if identifier.hasPrefix("disk") {
            WindowRouter.shared.request = .diskCleanup
        } else if identifier.hasPrefix("thermal") {
            WindowRouter.shared.request = .thermals
        } else if identifier.hasPrefix("favorite") {
            WindowRouter.shared.request = .portsOverview
        } else if identifier.hasPrefix("update") {
            WindowRouter.shared.request = .settings
        }
    }

    // MARK: - Evaluation & In-App Banners

    private func evaluate() {
        guard let store, store.lastScan != nil else { return }
        let workspaces = WorkspaceStore.shared
        let running = workspaces.running(in: store.projects)
        let stopped = store.stoppedByUser()
        let favorites = workspaces.favorites.map { (id: $0.id, name: $0.name, ports: $0.lastPorts) }
        let byUser = Set(workspaces.favorites.filter { f in
            stopped.contains { $0 == f.directory || $0.hasPrefix(f.directory + "/") }
        }.map(\.id))

        let chipPeak = store.thermals?.peakChipTemperature
        let topCulprit = store.thermalDiagnosis?.culprits.first?.name

        let diag = store.memoryDiagnosis
        let bloatInfo: (count: Int, reclaimableBytes: UInt64, topDaemon: String)?
        if diag.hasBloat {
            let topName = diag.bloatedItems.first?.daemon.primaryName ?? "daemon"
            bloatInfo = (count: diag.bloatedCount, reclaimableBytes: diag.reclaimableBytes, topDaemon: topName)
        } else {
            bloatInfo = nil
        }

        let alerts = state.update(
            memory: store.system,
            volumes: store.volumes,
            favorites: favorites,
            runningFavoriteIDs: Set(running.keys),
            stoppedByUser: byUser,
            peakChipTemperature: chipPeak,
            topCulpritName: topCulprit,
            daemonBloat: bloatInfo,
            diskThreshold: diskThreshold
        )

        // 1. Deliver macOS system notification banners
        if anyEnabled && !denied {
            for alert in alerts { deliver(alert) }
        }

        // 2. Compute active in-app alerts
        computeActiveInAppAlerts(
            store: store,
            chipPeak: chipPeak,
            topCulprit: topCulprit,
            diag: diag
        )
    }

    private func computeActiveInAppAlerts(
        store: ProjectStore,
        chipPeak: Double?,
        topCulprit: String?,
        diag: MemoryDiagnosisReport
    ) {
        let l10n = L10n.shared
        var current: [ActiveAlertBanner] = []

        // 1. Thermal Overheat (≥ 85°C)
        if let temp = chipPeak, temp >= AlertState.thermalTriggerCelsius {
            let id = "thermal"
            if !dismissedInAppAlertIDs.contains(id) {
                let rounded = Int(temp.rounded())
                current.append(ActiveAlertBanner(
                    id: id,
                    icon: "thermometer.sun.fill",
                    title: l10n.inAppAlertThermalTitle(rounded),
                    subtitle: l10n.inAppAlertThermalSub(topCulprit ?? "high CPU load"),
                    level: temp >= 95.0 ? .critical : .warning,
                    targetItem: .thermals
                ))
            }
        } else {
            dismissedInAppAlertIDs.remove("thermal")
        }

        // 2. Memory Pressure Warning/Critical
        if let sys = store.system, sys.pressure != .normal {
            let id = "memory"
            if !dismissedInAppAlertIDs.contains(id) {
                let pct = Int((sys.usedFraction * 100).rounded())
                current.append(ActiveAlertBanner(
                    id: id,
                    icon: "memorychip.fill",
                    title: l10n.inAppAlertMemoryTitle,
                    subtitle: l10n.inAppAlertMemorySub(pct),
                    level: sys.pressure == .critical ? .critical : .warning,
                    targetItem: .systemMemory
                ))
            }
        } else {
            dismissedInAppAlertIDs.remove("memory")
        }

        // 3. Daemon Bloat (≥ 500 MB)
        if diag.reclaimableBytes >= AlertState.daemonBloatTriggerBytes {
            let id = "bloat"
            if !dismissedInAppAlertIDs.contains(id) {
                let top = diag.bloatedItems.first?.daemon.primaryName ?? "daemon"
                current.append(ActiveAlertBanner(
                    id: id,
                    icon: "exclamationmark.triangle.fill",
                    title: l10n.inAppAlertBloatTitle,
                    subtitle: l10n.inAppAlertBloatSub(ByteFormat.short(diag.reclaimableBytes), top),
                    level: .warning,
                    targetItem: .systemMemory
                ))
            }
        } else {
            dismissedInAppAlertIDs.remove("bloat")
        }

        // 4. Startup Disk Space (≥ threshold)
        if let disk = store.volumes.first(where: { $0.kind == .startup }), disk.usedFraction >= diskThreshold {
            let id = "disk"
            if !dismissedInAppAlertIDs.contains(id) {
                current.append(ActiveAlertBanner(
                    id: id,
                    icon: "internaldrive.fill",
                    title: l10n.inAppAlertDiskTitle(disk.name),
                    subtitle: l10n.inAppAlertDiskSub(ByteFormat.disk(disk.available)),
                    level: disk.usedFraction >= 0.95 ? .critical : .warning,
                    targetItem: .diskCleanup
                ))
            }
        } else {
            dismissedInAppAlertIDs.remove("disk")
        }

        self.activeInAppAlerts = current
    }

    func dismissInAppAlert(id: String) {
        dismissedInAppAlertIDs.insert(id)
        activeInAppAlerts.removeAll { $0.id == id }
    }

    // MARK: - Delivery

    private func deliver(_ alert: AlertState.Alert) {
        guard Bundle.main.bundleIdentifier != nil, Bundle.main.bundleURL.pathExtension == "app" else {
            return
        }
        let l10n = L10n.shared
        let content = UNMutableNotificationContent()
        let id: String

        switch alert {
        case .memoryPressure(let used, let total):
            guard memory else { return }
            content.title = l10n.notifyMemoryTitle
            content.body = l10n.notifyMemoryBody(ByteFormat.short(used), ByteFormat.short(total))
            id = "memory"
        case .diskAlmostFull(let name, let path, let available):
            guard disk else { return }
            content.title = l10n.notifyDiskTitle(name)
            content.body = l10n.notifyDiskBody(ByteFormat.disk(available))
            id = "disk:" + path
        case .favoriteStopped(let fid, let name, let ports):
            guard favoriteExit else { return }
            content.title = l10n.notifyExitTitle(name)
            content.body = l10n.notifyExitBody(ports.isEmpty ? "—" : ports.map { ":\($0)" }.joined(separator: " "))
            id = "favorite:" + fid
        case .thermalOverheat(let peakCelsius, let culpritName):
            guard thermal else { return }
            content.title = l10n.notifyThermalTitle
            content.body = l10n.notifyThermalBody("\(Int(peakCelsius.rounded()))°C", culpritName)
            id = "thermal"
        case .daemonBloat(let count, let reclaimableBytes, let topDaemon):
            guard bloat else { return }
            content.title = l10n.notifyBloatTitle
            content.body = l10n.notifyBloatBody(count, ByteFormat.short(reclaimableBytes), topDaemon)
            id = "bloat"
        }

        content.sound = .default
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    public func notifyUpdateAvailable(version: String) {
        guard appUpdate, !denied else { return }
        guard Bundle.main.bundleIdentifier != nil, Bundle.main.bundleURL.pathExtension == "app" else { return }

        let l10n = L10n.shared
        let content = UNMutableNotificationContent()
        content.title = l10n.notifyUpdateTitle(version)
        content.body = l10n.notifyUpdateBody(version)
        content.sound = .default
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "update:\(version)", content: content, trigger: nil))
    }

    public func sendTestNotification() {
        guard Bundle.main.bundleIdentifier != nil, Bundle.main.bundleURL.pathExtension == "app" else {
            return
        }

        requestIfNeeded()

        let l10n = L10n.shared
        let content = UNMutableNotificationContent()
        content.title = l10n.testNotificationTitle
        content.body = l10n.testNotificationBody
        content.sound = .default
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let id = "test:\(UUID().uuidString)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { [weak self] error in
            if error == nil {
                Task { @MainActor in
                    self?.testNotificationDelivered = true
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    self?.testNotificationDelivered = false
                }
            }
        }
    }

    private func requestIfNeeded() {
        guard Bundle.main.bundleIdentifier != nil, Bundle.main.bundleURL.pathExtension == "app" else {
            return
        }
        guard anyEnabled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { @MainActor in self?.denied = !granted }
        }
    }

    func refreshAuthorization() {
        guard Bundle.main.bundleIdentifier != nil, Bundle.main.bundleURL.pathExtension == "app" else {
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let off = settings.authorizationStatus == .denied
            Task { @MainActor in self?.denied = off }
        }
    }

    private func save(_ value: Bool, _ key: String) { UserDefaults.standard.set(value, forKey: key) }
    private func saveDouble(_ value: Double, _ key: String) { UserDefaults.standard.set(value, forKey: key) }
}
