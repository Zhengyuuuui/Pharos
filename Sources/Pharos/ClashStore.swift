import AppKit
import Foundation
import PharosCore

/// Main-actor store managing Clash / Mihomo daemon integration and state.
@MainActor
final class ClashStore: ObservableObject {
    static let shared = ClashStore()

    @Published private(set) var snapshot: ClashStatusSnapshot = ClashStatusSnapshot()
    @Published private(set) var endpoint: ClashController.ControllerEndpoint?
    @Published private(set) var isOperating: Bool = false
    @Published var errorMessage: String?
    @Published var notificationBanner: String?

    private var pollTimer: Timer?
    private var lastRefreshTime: Date = Date()
    private var isRefreshing: Bool = false

    private init() {
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Polling Lifecycle

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
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - State Refresh

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefreshTime)
        lastRefreshTime = now

        let existingEndpoint = endpoint
        let prevSnapshot = snapshot

        let (resolvedEndpoint, newSnapshot) = await Task.detached(priority: .utility) { () -> (ClashController.ControllerEndpoint?, ClashStatusSnapshot?) in
            var ep = existingEndpoint
            if let current = ep {
                let alive: Bool
                switch current.channel {
                case .unixSocket(let path):
                    alive = ClashController.canConnectUnixSocket(path: path)
                case .http(_, let port):
                    alive = ClashController.canConnectTCP(port: port)
                }
                if !alive {
                    ep = ClashController.detectActiveEndpoint()
                }
            } else {
                ep = ClashController.detectActiveEndpoint()
            }

            guard let validEp = ep else {
                return (nil, nil)
            }
            let snap = await ClashController.fetchFullSnapshot(
                endpoint: validEp,
                previousSnapshot: prevSnapshot,
                elapsedSeconds: max(elapsed, 0.5)
            )
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
        let port = snapshot.mixedPort > 0 ? snapshot.mixedPort : 7890
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
