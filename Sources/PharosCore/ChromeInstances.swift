import Foundation

/// The settings that make one Chrome instance distinct. Shared by saved
/// presets and by what's parsed from a running instance's command line.
public struct ChromeConfig: Codable, Hashable, Sendable {
    /// nil = the default profile directory (~/Library/Application Support/Google/Chrome).
    public var userDataDir: String?
    public var debugPort: UInt16?
    public var proxyServer: String?
    public var startURL: String?
    /// Any other flags, verbatim (e.g. --no-first-run).
    public var extraFlags: [String]

    public init(userDataDir: String? = nil, debugPort: UInt16? = nil, proxyServer: String? = nil,
                startURL: String? = nil, extraFlags: [String] = []) {
        self.userDataDir = userDataDir.map(WorkspaceMatcher.normalize)
        self.debugPort = debugPort
        self.proxyServer = proxyServer
        self.startURL = startURL
        self.extraFlags = extraFlags
    }

    /// Identity of a Chrome instance: Chrome allows exactly one browser
    /// process per user-data-dir, so the folder *is* the instance.
    public var profileKey: String { userDataDir ?? ChromeInstances.defaultUserDataDir }
    public var isDefaultProfile: Bool { userDataDir == nil || userDataDir == ChromeInstances.defaultUserDataDir }
}

public struct ChromePreset: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var config: ChromeConfig

    public init(id: String = UUID().uuidString, name: String, config: ChromeConfig) {
        self.id = id
        self.name = name
        self.config = config
    }
}

/// One running Chrome browser process (helpers rolled up).
public struct ChromeInstance: Identifiable, Hashable, Sendable {
    public let pid: Int32
    public let config: ChromeConfig
    /// Browser process + all renderer/GPU/utility helpers.
    public let memoryBytes: UInt64
    public let processCount: Int
    public let helperPIDs: [Int32]

    public var id: String { config.profileKey }
    public var allPIDs: [Int32] { [pid] + helperPIDs }
}

public enum ChromeInstances {
    public static let appPath = "/Applications/Google Chrome.app"
    static let executableSuffix = "/Google Chrome.app/Contents/MacOS/Google Chrome"
    public static let defaultUserDataDir = NSHomeDirectory() + "/Library/Application Support/Google/Chrome"

    /// Flags Chrome adds or that only describe one launch, not the instance.
    static let ignoredFlags: Set<String> = ["--new-window", "--flag-switches-begin", "--flag-switches-end"]

    /// After an update, a running Chrome may execute from a code-sign clone
    /// (`/var/folders/…/X/com.google.Chrome.code_sign_clone/…/Google Chrome.app.bundle/…`),
    /// so argv[0] is checked as well as the executable path.
    public static func isChromeExecutable(path: String?, argv0: String?) -> Bool {
        let cloneSuffix = "/Google Chrome.app.bundle/Contents/MacOS/Google Chrome"
        return [path, argv0].contains { p in
            guard let p else { return false }
            return p.hasSuffix(executableSuffix) || p.hasSuffix(cloneSuffix)
        }
    }

    public static func isBrowserProcess(_ p: ProcessSnapshot) -> Bool {
        isChromeExecutable(path: p.executablePath, argv0: p.arguments.first)
            && !p.arguments.isEmpty && !p.arguments.contains { $0.hasPrefix("--type=") }
    }

    /// Browser processes with their helper trees.
    public static func find(in all: [ProcessSnapshot]) -> [ChromeInstance] {
        var children: [Int32: [ProcessSnapshot]] = [:]
        for p in all where p.pid != p.ppid { children[p.ppid, default: []].append(p) }
        return all.filter(isBrowserProcess).map { browser in
            var helpers: [ProcessSnapshot] = []
            var queue = [browser.pid]
            while let pid = queue.popLast() {
                for child in children[pid] ?? [] {
                    helpers.append(child)
                    queue.append(child.pid)
                }
            }
            return ChromeInstance(
                pid: browser.pid,
                config: parse(browser.arguments),
                memoryBytes: (helpers + [browser]).reduce(0) { $0 + $1.memoryBytes },
                processCount: helpers.count + 1,
                helperPIDs: helpers.map(\.pid)
            )
        }
        .sorted { ($0.config.debugPort ?? 0, $0.pid) < ($1.config.debugPort ?? 0, $1.pid) }
    }

