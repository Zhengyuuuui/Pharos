import Foundation

/// Chromium-based browsers that take the same command-line flags.
public enum ChromiumBrowser: String, Codable, CaseIterable, Sendable {
    case chrome, chromeBeta, chromeCanary, chromium, edge, brave

    /// App bundle name and executable name inside Contents/MacOS.
    public var appName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .chromeBeta: return "Google Chrome Beta"
        case .chromeCanary: return "Google Chrome Canary"
        case .chromium: return "Chromium"
        case .edge: return "Microsoft Edge"
        case .brave: return "Brave Browser"
        }
    }

    public var appPath: String { "/Applications/\(appName).app" }

    /// Where the browser keeps its profile when no --user-data-dir is given.
    public var defaultUserDataDir: String {
        let base = NSHomeDirectory() + "/Library/Application Support/"
        switch self {
        case .chrome: return base + "Google/Chrome"
        case .chromeBeta: return base + "Google/Chrome Beta"
        case .chromeCanary: return base + "Google/Chrome Canary"
        case .chromium: return base + "Chromium"
        case .edge: return base + "Microsoft Edge"
        case .brave: return base + "BraveSoftware/Brave-Browser"
        }
    }

    /// The browser whose main executable this is. Also matches the code-sign
    /// clone a browser runs from after an update
    /// (`/var/folders/…/code_sign_clone/…/Google Chrome.app.bundle/…`).
    public static func identify(path: String?, argv0: String? = nil) -> ChromiumBrowser? {
        for p in [path, argv0] {
            guard let p else { continue }
            for b in allCases {
                let exe = "/Contents/MacOS/\(b.appName)"
                if p.hasSuffix("/\(b.appName).app" + exe) || p.hasSuffix("/\(b.appName).app.bundle" + exe) { return b }
            }
        }
        return nil
    }
}

/// The settings that make one browser instance distinct. Shared by saved
/// presets and by what's parsed from a running instance's command line.
public struct ChromeConfig: Codable, Hashable, Sendable {
    public var browser: ChromiumBrowser
    /// nil = the browser's default profile directory.
    public var userDataDir: String?
    public var debugPort: UInt16?
    public var proxyServer: String?
    public var startURL: String?
    /// Any other flags, verbatim (e.g. --no-first-run).
    public var extraFlags: [String]

    public init(browser: ChromiumBrowser = .chrome, userDataDir: String? = nil, debugPort: UInt16? = nil,
                proxyServer: String? = nil, startURL: String? = nil, extraFlags: [String] = []) {
        self.browser = browser
        self.userDataDir = userDataDir.map(WorkspaceMatcher.normalize)
        self.debugPort = debugPort
        self.proxyServer = proxyServer
        self.startURL = startURL
        self.extraFlags = extraFlags
    }

    private enum CodingKeys: String, CodingKey { case browser, userDataDir, debugPort, proxyServer, startURL, extraFlags }

    /// Presets saved before multi-browser support have no `browser`: they were Chrome.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        browser = try c.decodeIfPresent(ChromiumBrowser.self, forKey: .browser) ?? .chrome
        userDataDir = try c.decodeIfPresent(String.self, forKey: .userDataDir)
        debugPort = try c.decodeIfPresent(UInt16.self, forKey: .debugPort)
        proxyServer = try c.decodeIfPresent(String.self, forKey: .proxyServer)
        startURL = try c.decodeIfPresent(String.self, forKey: .startURL)
        extraFlags = try c.decodeIfPresent([String].self, forKey: .extraFlags) ?? []
    }

    /// Identity of an instance: a Chromium browser allows exactly one browser
    /// process per user-data-dir, so the folder *is* the instance.
    public var profileKey: String { userDataDir ?? browser.defaultUserDataDir }
    public var isDefaultProfile: Bool { userDataDir == nil || userDataDir == browser.defaultUserDataDir }
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

    /// Browser + profile folder: each browser allows one process per folder.
    public var id: String { config.browser.rawValue + ":" + config.profileKey }
    public var allPIDs: [Int32] { [pid] + helperPIDs }
}

public enum ChromeInstances {
    public static let appPath = ChromiumBrowser.chrome.appPath
    public static let defaultUserDataDir = ChromiumBrowser.chrome.defaultUserDataDir

    /// Flags Chrome adds or that only describe one launch, not the instance.
    static let ignoredFlags: Set<String> = ["--new-window", "--flag-switches-begin", "--flag-switches-end"]

    public static func isChromeExecutable(path: String?, argv0: String?) -> Bool {
        ChromiumBrowser.identify(path: path, argv0: argv0) != nil
    }

    public static func isBrowserProcess(_ p: ProcessSnapshot) -> Bool {
        isChromeExecutable(path: p.executablePath, argv0: p.arguments.first)
            && !p.arguments.isEmpty && !p.arguments.contains { $0.hasPrefix("--type=") }
    }

    /// Browsers installed in /Applications, in `ChromiumBrowser` order.
    public static func installedBrowsers() -> [ChromiumBrowser] {
        ChromiumBrowser.allCases.filter { FileManager.default.fileExists(atPath: $0.appPath) }
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
                config: parse(browser.arguments,
                              browser: ChromiumBrowser.identify(path: browser.executablePath, argv0: browser.arguments.first) ?? .chrome),
                memoryBytes: (helpers + [browser]).reduce(0) { $0 + $1.memoryBytes },
                processCount: helpers.count + 1,
                helperPIDs: helpers.map(\.pid)
            )
        }
        .sorted { ($0.config.browser.rawValue, $0.config.debugPort ?? 0, $0.pid)
                < ($1.config.browser.rawValue, $1.config.debugPort ?? 0, $1.pid) }
    }

    /// Reads the instance-defining flags from a browser command line. Flags
    /// that are derived from others (`--remote-allow-origins` for the debug
    /// port) are dropped; `launchArguments` regenerates them.
    public static func parse(_ arguments: [String], browser: ChromiumBrowser = .chrome) -> ChromeConfig {
        var config = ChromeConfig(browser: browser)
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

    /// Arguments after `--args` for `open -na "<browser app>"`.
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
        let head = "open -na " + ShellQuote.quote(c.browser.appName)
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
