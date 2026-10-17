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
            guard targetLimit != oldValue else { return }
            UserDefaults.standard.set(targetLimit, forKey: "batteryTargetLimit")
            if case .limit = mode {
                apply(.limit(maxPercent: targetLimit))
            }
        }
    }

    /// Whether the user wants Pharos to enforce the limit; restored after relaunch,
    /// because the daemon itself falls back to `.system` whenever Pharos goes away.
    private var limitEnabled: Bool = UserDefaults.standard.bool(forKey: "batteryLimitEnabled") {
        didSet { UserDefaults.standard.set(limitEnabled, forKey: "batteryLimitEnabled") }
    }
    private var restoredAfterLaunch = false

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
            // Best effort restore to system charging on app exit; single attempt so quitting never stalls.
            _ = BatteryStore.send(.setMode(.system), attempts: 1)
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
        limitEnabled = true
        apply(.limit(maxPercent: targetLimit))
    }

    /// Preset pills: one command to the daemon, not one from `targetLimit.didSet` plus another here.
    func selectLimit(_ percent: Int) {
        let alreadyLimited: Bool
        if case .limit = mode { alreadyLimited = true } else { alreadyLimited = false }
        limitEnabled = true
        // In limit mode `targetLimit.didSet` already sends the new limit.
        targetLimit = percent
        if !alreadyLimited { resumeLimit() }
    }

    /// "System Managed": daemon runs `releaseHardwareLocked()` and drops its sleep assertion.
    func setSystemMode() {
        limitEnabled = false
        apply(.system)
    }

    /// True only when the daemon confirms it is enforcing a limit — the UI never guesses.
    var isPharosManaging: Bool {
        guard helper == .ready, !unsupported else { return false }
        return mode != .system
    }

    var activeLimit: Int? {
        guard helper == .ready, case .limit(let p) = mode else { return nil }
        return p
    }

    var powerFlow: BatteryPowerFlow { BatteryPowerFlow.classify(reading) }

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
        } else if reply.ok, failure != nil, errorMessage == L10n.shared.batteryCommandFailed {
            errorMessage = nil
        }
        if !restoredAfterLaunch {
            restoredAfterLaunch = true
            if limitEnabled, reply.mode == .system, !reply.unsupported {
                apply(.limit(maxPercent: targetLimit))
            }
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
        // An update restarts the daemon in `.system`; put back whatever the user had.
        let restore: BatteryMode = (helper == .ready && mode != .system) ? mode : .limit(maxPercent: targetLimit)
        let restoreLimit = helper != .ready || limitEnabled || mode != .system
        let script = BatteryHelperInstall.installScript(helperSource: helperURL.path, plistSource: plistURL.path)
        runAsAdmin(script, prompt: l10n.batteryInstallPrompt) { [weak self] error in
            try? FileManager.default.removeItem(at: plistURL)
            if let error {
                self?.errorMessage = error
                return
            }
            Task { @MainActor [weak self] in
                // launchd bootout → bootstrap needs ~200–400 ms before the socket exists again.
                try? await Task.sleep(nanoseconds: 300_000_000)
                for _ in 0..<10 {
                    guard let self else { return }
                    let reply = await Task.detached { BatteryStore.send(.status) }.value
                    if reply != nil {
                        self.handle(reply, failure: nil)
                        self.errorMessage = nil
                        if restoreLimit {
                            if case .limit = restore { self.limitEnabled = true }
                            self.apply(restore)
                        }
                        self.refreshHelperState()
                        self.beat()
                        return
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                self?.refreshHelperState()
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

    /// Retries only when the socket is missing or refusing connections (daemon being restarted
    /// by launchd), never after a request was delivered, so a slow daemon is not hammered.
    nonisolated static func send(
        _ command: BatteryProtocol.Command,
        attempts: Int = 3,
        retryDelay: useconds_t = 150_000
    ) -> BatteryProtocol.Reply? {
        for attempt in 1...max(1, attempts) {
            switch sendOnce(command) {
            case .reply(let r): return r
            case .failed: return nil
            case .unreachable:
                if attempt < attempts { usleep(retryDelay) }
            }
        }
        return nil
    }

    private enum SendOutcome {
        case reply(BatteryProtocol.Reply)
        case unreachable
        case failed
    }

    private nonisolated static func sendOnce(_ command: BatteryProtocol.Command) -> SendOutcome {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return .failed }
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
        guard connected == 0 else { return .unreachable }

        let line = Array((BatteryProtocol.encode(command) + "\n").utf8)
        guard line.withUnsafeBytes({ write(fd, $0.baseAddress, $0.count) }) == line.count else { return .unreachable }

        var buf = [UInt8](repeating: 0, count: 1024)
        let n = buf.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
        // EOF before any reply: the old daemon was torn down mid-request.
        if n == 0 { return .unreachable }
        guard n > 0 else { return .failed }

        guard let reply = try? JSONDecoder().decode(BatteryProtocol.Reply.self, from: Data(buf.prefix(n))) else { return .failed }
        return .reply(reply)
    }
}
