import Combine
import Foundation
import PharosCore
import UserNotifications

/// Local notifications (no network): memory pressure, a nearly full disk, a
/// favorite project that stopped on its own. Each kind can be turned off.
@MainActor
final class Notifier: ObservableObject {
    static let shared = Notifier()

    @Published var memory: Bool { didSet { save(memory, Keys.memory); requestIfNeeded() } }
    @Published var disk: Bool { didSet { save(disk, Keys.disk); requestIfNeeded() } }
    @Published var favoriteExit: Bool { didSet { save(favoriteExit, Keys.favoriteExit); requestIfNeeded() } }
    /// Set when macOS has notifications turned off for Pharos.
    @Published private(set) var denied = false

    private enum Keys {
        static let memory = "notifyMemory"
        static let disk = "notifyDisk"
        static let favoriteExit = "notifyFavoriteExit"
    }

    private var state = AlertState()
    private var cancellable: AnyCancellable?
    private weak var store: ProjectStore?

    private init() {
        let d = UserDefaults.standard
        memory = d.object(forKey: Keys.memory) as? Bool ?? false
        disk = d.object(forKey: Keys.disk) as? Bool ?? false
        favoriteExit = d.object(forKey: Keys.favoriteExit) as? Bool ?? false
    }

    var anyEnabled: Bool { memory || disk || favoriteExit }

    func start(observing store: ProjectStore) {
        self.store = store
        cancellable = store.$state
            .map(\.lastScan)
            .removeDuplicates()
            .sink { [weak self] _ in Task { @MainActor in self?.evaluate() } }
        refreshAuthorization()
    }

    private func evaluate() {
        guard let store, store.lastScan != nil else { return }
        let workspaces = WorkspaceStore.shared
        let running = workspaces.running(in: store.projects)
        let stopped = store.stoppedByUser()
        let favorites = workspaces.favorites.map { (id: $0.id, name: $0.name, ports: $0.lastPorts) }
        // Stopped from Pharos (the project folder sits inside the favorite) → expected.
        let byUser = Set(workspaces.favorites.filter { f in
            stopped.contains { $0 == f.directory || $0.hasPrefix(f.directory + "/") }
        }.map(\.id))
        let alerts = state.update(memory: store.system, volumes: store.volumes, favorites: favorites,
                                  runningFavoriteIDs: Set(running.keys), stoppedByUser: byUser)
        guard anyEnabled, !denied else { return }
        for alert in alerts { deliver(alert) }
    }

    private func deliver(_ alert: AlertState.Alert) {
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
        }
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    private func requestIfNeeded() {
        guard anyEnabled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in self?.denied = !granted }
        }
    }

    func refreshAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let off = settings.authorizationStatus == .denied
            Task { @MainActor in self?.denied = off }
        }
    }

    private func save(_ value: Bool, _ key: String) { UserDefaults.standard.set(value, forKey: key) }
}
