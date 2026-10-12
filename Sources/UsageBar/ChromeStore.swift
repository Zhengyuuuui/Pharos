import AppKit
import UsageBarCore

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
    /// Instances that survived SIGTERM; UI offers force quit.
    @Published private(set) var stubborn: Set<String> = []
    @Published var errorMessage: String?

    private static let key = "chromePresets.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key) {
            do { presets = try JSONDecoder().decode([ChromePreset].self, from: data) }
            catch { errorMessage = L10n.shared.chromeLoadFailed }
        }
    }

    var chromeInstalled: Bool { FileManager.default.fileExists(atPath: ChromeInstances.appPath) }

    func entries(_ running: [ChromeInstance]) -> [Entry] {
        var byProfile = Dictionary(running.map { ($0.config.profileKey, $0) }, uniquingKeysWith: { a, _ in a })
        var out: [Entry] = presets.map { preset in
            Entry(preset: preset, running: byProfile.removeValue(forKey: preset.config.profileKey))
        }
        out += running.filter { byProfile[$0.config.profileKey] != nil }.map { Entry(preset: nil, running: $0) }
        return out
    }

    func preset(id: String) -> ChromePreset? { presets.first { $0.id == id } }

    // MARK: - Presets

    func save(_ instance: ChromeInstance) {
        guard !presets.contains(where: { $0.config.profileKey == instance.config.profileKey }) else { return }
        presets.append(ChromePreset(name: defaultName(instance.config), config: instance.config))
        persist()
    }

    @discardableResult
    func addPreset() -> String {
        let used = Set(presets.compactMap(\.config.debugPort))
        let port = (9222...9999).first { !used.contains(UInt16($0)) }.map(UInt16.init) ?? 9222
        let preset = ChromePreset(name: "Chrome \(port)", config: ChromeConfig(
            userDataDir: NSHomeDirectory() + "/chrome\(port)", debugPort: port,
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

    // MARK: - Actions

    func start(_ config: ChromeConfig, running: [ChromeInstance], listening: Set<UInt16>) {
        let l10n = L10n.shared
        guard chromeInstalled else { errorMessage = l10n.chromeNotInstalled; return }
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
        p.arguments = ["-na", ChromeInstances.appPath, "--args"] + ChromeInstances.launchArguments(config)
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

    private func defaultName(_ c: ChromeConfig) -> String {
        if c.isDefaultProfile { return L10n.shared.chromeMain }
        let folder = (c.profileKey as NSString).lastPathComponent
        return c.debugPort.map { "\(folder) · \($0)" } ?? folder
    }

    private func persist() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(presets), forKey: Self.key) }
        catch { errorMessage = L10n.shared.chromeSaveFailed }
    }
}
