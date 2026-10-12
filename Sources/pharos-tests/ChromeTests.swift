import Foundation
import PharosCore

private let chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
private let helper = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/1/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"

func testChromeParse() {
    // Real command line from this machine (9367 debug profile behind a proxy).
    let c = ChromeInstances.parse([
        chrome, "--user-data-dir=/Users/me/chrome9367-clean", "--remote-debugging-port=9367",
        "--remote-allow-origins=http://localhost:9367,http://127.0.0.1:9367",
        "--proxy-server=http://127.0.0.1:7890", "--no-first-run", "--no-default-browser-check",
        "--enable-features=Foo,Bar", "https://account.minimax.io/unified-login",
    ])
    expectEq(c.userDataDir, "/Users/me/chrome9367-clean", "user-data-dir")
    expectEq(c.debugPort, 9367, "debug port")
    expectEq(c.proxyServer, "http://127.0.0.1:7890", "proxy")
    expectEq(c.startURL, "https://account.minimax.io/unified-login", "start URL")
    expectEq(c.extraFlags, ["--no-first-run", "--no-default-browser-check"],
             "extras kept; derived allow-origins and feature lists dropped")

    let quoted = ChromeInstances.parse([chrome, "--user-data-dir=\"/Users/me/my profile/\""])
    expectEq(quoted.userDataDir, "/Users/me/my profile", "quoted + trailing slash normalized")

    let normal = ChromeInstances.parse([chrome, "--new-window", "about:blank"])
    expect(normal.isDefaultProfile, "no user-data-dir → default profile")
    expectEq(normal.startURL, nil, "about:blank isn't a start URL")
    expectEq(normal.extraFlags, [], "--new-window is per-launch noise")
}

func testChromeLaunchArgsRoundTrip() {
    let c = ChromeConfig(userDataDir: "/Users/me/chrome-dig", debugPort: 9223,
                         proxyServer: "http://127.0.0.1:7890", startURL: "https://grok.com",
                         extraFlags: ["--no-first-run"])
    let args = ChromeInstances.launchArguments(c)
    expectEq(args, [
        "--user-data-dir=/Users/me/chrome-dig", "--remote-debugging-port=9223",
        "--remote-allow-origins=http://localhost:9223,http://127.0.0.1:9223",
        "--proxy-server=http://127.0.0.1:7890", "--no-first-run", "https://grok.com",
    ], "launch args, allow-origins regenerated for the port")
    expectEq(ChromeInstances.parse([chrome] + args), c, "parse(launchArguments(c)) == c")

    let plain = ChromeConfig()
    expectEq(ChromeInstances.launchArguments(plain), [], "default profile → no flags")
    let defaultDir = ChromeConfig(userDataDir: ChromeInstances.defaultUserDataDir)
    expectEq(ChromeInstances.launchArguments(defaultDir), [], "explicit default dir isn't passed")
}

func testChromeShellCommand() {
    let c = ChromeConfig(userDataDir: "/Users/me/chrome 9367", debugPort: 9367,
                         proxyServer: "http://127.0.0.1:7890", startURL: "https://x.com/?a=1&b=2",
                         extraFlags: ["--no-first-run"])
    expectEq(ChromeInstances.shellCommand(c),
             "open -na 'Google Chrome' --args '--user-data-dir=/Users/me/chrome 9367' --remote-debugging-port=9367 "
                + "--remote-allow-origins=http://localhost:9367,http://127.0.0.1:9367 "
                + "--proxy-server=http://127.0.0.1:7890 --no-first-run 'https://x.com/?a=1&b=2'",
             "shell command quotes spaces and & so it can be pasted into a terminal")
    expectEq(ChromeInstances.shellCommand(ChromeConfig()), "open -na 'Google Chrome'", "default profile → no --args")
}

