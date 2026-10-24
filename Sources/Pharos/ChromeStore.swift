import AppKit
import PharosCore

/// Chrome instances: running ones (from ProjectStore's scan) and saved presets.
/// Start launches Chrome directly; Quit sends SIGTERM to the browser process
/// (Chrome's normal shutdown), offering a force quit only if it stays alive.
@MainActor
final class ChromeStore: ObservableObject {
    static let shared = ChromeStore()

    /// A preset and/or a running instance, matched by profile folder.
    struct Entry: Identifiable {
        let preset: ChromePreset?
        let running: ChromeInstance?

        var id: String { preset?.id ?? "running:" + (running?.id ?? "") }
        var config: ChromeConfig { running?.config ?? preset?.config ?? ChromeConfig() }
        var isRunning: Bool { running != nil }
    }

    @Published private(set) var presets: [ChromePreset] = []
    @Published private(set) var folderSizes: [String: UInt64] = [:]
    @Published private(set) var sizing = false
    /// Signed-in profile names per user-data-dir. Read off the main thread and
    /// cached by the file's mtime, so card redraws never touch the disk.
    @Published private(set) var profileNames: [String: [String]] = [:]
    private var profileStamps: [String: Date] = [:]
    private var loadingProfiles: Set<String> = []
    /// Instances that survived SIGTERM; UI offers force quit.
    @Published private(set) var stubborn: Set<String> = []
    @Published var errorMessage: String?

    private static let key = "chromePresets.v1"

    private init() {
        let d = UserDefaults.standard
        hiddenBrowsers = Set((d.stringArray(forKey: Self.hiddenKey) ?? []).compactMap(ChromiumBrowser.init))
        defaultBrowser = d.string(forKey: Self.defaultBrowserKey).flatMap(ChromiumBrowser.init)
            ?? installedBrowsers.first ?? .chrome
        if let data = d.data(forKey: Self.key) {
            do { presets = try JSONDecoder().decode([ChromePreset].self, from: data) }
            catch { errorMessage = L10n.shared.chromeLoadFailed }
        }
    }

    var chromeInstalled: Bool { !installedBrowsers.isEmpty }
    /// Checked once: installing a browser while Pharos runs is rare, and a
    /// stale list only hides the picker entry until the next launch.
    let installedBrowsers = ChromeInstances.installedBrowsers()

    func isInstalled(_ b: ChromiumBrowser) -> Bool { FileManager.default.fileExists(atPath: b.appPath) }

    /// Browsers hidden from the instances page (Settings → Browsers). Presets are kept.
    @Published var hiddenBrowsers: Set<ChromiumBrowser> {
        didSet { UserDefaults.standard.set(hiddenBrowsers.map(\.rawValue).sorted(), forKey: Self.hiddenKey) }
    }
    /// Browser used by "New Instance".
    @Published var defaultBrowser: ChromiumBrowser {
        didSet { UserDefaults.standard.set(defaultBrowser.rawValue, forKey: Self.defaultBrowserKey) }
    }
    private static let hiddenKey = "hiddenBrowsers"
    private static let defaultBrowserKey = "defaultBrowser"

    func isVisible(_ b: ChromiumBrowser) -> Bool { !hiddenBrowsers.contains(b) }

    func setVisible(_ b: ChromiumBrowser, _ visible: Bool) {
        if visible { hiddenBrowsers.remove(b) } else { hiddenBrowsers.insert(b) }
    }

    func resetSettings() {
        hiddenBrowsers = []
        defaultBrowser = installedBrowsers.first ?? .chrome
    }

