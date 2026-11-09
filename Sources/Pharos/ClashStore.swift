import AppKit
import Foundation
import PharosCore

/// Main-actor store managing Clash / Mihomo daemon integration and state.
@MainActor
final class ClashStore: ObservableObject {
    static let shared = ClashStore()

    @Published private(set) var snapshot: ClashStatusSnapshot = ClashStatusSnapshot()
    @Published private(set) var endpoint: ClashController.ControllerEndpoint?
    @Published private(set) var nodes: [MihomoProxyNode] = []
    @Published private(set) var isOperating: Bool = false
    @Published var errorMessage: String?
    @Published var notificationBanner: String?

    // MARK: - Manual Configuration State

    @Published var isManualMode: Bool {
        didSet { UserDefaults.standard.set(isManualMode, forKey: Keys.manualMode) }
    }
    @Published var manualEndpoint: String {
        didSet { UserDefaults.standard.set(manualEndpoint, forKey: Keys.manualEndpoint) }
    }
    @Published var manualSecret: String {
        didSet { UserDefaults.standard.set(manualSecret, forKey: Keys.manualSecret) }
    }
    @Published var manualMixedPort: Int {
        didSet { UserDefaults.standard.set(manualMixedPort, forKey: Keys.manualMixedPort) }
    }
    @Published var manualClientName: String {
        didSet { UserDefaults.standard.set(manualClientName, forKey: Keys.manualClientName) }
    }
    @Published var manualConfigPath: String {
        didSet { UserDefaults.standard.set(manualConfigPath, forKey: Keys.manualConfigPath) }
    }

    private enum Keys {
        static let manualMode = "clashManualMode"
        static let manualEndpoint = "clashManualEndpoint"
        static let manualSecret = "clashManualSecret"
        static let manualMixedPort = "clashManualMixedPort"
        static let manualClientName = "clashManualClientName"
        static let manualConfigPath = "clashManualConfigPath"
    }

    private var pollTimer: Timer?
    private var lastRefreshTime: Date = Date()
    private var lastNodesFetchTime: Date = Date.distantPast
    private var isRefreshing: Bool = false
    private var activeViewers: Int = 0

