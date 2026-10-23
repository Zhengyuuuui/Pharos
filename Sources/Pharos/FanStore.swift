import AppKit
import Darwin
import PharosCore

/// Talks to the optional `pharos-fand` root helper. Nothing here runs as root:
/// install/uninstall go through macOS's own administrator password prompt, and
/// fan commands are single lines over the helper's 0600 Unix socket.
@MainActor
final class FanStore: ObservableObject {
    static let shared = FanStore()

    enum HelperState: Equatable {
        case notInstalled
        /// Installed but not answering (just installed, crashed, or launchd hasn't started it).
        case notResponding
        case ready
    }

    @Published private(set) var helper: HelperState = .notInstalled
    @Published private(set) var request: FanRequest = .system
    @Published private(set) var overheating = false
    @Published private(set) var unsupported = false
    @Published private(set) var busy = false
    @Published var errorMessage: String?
    /// RPM the slider is set to (kept when switching modes).
    @Published var fixedRPM: Int = UserDefaults.standard.object(forKey: "fanFixedRPM") as? Int ?? 3500 {
        didSet { UserDefaults.standard.set(fixedRPM, forKey: "fanFixedRPM") }
    }

    private var heartbeat: Timer?
    private var hasViewers: Bool = false

    func updateVisibility(hasViewers: Bool) {
        guard self.hasViewers != hasViewers else { return }
        self.hasViewers = hasViewers
        if hasViewers {
            refreshState()
        }
        scheduleTimer()
    }

    func viewAppeared() { updateVisibility(hasViewers: true) }
    func viewDisappeared() { updateVisibility(hasViewers: false) }

    private func scheduleTimer() {
        heartbeat?.invalidate()

        let interval: TimeInterval
        if request != .system {
            // Actively controlling fans: must maintain 5s heartbeat to prevent daemon 15s timeout
            interval = 5
        } else {
            // System mode: downclock to 30s when no windows are open, 5s when visible
            interval = hasViewers ? 5 : 30
        }

        heartbeat = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.beat() }
        }
    }

    private init() {
        refreshState()
        scheduleTimer()
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil,
                                               queue: .main) { _ in
            // Best effort; the heartbeat timeout covers crashes and force quits.
            _ = FanStore.send(.set(.system))
        }
    }

    deinit { heartbeat?.invalidate() }

    var isInstalled: Bool { FileManager.default.fileExists(atPath: FanHelperInstall.plistPath) }

    // MARK: - Control

    func apply(_ r: FanRequest) {
        guard helper == .ready else { return }
        busy = true
        scheduleTimer()
        Task {
            let reply = await Task.detached { FanStore.send(.set(r)) }.value
            busy = false
            handle(reply, failure: L10n.shared.fanCommandFailed)
            scheduleTimer()
        }
    }

    private func beat() {
        // Only ping while something is held; idle Pharos shouldn't touch the helper.
        let cmd: FanProtocol.Command = request == .system ? .status : .heartbeat
        guard isInstalled else { if helper != .notInstalled { helper = .notInstalled }; return }
        Task {
            let reply = await Task.detached { FanStore.send(cmd) }.value
            handle(reply, failure: nil)
        }
    }

    func refreshState() {
        guard isInstalled else { helper = .notInstalled; return }
        beat()
    }

    private func handle(_ reply: FanProtocol.Reply?, failure: String?) {
        guard let reply else {
            helper = isInstalled ? .notResponding : .notInstalled
            if let failure { errorMessage = failure }
            return
        }
        helper = .ready
        let oldRequest = request
        request = reply.request
        overheating = reply.overheating
        unsupported = reply.unsupported
        if oldRequest != request {
            scheduleTimer()
        }
        if !reply.ok, let failure { errorMessage = reply.error ?? failure }
    }

    // MARK: - Install / uninstall

    func install() {
        let l10n = L10n.shared
        guard let helperURL = Bundle.main.url(forAuxiliaryExecutable: "pharos-fand") else {
            errorMessage = l10n.fanHelperMissing
            return
        }
        let plistURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(FanHelperInstall.label).plist")
        do {
            try FanHelperInstall.plist(uid: getuid()).write(to: plistURL, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = l10n.fanInstallFailed(error.localizedDescription)
            return
        }
        runAsAdmin(FanHelperInstall.installScript(helperSource: helperURL.path, plistSource: plistURL.path),
                   prompt: l10n.fanInstallPrompt) { [weak self] error in
            try? FileManager.default.removeItem(at: plistURL)
            if let error { self?.errorMessage = l10n.fanInstallFailed(error) }
            self?.waitForHelper()
        }
    }

    func uninstall() {
        let l10n = L10n.shared
        runAsAdmin(FanHelperInstall.uninstallScript, prompt: l10n.fanUninstallPrompt) { [weak self] error in
            if let error { self?.errorMessage = l10n.fanInstallFailed(error) }
            self?.request = .system
            self?.refreshState()
        }
    }

    private func waitForHelper() {
        Task {
            for _ in 0..<10 {
                refreshState()
                if helper == .ready { return }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    /// macOS shows its own administrator password dialog; Pharos never sees the password.
    private func runAsAdmin(_ script: String, prompt: String, done: @escaping @MainActor (String?) -> Void) {
        busy = true
        let escaped = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with prompt \"\(prompt)\" with administrator privileges"
        Task.detached {
            var errorInfo: NSDictionary?
            let ok = NSAppleScript(source: source)?.executeAndReturnError(&errorInfo) != nil
            let code = errorInfo?[NSAppleScript.errorNumber] as? Int
            // -128 = user cancelled the password prompt; not an error worth showing.
            let message: String? = ok || code == -128 ? nil : (errorInfo?[NSAppleScript.errorMessage] as? String ?? "error \(code ?? 0)")
            await MainActor.run {
                self.busy = false
                done(message)
            }
        }
    }

    // MARK: - Socket

    /// One request, one reply. Blocking; call off the main thread.
    nonisolated static func send(_ command: FanProtocol.Command) -> FanProtocol.Reply? {
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
        let path = Array(FanProtocol.socketPath.utf8)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            for (i, b) in path.prefix(buf.count - 1).enumerated() { buf[i] = b }
        }
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else { return nil }
        let line = Array((FanProtocol.encode(command) + "\n").utf8)
        guard line.withUnsafeBytes({ write(fd, $0.baseAddress, $0.count) }) == line.count else { return nil }
        var buf = [UInt8](repeating: 0, count: 1024)
        let n = buf.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
        guard n > 0 else { return nil }
        return try? JSONDecoder().decode(FanProtocol.Reply.self, from: Data(buf.prefix(n)))
    }
}
