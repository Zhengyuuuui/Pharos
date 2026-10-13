import AppKit
import PharosCore

/// Scans processes, ports and machine memory. Polls at `refreshSeconds` while a
/// popover / main window is visible, otherwise every `backgroundSeconds` so the
/// memory-history charts have data when opened.
@MainActor
final class ProjectStore: ObservableObject {
    /// Everything one scan produces, published as a single value: each separate
    /// @Published write re-renders every observing view (and its GPU layers).
    struct ScanState {
        var projects: [Project] = []
        var chrome: [ChromeInstance] = []
        /// Every TCP port any of the user's processes listens on (for launch conflict checks).
        var listeningPorts: Set<UInt16> = []
        var apps: [AppUsage] = []
        var system: SystemMemoryStats?
        var volumes: [DiskVolume] = []
        var thermals: ThermalSnapshot?
        var thermalState: ProcessInfo.ThermalState = .nominal
        var history = MemoryHistory(window: 3600, minInterval: 10)
        var lastScan: Date?
    }

    @Published private(set) var state = ScanState()
    /// Not @Published: only the refresh spinner needs it (see `ScanActivity`).
    let activity = ScanActivity()

    var projects: [Project] { state.projects }
    var chrome: [ChromeInstance] { state.chrome }
    var apps: [AppUsage] { state.apps }
    var system: SystemMemoryStats? { state.system }
    var volumes: [DiskVolume] { state.volumes }
    var thermals: ThermalSnapshot? { state.thermals }
    var thermalState: ProcessInfo.ThermalState { state.thermalState }
    var history: MemoryHistory { state.history }
    var lastScan: Date? { state.lastScan }
    var isScanning: Bool { activity.isScanning }
    /// Projects that survived SIGTERM; UI offers a force kill for these.
    @Published private(set) var stubborn: Set<String> = []

    @Published var refreshSeconds: Int {
        didSet {
            UserDefaults.standard.set(refreshSeconds, forKey: Keys.refresh)
            scheduleTimer()
        }
    }
    @Published var showSystem: Bool {
        didSet {
            UserDefaults.standard.set(showSystem, forKey: Keys.showSystem)
            Task { await refresh() }
        }
    }

    private enum Keys {
        static let refresh = "refreshSeconds"
        static let showSystem = "showSystemProcesses"
    }

    private let backgroundSeconds: TimeInterval = 30
    private var timer: Timer?
    private var viewers = 0
    private var mountObservers: [NSObjectProtocol] = []