func testChromeFindInstances() {
    let all = [
        ProcessSnapshot(pid: 100, ppid: 1, name: "Google Chrome", executablePath: chrome,
                        arguments: [chrome, "--new-window"], memoryBytes: 500),
        ProcessSnapshot(pid: 101, ppid: 100, name: "Google Chrome Helper (Renderer)", executablePath: helper,
                        arguments: [helper, "--type=renderer"], memoryBytes: 200),
        ProcessSnapshot(pid: 102, ppid: 101, name: "x", executablePath: helper, memoryBytes: 50),
        ProcessSnapshot(pid: 200, ppid: 1, name: "Google Chrome", executablePath: chrome,
                        arguments: [chrome, "--user-data-dir=/Users/me/chrome9366-clean",
                                    "--remote-debugging-port=9366"],
                        memoryBytes: 300, ports: [ListeningPort(port: 9366, loopbackOnly: true)]),
        ProcessSnapshot(pid: 201, ppid: 200, name: "h", executablePath: helper, memoryBytes: 30),
        // A renderer launched with the main executable path but --type= is a helper, not a browser.
        ProcessSnapshot(pid: 300, ppid: 200, name: "Google Chrome", executablePath: chrome,
                        arguments: [chrome, "--type=utility"], memoryBytes: 10),
        ProcessSnapshot(pid: 400, ppid: 1, name: "node", executablePath: "/opt/homebrew/bin/node", memoryBytes: 99),
        // Seen on this machine after a Chrome update: runs from a code-sign clone.
        ProcessSnapshot(pid: 500, ppid: 1, name: "Google Chrome",
                        executablePath: "/private/var/folders/f0/x/X/com.google.Chrome.code_sign_clone/code_sign_clone.HLHQXC/Google Chrome.app.bundle/Contents/MacOS/Google Chrome",
                        arguments: [chrome, "--user-data-dir=/Users/me/chrome9366-b", "--remote-debugging-port=9400"],
                        memoryBytes: 70),
    ]
    let found = ChromeInstances.find(in: all)
    expectEq(found.map(\.pid), [100, 200, 500], "browsers incl. code-sign clone, sorted by debug port")
    expectEq(found[0].memoryBytes, 750, "default instance memory includes nested helpers")
    expectEq(found[0].processCount, 3, "browser + 2 helpers")
    expectEq(found[1].memoryBytes, 340, "debug instance memory")
    expectEq(Set(found[1].allPIDs), Set<Int32>([200, 201, 300]), "helper tree PIDs")
    expectEq(found[1].id, "/Users/me/chrome9366-clean", "instance identity = profile folder")
}

func testChromeLaunchProblems() {
    let running = ChromeInstances.find(in: [
        ProcessSnapshot(pid: 200, ppid: 1, name: "Google Chrome", executablePath: chrome,
                        arguments: [chrome, "--user-data-dir=/Users/me/a", "--remote-debugging-port=9366"],
                        memoryBytes: 1),
    ])
    let same = ChromeConfig(userDataDir: "/Users/me/a", debugPort: 9366)
    expectEq(ChromeInstances.problems(for: same, running: running, listeningPorts: [9366]), [.alreadyRunning],
             "same profile running → already running (its own port isn't a conflict)")

    let clash = ChromeConfig(userDataDir: "/Users/me/b", debugPort: 9366)
    expectEq(ChromeInstances.problems(for: clash, running: running, listeningPorts: [9366]), [.portInUse(9366)],
             "another instance holds the port")

    let dflt = ChromeConfig(debugPort: 9222)
    expectEq(ChromeInstances.problems(for: dflt, running: [], listeningPorts: []), [.defaultProfileWithDebugPort],
             "Chrome ignores debug port on the default profile")

    let ok = ChromeConfig(userDataDir: "/Users/me/c", debugPort: 9400)
    expectEq(ChromeInstances.problems(for: ok, running: running, listeningPorts: [9366]), [], "free → no problems")
}

func testChromeProfileHelpers() {
    let dir = NSTemporaryDirectory() + "pharos-chrome-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: dir + "/Default", withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: dir) }
    let state = #"{"profile":{"info_cache":{"Default":{"name":"Work","user_name":"me@x.com"},"Profile 1":{"name":"Alt"}}}}"#
    FileManager.default.createFile(atPath: dir + "/Local State", contents: Data(state.utf8))
    FileManager.default.createFile(atPath: dir + "/Default/blob", contents: Data(repeating: 0, count: 10_000))

    expectEq(ChromeInstances.profileNames(in: dir), ["Work (me@x.com)", "Alt"], "profile names from Local State")
    expectEq(ChromeInstances.profileNames(in: dir + "/missing"), [], "missing Local State → empty")
    expect(ChromeInstances.folderSize(dir) >= 10_000, "folder size counts nested files")

    let preset = ChromePreset(name: "grok", config: ChromeConfig(userDataDir: dir, debugPort: 9223))
    let back = (try? JSONEncoder().encode([preset])).flatMap { try? JSONDecoder().decode([ChromePreset].self, from: $0) }
    expectEq(back, [preset], "presets round-trip through JSON")
}