    private init() {
        let d = UserDefaults.standard
        isManualMode = d.bool(forKey: Keys.manualMode)
        manualEndpoint = d.string(forKey: Keys.manualEndpoint) ?? "http://127.0.0.1:9097"
        manualSecret = d.string(forKey: Keys.manualSecret) ?? ""
        let port = d.integer(forKey: Keys.manualMixedPort)
        manualMixedPort = port > 0 ? port : 7890
        manualClientName = d.string(forKey: Keys.manualClientName) ?? "Mihomo Core"
        manualConfigPath = d.string(forKey: Keys.manualConfigPath) ?? ""
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Polling Lifecycle

    func viewAppeared() {
        activeViewers += 1
        if activeViewers == 1 {
            startPolling()
        }
    }

    func viewDisappeared() {
        activeViewers = max(0, activeViewers - 1)
        if activeViewers == 0 {
            stopPolling()
        }
    }

    func startPolling() {
        guard pollTimer == nil else { return }
        // Initial probe
        Task { [weak self] in
            await self?.refresh()
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func stopPolling() {
        activeViewers = 0
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func applyMockSnapshot(_ s: ClashStatusSnapshot) {
        self.snapshot = s
    }

    // MARK: - State Refresh & Testing

    /// Tests connectivity to a given endpoint and secret token.
    func testConnection(endpoint: String, secret: String?) async -> (success: Bool, message: String) {
        let ep = ClashController.parseEndpoint(from: endpoint, secret: secret, clientKind: .custom)
        guard let validEp = ep else {
            return (false, "Invalid endpoint address")
        }

        return await Task.detached(priority: .utility) { () -> (Bool, String) in
            // 1. Connection-level check
            switch validEp.channel {
            case .unixSocket(let path):
                guard ClashController.canConnectUnixSocket(path: path) else {
                    return (false, "Cannot connect to unix socket")
                }
            case .http(let host, let port):
                guard ClashController.canConnectTCP(port: port, host: host) else {
                    return (false, "Cannot connect to \(host):\(port)")
                }
            }

            // 2. Protocol / Authentication check
            do {
                let (status, _) = try await ClashController.sendRequest(endpoint: validEp, method: "GET", uri: "/version")
                if status == 200 {
                    return (true, "OK (HTTP 200)")
                } else if status == 401 || status == 403 {
                    return (false, "Unauthorized: Invalid Secret")
                } else {
                    let (cfgStatus, _) = try await ClashController.sendRequest(endpoint: validEp, method: "GET", uri: "/configs")
                    if cfgStatus == 200 {
                        return (true, "OK (HTTP 200)")
                    } else {
                        return (false, "HTTP \(cfgStatus)")
                    }
                }
            } catch {
                return (false, error.localizedDescription)
            }
        }.value
    }

    func refresh() async {
        if DemoMode.isEnabled { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefreshTime)
        lastRefreshTime = now

        let existingEndpoint = endpoint
        let prevSnapshot = snapshot
        let manual = isManualMode
        let manEndpointStr = manualEndpoint
        let manSecretStr = manualSecret
        let manMixedPort = manualMixedPort
        let manCfgPath = manualConfigPath

        let (resolvedEndpoint, newSnapshot) = await Task.detached(priority: .utility) { () -> (ClashController.ControllerEndpoint?, ClashStatusSnapshot?) in
            var ep: ClashController.ControllerEndpoint?
            if manual {
                ep = ClashController.parseEndpoint(from: manEndpointStr, secret: manSecretStr, clientKind: .custom, configPath: manCfgPath)
            } else {
                ep = existingEndpoint
                if let current = ep {
                    let alive: Bool
                    switch current.channel {
                    case .unixSocket(let path):
                        alive = ClashController.canConnectUnixSocket(path: path)
                    case .http(let host, let port):
                        alive = ClashController.canConnectTCP(port: port, host: host)
                    }
                    if !alive {
                        ep = ClashController.detectActiveEndpoint()
                    }
                } else {
                    ep = ClashController.detectActiveEndpoint()
                }
            }

            guard let validEp = ep else {
                return (nil, nil)
            }

            var snap = await ClashController.fetchFullSnapshot(
                endpoint: validEp,
                previousSnapshot: prevSnapshot,
                elapsedSeconds: max(elapsed, 0.5)
            )

            if manual && snap.isRunning && manMixedPort > 0 && snap.mixedPort == 7890 && manMixedPort != 7890 {
                snap = ClashStatusSnapshot(
                    isRunning: snap.isRunning,
                    clientKind: snap.clientKind,
                    mode: snap.mode,
                    mixedPort: manMixedPort,
                    socksPort: snap.socksPort,
                    httpPort: snap.httpPort,
                    isTunEnabled: snap.isTunEnabled,
                    uploadBytesPerSec: snap.uploadBytesPerSec,
                    downloadBytesPerSec: snap.downloadBytesPerSec,
                    totalUploadBytes: snap.totalUploadBytes,
                    totalDownloadBytes: snap.totalDownloadBytes,
                    activeConnectionCount: snap.activeConnectionCount,
                    controllerEndpoint: snap.controllerEndpoint
                )
            }
            return (validEp, snap)
        }.value

        if self.endpoint != resolvedEndpoint {
            self.endpoint = resolvedEndpoint
        }

        guard let newSnapshot else {
            if snapshot.isRunning {
                snapshot = ClashStatusSnapshot(isRunning: false)
            }
            return
        }

        if self.snapshot != newSnapshot {
            self.snapshot = newSnapshot
        }

        if newSnapshot.isRunning {
            if nodes.isEmpty || lastNodesFetchTime.timeIntervalSinceNow < -15 {
                await refreshNodes()
            }
        } else if !nodes.isEmpty {
            nodes = []
        }
    }

    // MARK: - Proxy Node Management

    /// Refreshes available proxy nodes from the Mihomo/Clash core.
    /// If `triggerSpeedTest` is true, Mihomo executes a concurrent health-check to update live latencies.
    func refreshNodes(triggerSpeedTest: Bool = false) async {
        var ep = endpoint
        if ep == nil {
            ep = ClashController.detectActiveEndpoint()
            if let detected = ep {
                self.endpoint = detected
            }
        }
        guard let validEp = ep else { return }
        lastNodesFetchTime = Date()

        if triggerSpeedTest {
            do {
                _ = try await ClashController.testGroupDelay(endpoint: validEp, groupName: "GLOBAL")
            } catch {
                if let names = try? await ClashController.fetchProxyGroupNames(endpoint: validEp),
                   let first = names.first(where: { $0 != "GLOBAL" }) {
                    _ = try? await ClashController.testGroupDelay(endpoint: validEp, groupName: first)
                }
            }
        }

        do {
            let fetched = try await ClashController.fetchProxies(endpoint: validEp)
            self.nodes = fetched
        } catch {
            // Keep existing nodes if momentary error
        }
    }

    /// Hot switches a proxy group to the selected node in milliseconds without restarting the browser.
    @discardableResult
    func switchProxy(groupName: String, nodeName: String) async -> Bool {
        guard let ep = endpoint else { return false }
        isOperating = true
        defer { isOperating = false }

        do {
            let ok = try await ClashController.switchGroupProxy(
                groupName: groupName,
                nodeName: nodeName,
                endpoint: ep
            )
            if ok {
                notificationBanner = L10n.shared.proxyNodeSwitchedToast(nodeName, 0)
            }
            return ok
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Mounts the dedicated listener port and selector group for this instance in Mihomo config.
    func ensureInstanceListener(config: ChromeConfig) async throws {
        guard let ep = endpoint else { return }
        let cfgPath = ep.configPath ?? (manualConfigPath.isEmpty ? nil : manualConfigPath)
        try await ClashController.ensureListenerAndGroup(
            port: config.dedicatedProxyPort,
            groupName: config.dedicatedGroupName,
            availableNodeNames: nodes.map(\.name),
            configPath: cfgPath,
            endpoint: ep
        )
    }

    // MARK: - Controller Actions

    /// Switches routing mode (Rule / Direct / Global) in real time.
    func switchMode(_ mode: ClashRoutingMode) async {
        guard let ep = endpoint else { return }
        isOperating = true
        defer { isOperating = false }

        do {
            let ok = try await ClashController.switchMode(mode, endpoint: ep)
            if ok {
                // Optimistically update snapshot mode
                snapshot = ClashStatusSnapshot(
                    isRunning: true,
                    clientKind: snapshot.clientKind,
                    mode: mode,
                    mixedPort: snapshot.mixedPort,
                    socksPort: snapshot.socksPort,
                    httpPort: snapshot.httpPort,
                    isTunEnabled: snapshot.isTunEnabled,
                    uploadBytesPerSec: snapshot.uploadBytesPerSec,
                    downloadBytesPerSec: snapshot.downloadBytesPerSec,
                    totalUploadBytes: snapshot.totalUploadBytes,
                    totalDownloadBytes: snapshot.totalDownloadBytes,
                    activeConnectionCount: snapshot.activeConnectionCount,
                    controllerEndpoint: snapshot.controllerEndpoint
                )
                notificationBanner = L10n.shared.clashModeSwitchSuccess(mode.rawValue)
                // Also trigger close connections optionally or refresh
                await refresh()
            } else {
                errorMessage = L10n.shared.clashModeSwitchFailed
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Resets all open connections to immediately route traffic under the new mode.
    func closeAllConnections() async {
        guard let ep = endpoint else { return }
        isOperating = true
        defer { isOperating = false }

        do {
            let ok = try await ClashController.closeAllConnections(endpoint: ep)
            if ok {
                notificationBanner = L10n.shared.clashConnectionsClosed
                await refresh()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Copies terminal export command to clipboard.
    func copyTerminalProxySnippet() {
        let port: Int
        if isManualMode && manualMixedPort > 0 {
            port = manualMixedPort
        } else {
            port = snapshot.mixedPort > 0 ? snapshot.mixedPort : 7890
        }
        let (exportCmd, _) = ChromeInstances.terminalProxyCommands(mixedPort: port)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportCmd, forType: .string)
        notificationBanner = L10n.shared.terminalProxyCopied
    }

    /// Copies terminal unset command to clipboard.
    func copyTerminalUnsetSnippet() {
        let (_, unsetCmd) = ChromeInstances.terminalProxyCommands()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(unsetCmd, forType: .string)
        notificationBanner = L10n.shared.terminalUnsetCopied
    }
}