    /// Reads the instance-defining flags from a browser command line. Flags
    /// that are derived from others (`--remote-allow-origins` for the debug
    /// port) are dropped; `launchArguments` regenerates them.
    public static func parse(_ arguments: [String]) -> ChromeConfig {
        var config = ChromeConfig()
        var extras: [String] = []
        var positional: [String] = []
        for arg in arguments.dropFirst() {
            if let v = value(arg, "--user-data-dir") {
                config.userDataDir = WorkspaceMatcher.normalize(v)
            } else if let v = value(arg, "--remote-debugging-port") {
                config.debugPort = UInt16(v)
            } else if let v = value(arg, "--proxy-server") {
                config.proxyServer = v
            } else if value(arg, "--remote-allow-origins") != nil || ignoredFlags.contains(arg)
                        || arg.hasPrefix("--enable-features=") || arg.hasPrefix("--disable-features=") {
                continue
            } else if arg.hasPrefix("-") {
                extras.append(arg)
            } else {
                positional.append(arg)
            }
        }
        config.startURL = positional.first { $0 != "about:blank" }
        config.extraFlags = extras
        return config
    }

    /// Arguments after `--args` for `open -na "Google Chrome"`.
    public static func launchArguments(_ c: ChromeConfig) -> [String] {
        var args: [String] = []
        if let dir = c.userDataDir, !c.isDefaultProfile { args.append("--user-data-dir=\(dir)") }
        if let port = c.debugPort {
            args.append("--remote-debugging-port=\(port)")
            args.append("--remote-allow-origins=http://localhost:\(port),http://127.0.0.1:\(port)")
        }
        if let proxy = c.proxyServer, !proxy.isEmpty { args.append("--proxy-server=\(proxy)") }
        args.append(contentsOf: c.extraFlags.filter { $0.hasPrefix("-") })
        if let url = c.startURL, !url.isEmpty { args.append(url) }
        return args
    }

    /// The same launch as a terminal command, for showing and copying. Pharos
    /// itself never runs this through a shell; it passes `launchArguments` directly.
    public static func shellCommand(_ c: ChromeConfig) -> String {
        let args = launchArguments(c)
        let head = "open -na " + ShellQuote.quote("Google Chrome")
        return args.isEmpty ? head : head + " --args " + args.map(ShellQuote.quote).joined(separator: " ")
    }

    /// Problems that would make a launch fail or hit the wrong instance.
    public enum LaunchProblem: Equatable, Sendable {
        case alreadyRunning
        case portInUse(UInt16)
        case defaultProfileWithDebugPort
    }

    public static func problems(for c: ChromeConfig, running: [ChromeInstance],
                                listeningPorts: Set<UInt16>) -> [LaunchProblem] {
        var out: [LaunchProblem] = []
        if running.contains(where: { $0.config.profileKey == c.profileKey }) { out.append(.alreadyRunning) }
        if let port = c.debugPort, listeningPorts.contains(port),
           !running.contains(where: { $0.config.debugPort == port && $0.config.profileKey == c.profileKey }) {
            out.append(.portInUse(port))
        }
        // Chrome 136+ ignores --remote-debugging-port on the default profile.
        if c.debugPort != nil, c.isDefaultProfile { out.append(.defaultProfileWithDebugPort) }
        return out
    }

    /// Profile names inside a user-data-dir (from its "Local State").
    public static func profileNames(in userDataDir: String) -> [String] {
        guard let data = FileManager.default.contents(atPath: userDataDir + "/Local State"),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let cache = (json["profile"] as? [String: Any])?["info_cache"] as? [String: Any] else { return [] }
        return cache.keys.sorted().compactMap { key in
            guard let info = cache[key] as? [String: Any] else { return nil }
            let name = info["name"] as? String ?? key
            let user = info["user_name"] as? String ?? ""
            return user.isEmpty ? name : "\(name) (\(user))"
        }
    }

    /// Disk usage of a folder (allocated blocks, no symlink following).
    public static func folderSize(_ path: String) -> UInt64 {
        var total: UInt64 = 0
        func walk(_ dir: String) {
            guard let kids = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
            for k in kids {
                let p = dir + "/" + k
                var st = stat()
                guard lstat(p, &st) == 0 else { continue }
                if (st.st_mode & S_IFMT) == S_IFDIR { walk(p) } else { total += UInt64(st.st_blocks) * 512 }
            }
        }
        walk(path)
        return total
    }

    private static func value(_ arg: String, _ flag: String) -> String? {
        guard arg.hasPrefix(flag + "=") else { return nil }
        var v = String(arg.dropFirst(flag.count + 1))
        if v.count >= 2, let f = v.first, f == v.last, f == "\"" || f == "'" { v = String(v.dropFirst().dropLast()) }
        return v
    }
}
