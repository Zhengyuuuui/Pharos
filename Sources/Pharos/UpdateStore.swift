import AppKit
import CryptoKit
import Foundation
import PharosCore

/// Manages in-app update checks, streaming download, SHA-256 verification,
/// silent disk image staging, code signature check, and atomic relaunch.
@MainActor
final class UpdateStore: ObservableObject {
    static let shared = UpdateStore()

    // MARK: - Constants & Defaults

    public static let defaultWorkerBaseURL = "https://pharos-update.zysgm123.workers.dev"
    public static let defaultGitHubAPIURL = "https://api.github.com/repos/Zhengyuuuui/Pharos/releases/latest"

    public var workerBaseURL: String {
        if let custom = UserDefaults.standard.string(forKey: "pharos.updateWorkerURL")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return Self.defaultWorkerBaseURL
    }

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.2.0"
    }

    // MARK: - State

    public enum State: Equatable {
        case idle
        case checking
        case upToDate(lastChecked: Date)
        case available(ReleaseManifest)
        case downloading(manifest: ReleaseManifest, progress: Double, downloadedBytes: Int64, totalBytes: Int64)
        case verifying(ReleaseManifest)
        case installing(ReleaseManifest)
        case failed(String)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.checking, .checking):
                return true
            case let (.upToDate(d1), .upToDate(d2)):
                return abs(d1.timeIntervalSince(d2)) < 1.0
            case let (.available(m1), .available(m2)):
                return m1 == m2
            case let (.downloading(m1, p1, b1, t1), .downloading(m2, p2, b2, t2)):
                return m1 == m2 && abs(p1 - p2) < 0.001 && b1 == b2 && t1 == t2
            case let (.verifying(m1), .verifying(m2)):
                return m1 == m2
            case let (.installing(m1), .installing(m2)):
                return m1 == m2
            case let (.failed(e1), .failed(e2)):
                return e1 == e2
            default:
                return false
            }
        }
    }

    @Published private(set) var state: State = .idle

    @Published var autoCheckEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckEnabled, forKey: "pharos.autoCheckUpdates")
        }
    }

    public var availableManifest: ReleaseManifest? {
        switch state {
        case let .available(manifest),
             let .downloading(manifest, _, _, _),
             let .verifying(manifest),
             let .installing(manifest):
            return manifest
        default:
            return nil
        }
    }

    public var isChecking: Bool {
        if case .checking = state { return true }
        return false
    }

    public var isWorking: Bool {
        switch state {
        case .downloading, .verifying, .installing:
            return true
        default:
            return false
        }
    }

    public var lastCheckedDate: Date? {
        let t = UserDefaults.standard.double(forKey: "pharos.lastUpdateCheckTime")
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    private var backgroundTimer: Timer?
    private var downloadTask: Task<Void, Never>?

    private init() {
        if UserDefaults.standard.object(forKey: "pharos.autoCheckUpdates") == nil {
            autoCheckEnabled = true
        } else {
            autoCheckEnabled = UserDefaults.standard.bool(forKey: "pharos.autoCheckUpdates")
        }
    }

    deinit {
        backgroundTimer?.invalidate()
        downloadTask?.cancel()
    }

    // MARK: - Update Check (Dual-Channel)

    public func checkForUpdates(manual: Bool = false) {
        guard !isWorking && !isChecking else { return }
        state = .checking

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let manifest = try await self.fetchLatestManifest()
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "pharos.lastUpdateCheckTime")

                let skipped = manual ? nil : UserDefaults.standard.string(forKey: "pharos.skippedUpdateVersion")
                if UpdatePolicy.isUpdateAvailable(current: self.currentVersion, remote: manifest.version, skippedVersion: skipped) {
                    self.state = .available(manifest)
                    Notifier.shared.notifyUpdateAvailable(version: manifest.version)
                } else {
                    self.state = .upToDate(lastChecked: Date())
                }
            } catch {
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    public func skipVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: "pharos.skippedUpdateVersion")
        state = .idle
    }

    public func resetState() {
        if !isWorking {
            state = .idle
        }
    }

    private func fetchLatestManifest() async throws -> ReleaseManifest {
        // Channel 1: Cloudflare Worker Edge Gateway (8s timeout)
        let workerEndpoint = "\(workerBaseURL)/api/v1/latest"
        if let url = URL(string: workerEndpoint) {
            var req = URLRequest(url: url)
            req.timeoutInterval = 8.0
            req.setValue("Pharos/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    return try UpdatePolicy.parseWorkerManifest(data: data)
                }
            } catch {
                // Fall through to Channel 2 on Worker timeout/network error
            }
        }

        // Channel 2: GitHub Releases Official API Fallback (10s timeout)
        if let ghUrl = URL(string: Self.defaultGitHubAPIURL) {
            var ghReq = URLRequest(url: ghUrl)
            ghReq.timeoutInterval = 10.0
            ghReq.setValue("Pharos/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            ghReq.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: ghReq)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    return try UpdatePolicy.parseGitHubReleaseManifest(data: data)
                }
            } catch {
                // Fall through to Channel 3 on error or rate-limit
            }
        }

        // Channel 3: GitHub Public Releases Atom Feed (Rate-limit immune fallback)
        let atomEndpoint = "https://github.com/Zhengyuuuui/Pharos/releases.atom"
        if let atomUrl = URL(string: atomEndpoint) {
            var atomReq = URLRequest(url: atomUrl)
            atomReq.timeoutInterval = 10.0
            atomReq.setValue("Pharos/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: atomReq)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let xml = String(data: data, encoding: .utf8) {
                    return try UpdatePolicy.parseAtomFeed(xml: xml)
                }
            } catch {
                // Fall through
            }
        }

        throw NSError(domain: "UpdateStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Update server unavailable"])
    }

    // MARK: - Background Schedule

    public func startBackgroundSchedule() {
        // Silent check 6 seconds after launch if enabled and >12h since last check
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            guard let self = self, self.autoCheckEnabled else { return }
            let last = UserDefaults.standard.double(forKey: "pharos.lastUpdateCheckTime")
            let elapsed = Date().timeIntervalSince1970 - last
            if last == 0 || elapsed >= 12 * 3600 {
                self.checkForUpdates(manual: false)
            }
        }

        // 12-hour recurring timer
        backgroundTimer?.invalidate()
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 12 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.autoCheckEnabled else { return }
                self.checkForUpdates(manual: false)
            }
        }
    }

    // MARK: - Download, Verify, Install & Relaunch

    public func downloadAndInstall(_ manifest: ReleaseManifest) {
        guard !isWorking else { return }

        downloadTask?.cancel()
        downloadTask = Task { [weak self] in
            guard let self = self else { return }
            let workDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("pharos-update-\(UUID().uuidString)")

            do {
                try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
                let dmgFile = workDir.appendingPathComponent(manifest.dmgName)

                // 1. Download DMG with automatic fallback
                try await self.performDownload(manifest: manifest, destination: dmgFile)

                // 2. Verify SHA-256
                self.state = .verifying(manifest)
                try self.verifySHA256(file: dmgFile, expected: manifest.sha256)

                // 3. Mount, codesign verify, stage, and hand off
                self.state = .installing(manifest)
                try await self.stageAndRelaunch(workDir: workDir, dmgFile: dmgFile)
            } catch {
                try? FileManager.default.removeItem(at: workDir)
                if !Task.isCancelled {
                    self.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func performDownload(manifest: ReleaseManifest, destination: URL) async throws {
        // Try Cloudflare Worker stream first, fallback to GitHub DMG URL
        let urlsToTry: [URL] = [manifest.dmgUrl, manifest.githubDmgUrl].compactMap { $0 }
        var lastError: Error?

        for url in urlsToTry {
            if Task.isCancelled { return }
            do {
                try await downloadToFile(url: url, destination: destination, manifest: manifest)
                return
            } catch {
                lastError = error
                try? FileManager.default.removeItem(at: destination)
            }
        }

        throw lastError ?? NSError(domain: "UpdateStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Download failed from all sources"])
    }

    private func downloadToFile(url: URL, destination: URL, manifest: ReleaseManifest) async throws {
        var req = URLRequest(url: url)
        req.setValue("Pharos/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "UpdateStore", code: code, userInfo: [NSLocalizedDescriptionKey: "Download stream HTTP \(code)"])
        }

        let expectedLength = response.expectedContentLength > 0 ? response.expectedContentLength : (manifest.dmgSize ?? -1)
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        var downloaded: Int64 = 0
        var lastUpdateTime: Double = 0
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        for try await byte in bytes {
            if Task.isCancelled {
                throw CancellationError()
            }
            buffer.append(byte)
            downloaded += 1

            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)

                let now = CACurrentMediaTime()
                if now - lastUpdateTime >= 0.08 {
                    lastUpdateTime = now
                    let progress = expectedLength > 0 ? min(1.0, Double(downloaded) / Double(expectedLength)) : 0.0
                    self.state = .downloading(
                        manifest: manifest,
                        progress: progress,
                        downloadedBytes: downloaded,
                        totalBytes: expectedLength
                    )
                }
            }
        }

        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }

        let progress = expectedLength > 0 ? min(1.0, Double(downloaded) / Double(expectedLength)) : 1.0
        self.state = .downloading(
            manifest: manifest,
            progress: progress,
            downloadedBytes: downloaded,
            totalBytes: expectedLength
        )
    }

    private func verifySHA256(file: URL, expected: String?) throws {
        guard let expected = expected?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              expected.count == 64 else {
            // If no checksum was provided in notes, proceed
            return
        }

        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}

        let computed = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        if computed != expected {
            throw NSError(
                domain: "UpdateStore",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "\(L10n.shared.updateHashMismatch) (calc: \(computed.prefix(8))..., exp: \(expected.prefix(8))...)"]
            )
        }
    }

    private func stageAndRelaunch(workDir: URL, dmgFile: URL) async throws {
        let mntDir = workDir.appendingPathComponent("mnt")
        try FileManager.default.createDirectory(at: mntDir, withIntermediateDirectories: true)

        // 1. Silent attach
        let attachRes = runCommand("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-mountpoint", mntDir.path, dmgFile.path])
        guard attachRes.exitCode == 0 else {
            throw NSError(domain: "UpdateStore", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to mount DMG: \(attachRes.output)"])
        }

        defer {
            _ = runCommand("/usr/bin/hdiutil", ["detach", mntDir.path, "-force"])
        }

        // 2. Locate mounted Pharos.app
        let sourceApp = mntDir.appendingPathComponent("Pharos.app")
        guard FileManager.default.fileExists(atPath: sourceApp.path) else {
            throw NSError(domain: "UpdateStore", code: -4, userInfo: [NSLocalizedDescriptionKey: "Pharos.app not found inside DMG"])
        }

        // 3. Stage app to work directory
        let stagedApp = workDir.appendingPathComponent("Pharos.app")
        if FileManager.default.fileExists(atPath: stagedApp.path) {
            try? FileManager.default.removeItem(at: stagedApp)
        }
        let copyRes = runCommand("/usr/bin/ditto", [sourceApp.path, stagedApp.path])
        guard copyRes.exitCode == 0 else {
            throw NSError(domain: "UpdateStore", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to stage application: \(copyRes.output)"])
        }

        // 4. Detach DMG early before verification
        _ = runCommand("/usr/bin/hdiutil", ["detach", mntDir.path, "-force"])

        // 5. Verify codesign
        let signRes = runCommand("/usr/bin/codesign", ["--verify", "--deep", "--strict", stagedApp.path])
        guard signRes.exitCode == 0 else {
            throw NSError(domain: "UpdateStore", code: -6, userInfo: [NSLocalizedDescriptionKey: "Code signature verification failed: \(signRes.output)"])
        }

        // 6. Remove quarantine
        _ = runCommand("/usr/bin/xattr", ["-dr", "com.apple.quarantine", stagedApp.path])

        // 7. Determine installation target
        var targetAppPath = "/Applications/Pharos.app"
        let currentBundlePath = Bundle.main.bundleURL.path
        if currentBundlePath.hasSuffix(".app") &&
           (currentBundlePath.hasPrefix("/Applications/") || currentBundlePath.hasPrefix(NSHomeDirectory())) {
            targetAppPath = currentBundlePath
        }

        let currentPid = ProcessInfo.processInfo.processIdentifier
        let parentDir = (targetAppPath as NSString).deletingLastPathComponent
        let isWritable = FileManager.default.isWritableFile(atPath: parentDir)

        if isWritable {
            // Launch independent handoff subshell
            let script = "while kill -0 \"$1\" 2>/dev/null; do sleep 0.15; done; rm -rf \"$3\" && mv \"$2\" \"$3\" && open \"$3\"; rm -rf \"$4\""
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", script, "sh", "\(currentPid)", stagedApp.path, targetAppPath, workDir.path]
            try process.run()
        } else {
            // Admin authorization prompt if /Applications is not writable
            let adminScript = "while kill -0 \(currentPid) 2>/dev/null; do sleep 0.15; done; rm -rf \\\"\(targetAppPath)\\\" && mv \\\"\(stagedApp.path)\\\" \\\"\(targetAppPath)\\\" && open \\\"\(targetAppPath)\\\"; rm -rf \\\"\(workDir.path)\\\""
            let appleScriptText = "do shell script \"\(adminScript)\" with administrator privileges"
            if let appleScript = NSAppleScript(source: appleScriptText) {
                var err: NSDictionary?
                appleScript.executeAndReturnError(&err)
                if let err = err {
                    throw NSError(domain: "UpdateStore", code: -7, userInfo: [NSLocalizedDescriptionKey: "\(err)"])
                }
            }
        }

        // 8. Gracefully terminate current instance
        NSApp.terminate(nil)
    }

    @discardableResult
    private func runCommand(_ executable: String, _ arguments: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, out)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}
