import AppKit
import Darwin
import PharosCore

/// Manages battery charging telemetry, target limits, and IPC with the optional `pharos-battd` root helper.
/// Strictly non-root in the main app: privileges are only requested once via macOS's native administrator prompt.
@MainActor
final class BatteryStore: ObservableObject {
    static let shared = BatteryStore()

    enum HelperState: Equatable {
        case notInstalled
        case notResponding
        case ready
    }

    @Published private(set) var reading: BatteryReading = BatteryReading()
    @Published private(set) var capabilities: BatteryHardwareCapabilities = BatteryHardwareCapabilities()
    @Published private(set) var helper: HelperState = .notInstalled
    @Published private(set) var mode: BatteryMode = .system
    @Published private(set) var isHolding: Bool = false
    @Published private(set) var isAdapterBypassed: Bool = false
    @Published private(set) var unsupported: Bool = false
    @Published private(set) var busy: Bool = false
    @Published var errorMessage: String?

    /// User's chosen charge limit (e.g. 80%), persisted in UserDefaults.
    @Published var targetLimit: Int = UserDefaults.standard.object(forKey: "batteryTargetLimit") as? Int ?? 80 {
        didSet {
            UserDefaults.standard.set(targetLimit, forKey: "batteryTargetLimit")
            if case .limit = mode {
                apply(.limit(maxPercent: targetLimit))
            }
        }
    }

    /// Whether to synchronize MagSafe LED state with charging limit.
    @Published var syncMagSafe: Bool = UserDefaults.standard.object(forKey: "batterySyncMagSafe") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(syncMagSafe, forKey: "batterySyncMagSafe")
            let flag = syncMagSafe
            Task {
                _ = await Task.detached { BatteryStore.send(.syncMagSafe(flag)) }.value
            }
        }
    }

    private var heartbeatTimer: Timer?
    private var telemetryTimer: Timer?

    private init() {
        capabilities = BatteryScanner.probeCapabilities()
        refreshTelemetry()
        refreshHelperState()

        // Heartbeat every 5s keeps margin well within the 15s daemon timeout
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.beat() }
        }

        // Low-frequency telemetry refresh every 3 seconds
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshTelemetry() }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Best effort restore to system charging on app exit
            _ = BatteryStore.send(.setMode(.system))
        }
    }

    deinit {
        heartbeatTimer?.invalidate()
        telemetryTimer?.invalidate()
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: BatteryHelperInstall.plistPath)
    }

    // MARK: - Telemetry

    func refreshTelemetry() {
        if let r = BatteryScanner.read() {
            reading = r
        }
    }

    // MARK: - Control Actions

    func apply(_ newMode: BatteryMode) {
        guard helper == .ready else {
            mode = newMode
            return
        }
        busy = true
        Task {
            let reply = await Task.detached { BatteryStore.send(.setMode(newMode)) }.value
            busy = false
            handle(reply, failure: L10n.shared.batteryCommandFailed)
            refreshTelemetry()
        }
    }

    func chargeToFullNow() {
        apply(.full)
    }

    func resumeLimit() {
        apply(.limit(maxPercent: targetLimit))
    }

    func setSystemMode() {
        apply(.system)
    }

    func toggleDischarge() {
        resumeLimit()
    }

    // MARK: - Heartbeat & State Sync

    private func beat() {
        let cmd: BatteryProtocol.Command = (mode == .system ? .status : .heartbeat)
        guard isInstalled else {
            if helper != .notInstalled { helper = .notInstalled }
            return
        }
        Task {
            let reply = await Task.detached { BatteryStore.send(cmd) }.value
            handle(reply, failure: nil)
        }
    }

    func refreshHelperState() {
        guard isInstalled else {
            helper = .notInstalled
            return
        }
        beat()
    }

    private func handle(_ reply: BatteryProtocol.Reply?, failure: String?) {
        guard let reply else {
            helper = isInstalled ? .notResponding : .notInstalled
            if let failure { errorMessage = failure }
            return
        }
        helper = .ready
        mode = reply.mode
        isHolding = reply.isHolding
        isAdapterBypassed = reply.isAdapterBypassed
        unsupported = reply.unsupported
        if !reply.ok, let failure {
            errorMessage = reply.error ?? failure
        }
    }

    // MARK: - Install / Uninstall

    func install() {
        let l10n = L10n.shared
        guard let helperURL = Bundle.main.url(forAuxiliaryExecutable: "pharos-battd") else {
            errorMessage = l10n.batteryHelperMissing
            return
        }
        let plistURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(BatteryHelperInstall.label).plist")
        do {
            try BatteryHelperInstall.plist(uid: getuid()).write(to: plistURL, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let script = BatteryHelperInstall.installScript(helperSource: helperURL.path, plistSource: plistURL.path)
        runAsAdmin(script, prompt: l10n.batteryInstallPrompt) { [weak self] error in
            try? FileManager.default.removeItem(at: plistURL)
            if let error {
                self?.errorMessage = error
                return
            }
            Task { @MainActor in
                for _ in 0..<20 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    self?.refreshHelperState()
                    if self?.helper == .ready {
                        self?.resumeLimit()
                        break
                    }
                }
            }
        }
    }

    func uninstall() {
        let l10n = L10n.shared
        runAsAdmin(BatteryHelperInstall.uninstallScript, prompt: l10n.batteryUninstallPrompt) { [weak self] error in
            if let error {
                self?.errorMessage = error
                return
            }
            self?.helper = .notInstalled
            self?.mode = .system
            self?.isHolding = false
            self?.isAdapterBypassed = false
        }
    }

    private func runAsAdmin(_ script: String, prompt: String, done: @escaping @MainActor (String?) -> Void) {
        busy = true
        let escaped = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with prompt \"\(prompt)\" with administrator privileges"
        Task.detached {
            var errorInfo: NSDictionary?
            let ok = NSAppleScript(source: source)?.executeAndReturnError(&errorInfo) != nil
            let code = errorInfo?[NSAppleScript.errorNumber] as? Int
            // -128 = user cancelled password prompt
            let message: String? = ok || code == -128 ? nil : (errorInfo?[NSAppleScript.errorMessage] as? String ?? "error \(code ?? 0)")
            await MainActor.run {
                self.busy = false
                done(message)
            }
        }
    }

    // MARK: - Socket Client

    nonisolated static func send(_ command: BatteryProtocol.Command) -> BatteryProtocol.Reply? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var tv = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = Array(BatteryProtocol.socketPath.utf8)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            for (i, b) in path.prefix(buf.count - 1).enumerated() { buf[i] = b }
        }

        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { return nil }

        let line = Array((BatteryProtocol.encode(command) + "\n").utf8)
        guard line.withUnsafeBytes({ write(fd, $0.baseAddress, $0.count) }) == line.count else { return nil }

        var buf = [UInt8](repeating: 0, count: 1024)
        let n = buf.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
        guard n > 0 else { return nil }

        return try? JSONDecoder().decode(BatteryProtocol.Reply.self, from: Data(buf.prefix(n)))
    }
}