    func revealDefaultProfile(_ b: ChromiumBrowser) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: b.defaultUserDataDir)
    }

    /// Presets and running instances of visible browsers, matched by browser + profile folder.
    func entries(_ running: [ChromeInstance], browser: ChromiumBrowser? = nil) -> [Entry] {
        func key(_ c: ChromeConfig) -> String { c.browser.rawValue + ":" + c.profileKey }
        let shown: (ChromeConfig) -> Bool = { c in
            self.isVisible(c.browser) && (browser == nil || c.browser == browser)
        }
        var byProfile = Dictionary(running.map { (key($0.config), $0) }, uniquingKeysWith: { a, _ in a })
        var out: [Entry] = presets.map { preset in
            Entry(preset: preset, running: byProfile.removeValue(forKey: key(preset.config)))
        }
        out += running.filter { byProfile[key($0.config)] != nil }.map { Entry(preset: nil, running: $0) }
        return out.filter { shown($0.config) }
    }

    /// Browsers that have something to show (installed, or with a preset / running instance).
    func browsersInUse(_ running: [ChromeInstance]) -> [ChromiumBrowser] {
        let used = Set(presets.map(\.config.browser) + running.map(\.config.browser))
        return ChromiumBrowser.allCases.filter { isVisible($0) && (used.contains($0) || isInstalled($0)) }
    }

    func preset(id: String) -> ChromePreset? { presets.first { $0.id == id } }

    // MARK: - Presets

    func save(_ instance: ChromeInstance) {
        let c = instance.config
        guard !presets.contains(where: { $0.config.browser == c.browser && $0.config.profileKey == c.profileKey }) else { return }
        presets.append(ChromePreset(name: defaultName(c), config: c))
        persist()
    }

    /// The instance was relaunched with different flags than the preset stores.
    func adopt(_ instance: ChromeInstance, into presetID: String) {
        guard let i = presets.firstIndex(where: { $0.id == presetID }) else { return }
        presets[i].config = instance.config
        persist()
    }

    func copyCommand(_ config: ChromeConfig) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ChromeInstances.shellCommand(config), forType: .string)
    }

    @discardableResult
    func addPreset(browser: ChromiumBrowser? = nil) -> String {
        let b = browser ?? defaultBrowser
        let used = Set(presets.compactMap(\.config.debugPort))
        let port = (9222...9999).first { !used.contains(UInt16($0)) }.map(UInt16.init) ?? 9222
        let folder = b == .chrome ? "chrome" : b.rawValue.lowercased()
        let preset = ChromePreset(name: "\(b.appName) \(port)", config: ChromeConfig(
            browser: b, userDataDir: NSHomeDirectory() + "/\(folder)\(port)", debugPort: port,
            extraFlags: ["--no-first-run", "--no-default-browser-check"]))
        presets.append(preset)
        persist()
        return preset.id
    }

    func update(_ preset: ChromePreset) {
        guard let i = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[i] = preset
        persist()
    }

    func remove(id: String) {
        presets.removeAll { $0.id == id }
        persist()
    }

    func add(_ imported: [ChromePreset]) {
        guard !imported.isEmpty else { return }
        presets += imported
        persist()
    }

    // MARK: - Actions

    func start(_ config: ChromeConfig, running: [ChromeInstance], listening: Set<UInt16>) {
        let l10n = L10n.shared
        guard isInstalled(config.browser) else { errorMessage = l10n.browserNotInstalled(config.browser.appName); return }
        let problems = ChromeInstances.problems(for: config, running: running, listeningPorts: listening)
        if problems.contains(.alreadyRunning) { errorMessage = l10n.chromeAlreadyRunning; return }
        if let port = problems.compactMap({ if case .portInUse(let p) = $0 { return p } else { return nil } }).first {
            errorMessage = l10n.portInUse(port)
            return
        }
        if let dir = config.userDataDir, !config.isDefaultProfile {
            do { try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true) }
            catch { errorMessage = l10n.chromeStartFailed(error.localizedDescription); return }
        }
        // `open -n` starts a separate Chrome app instance with these flags,
        // the same as launching it from a terminal; it isn't our child.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-na", config.browser.appPath, "--args"] + ChromeInstances.launchArguments(config)
        let errPipe = Pipe()
        p.standardError = errPipe
        p.terminationHandler = { [weak self] proc in
            guard proc.terminationStatus != 0 else { return }
            let msg = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            Task { @MainActor in
                self?.errorMessage = L10n.shared.chromeStartFailed(msg.isEmpty ? "exit \(proc.terminationStatus)" : msg)
            }
        }
        do { try p.run() } catch { errorMessage = l10n.chromeStartFailed(error.localizedDescription) }
    }

    func quit(_ instance: ChromeInstance, then refresh: @escaping () async -> Void) {
        guard instance.pid > 1, instance.pid != getpid() else { return }
        ProcessControl.send(.terminate, to: [instance.pid])
        let key = instance.id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if ProcessControl.isAlive(instance.pid) { self?.stubborn.insert(key) }
            await refresh()
        }
    }

    func forceQuit(_ instance: ChromeInstance, then refresh: @escaping () async -> Void) {
        let me = getpid()
        ProcessControl.send(.kill, to: instance.allPIDs.filter { $0 > 1 && $0 != me })
        stubborn.remove(instance.id)
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await refresh()
        }
    }

    func clearStubborn(keeping alive: Set<String>) {
        let next = stubborn.intersection(alive)
        if next != stubborn { stubborn = next }
    }

    func openDevToolsList(port: UInt16) {
        if let url = URL(string: "http://127.0.0.1:\(port)") { NSWorkspace.shared.open(url) }
    }

    func reveal(_ config: ChromeConfig) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: config.profileKey)
    }

    /// Profile folders can be GBs; measured on demand, off the main thread.
    func measureSizes(_ dirs: [String]) {
        guard !sizing else { return }
        sizing = true
        Task { [weak self] in
            let sizes = await Task.detached(priority: .utility) {
                Dictionary(dirs.map { ($0, ChromeInstances.folderSize($0)) }, uniquingKeysWith: { a, _ in a })
            }.value
            self?.folderSizes = sizes
            self?.sizing = false
        }
    }

    // MARK: - Private

    /// Reloads names only for folders whose "Local State" changed since last time.
    func loadProfileNames(_ dirs: [String]) {
        let todo = Set(dirs).subtracting(loadingProfiles)
        guard !todo.isEmpty else { return }
        loadingProfiles.formUnion(todo)
        let known = profileStamps
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) { () -> [(String, Date?, [String])?] in
                todo.map { dir in
                    let stamp = (try? FileManager.default.attributesOfItem(atPath: dir + "/Local State"))?[.modificationDate] as? Date
                    if let stamp, known[dir] == stamp { return nil }
                    return (dir, stamp, ChromeInstances.profileNames(in: dir))
                }
            }.value
            guard let self else { return }
            self.loadingProfiles.subtract(todo)
            var names = self.profileNames
            for case let (dir, stamp, list)? in result {
                names[dir] = list
                self.profileStamps[dir] = stamp
            }
            if names != self.profileNames { self.profileNames = names }
        }
    }

    private func defaultName(_ c: ChromeConfig) -> String {
        if c.isDefaultProfile { return L10n.shared.browserMain(c.browser.appName) }
        let folder = (c.profileKey as NSString).lastPathComponent
        return c.debugPort.map { "\(folder) · \($0)" } ?? folder
    }

    private func persist() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(presets), forKey: Self.key) }
        catch { errorMessage = L10n.shared.chromeSaveFailed }
    }
}