    init() {
        let saved = UserDefaults.standard.integer(forKey: Keys.refresh)
        refreshSeconds = saved > 0 ? saved : 5
        showSystem = UserDefaults.standard.bool(forKey: Keys.showSystem)
        scheduleTimer()
        // A drive plugged in or ejected shows up right away, not at the next poll.
        let center = NSWorkspace.shared.notificationCenter
        mountObservers = [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification,
                          NSWorkspace.didRenameVolumeNotification].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.refreshVolumes() }
            }
        }
        Task { await refresh() }
    }

    deinit {
        timer?.invalidate()
        let center = NSWorkspace.shared.notificationCenter
        mountObservers.forEach(center.removeObserver)
    }

    var totalMemory: UInt64 { projects.reduce(0) { $0 + $1.memoryBytes } }
    var totalPorts: Int { projects.reduce(0) { $0 + $1.ports.count } }
    var exposedPorts: Int { projects.reduce(0) { $0 + $1.ports.filter { !$0.loopbackOnly }.count } }
    /// Sum of footprints of the current user's processes.
    var userAppsMemory: UInt64 { apps.reduce(0) { $0 + $1.memoryBytes } }

    func project(id: String) -> Project? { projects.first { $0.id == id } }

    // MARK: - Visibility-driven polling

    func viewAppeared() {
        viewers += 1
        if viewers == 1 {
            Task { await refresh() }
            scheduleTimer()
        }
    }

    func viewDisappeared() {
        viewers = max(0, viewers - 1)
        if viewers == 0 { scheduleTimer() }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = viewers > 0 ? TimeInterval(refreshSeconds) : backgroundSeconds
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        guard !activity.isScanning else { return }
        activity.isScanning = true
        defer { activity.isScanning = false }
        // Not awaited: a slow or disconnected network share must not delay ports/memory.
        Task { await refreshVolumes() }
        Task { await refreshThermals() }
        let include = showSystem
        let (projects, chrome, ports, apps, system) = await Task.detached(priority: .utility) {
            let all = ProcessScanner.scan()
            let chrome = ChromeInstances.find(in: all)
            // Chrome instances get their own page; keep debug-port browsers out
            // of the project list even when "show background apps" is on.
            let chromePIDs = Set(chrome.flatMap(\.allPIDs))
            return (ProjectGrouper.group(all.filter { !chromePIDs.contains($0.pid) }, includeSystem: include),
                    chrome,
                    Set(all.flatMap { $0.ports.map(\.port) }),
                    AppGrouper.group(all),
                    SystemMemory.read())
        }.value
        let now = Date()
        var next = state
        next.projects = projects
        next.chrome = chrome
        next.listeningPorts = ports
        next.apps = apps
        if let system { next.system = system }
        next.history.append(MemorySample(
            date: now,
            systemUsed: system?.used ?? 0,
            projects: projects.map { ProjectSample(id: $0.id, name: $0.name, bytes: $0.memoryBytes) }
        ))
        next.lastScan = now
        state = next
        let alive = stubborn.intersection(projects.map(\.id))
        if alive != stubborn { stubborn = alive }
        ChromeStore.shared.clearStubborn(keeping: Set(chrome.map(\.id)))
    }

    /// At most one read in flight: if a share hangs, later polls skip instead of piling up threads.
    private var readingVolumes = false

    private func refreshVolumes() async {
        guard !readingVolumes else { return }
        readingVolumes = true
        defer { readingVolumes = false }
        let volumes = await Task.detached(priority: .utility) { DiskVolumes.read() }.value
        if volumes != state.volumes { state.volumes = volumes }
    }

    private var readingThermals = false

    /// Separate task like volumes: SMC reads are fast (~50 ms) but the first one
    /// enumerates every key (~300 ms) and must not hold up the process scan.
    func refreshThermals() async {
        guard !readingThermals else { return }
        readingThermals = true
        defer { readingThermals = false }
        let snap = await Task.detached(priority: .utility) { Thermals.read() }.value
        let level = ProcessInfo.processInfo.thermalState
        if snap != state.thermals || level != state.thermalState {
            var next = state
            next.thermals = snap
            next.thermalState = level
            state = next
        }
    }

    func revealVolume(_ v: DiskVolume) {
        NSWorkspace.shared.open(URL(fileURLWithPath: v.path, isDirectory: true))
    }

    // MARK: - Actions

    func terminate(_ project: Project) {
        recentlyStopped[project.directory ?? project.id] = Date()
        let pids = killablePIDs(project)
        ProcessControl.send(.terminate, to: pids)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard let self else { return }
            if pids.contains(where: ProcessControl.isAlive) {
                self.stubborn.insert(project.id)
            }
            await self.refresh()
        }
    }

    func forceKill(_ project: Project) {
        recentlyStopped[project.directory ?? project.id] = Date()
        ProcessControl.send(.kill, to: killablePIDs(project))
        stubborn.remove(project.id)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            await self?.refresh()
        }
    }

    /// Project folders stopped from Pharos, so the "stopped unexpectedly"
    /// notification skips them. Entries expire after a minute.
    private var recentlyStopped: [String: Date] = [:]

    func stoppedByUser(within seconds: TimeInterval = 60) -> Set<String> {
        let cutoff = Date().addingTimeInterval(-seconds)
        recentlyStopped = recentlyStopped.filter { $0.value > cutoff }
        return Set(recentlyStopped.keys)
    }

    private func killablePIDs(_ project: Project) -> [Int32] {
        let me = getpid()
        return project.allPIDs.filter { $0 != me }
    }

    func openInBrowser(_ port: ListeningPort) {
        guard let url = URL(string: "http://localhost:\(port.port)") else { return }
        NSWorkspace.shared.open(url)
    }

    func revealInFinder(_ project: Project) {
        guard let dir = project.directory else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir)
    }
}

/// Separate tiny observable so the spinner can update without re-rendering charts.
@MainActor
final class ScanActivity: ObservableObject {
    @Published var isScanning = false
}
