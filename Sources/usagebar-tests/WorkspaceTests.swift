import Foundation
import UsageBarCore

private func makeProject(_ files: [String: String]) -> (dir: String, done: () -> Void) {
    let dir = NSTemporaryDirectory() + "usagebar-ws-\(UUID().uuidString)"
    for (name, body) in files {
        let path = dir + "/" + name
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                 withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: path, contents: Data(body.utf8))
    }
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return (dir, { try? FileManager.default.removeItem(atPath: dir) })
}

func testLaunchDetectionNode() {
    let (dir, done) = makeProject([
        "package.json": #"{"scripts":{"build":"vite build","dev":"vite","dev:api":"node api.js","start":"vite preview","lint":"eslint ."}}"#,
        "pnpm-lock.yaml": "",
    ])
    defer { done() }
    let c = LaunchDetector.candidates(in: dir)
    expectEq(c.map(\.command), ["pnpm run dev", "pnpm run start", "pnpm run dev:api"],
             "node: preferred scripts first, build/lint excluded, lockfile picks pnpm")
    expectEq(c.first?.origin, "package.json · dev", "origin label")

    let (npmDir, npmDone) = makeProject(["package.json": #"{"scripts":{"start":"node server.js"}}"#])
    defer { npmDone() }
    expectEq(LaunchDetector.candidates(in: npmDir).first?.command, "npm start", "npm start shorthand")

    let (pmDir, pmDone) = makeProject([
        "package.json": #"{"packageManager":"yarn@4.1.0","scripts":{"dev":"next dev"}}"#,
        "package-lock.json": "",
    ])
    defer { pmDone() }
    expectEq(LaunchDetector.candidates(in: pmDir).first?.command, "yarn run dev", "packageManager field wins over lockfile")
}

func testLaunchDetectionOthers() {
    let (dj, djDone) = makeProject(["manage.py": "", "uv.lock": "", "main.py": ""])
    defer { djDone() }
    expectEq(LaunchDetector.candidates(in: dj).map(\.command), ["uv run manage.py runserver"],
             "django via uv; main.py not offered next to manage.py")

    let (mk, mkDone) = makeProject([
        "Makefile": "CC := clang\n.PHONY: dev\ndev: deps\n\tgo run .\nbuild:\n\tgo build\n# run: comment\n",
        "go.mod": "module x",
        "compose.yaml": "",
    ])
    defer { mkDone() }
    expectEq(LaunchDetector.candidates(in: mk).map(\.command), ["make dev", "docker compose up", "go run ."],
             "make start-like targets only, skips assignments/comments; compose; go")

    let (rails, railsDone) = makeProject(["bin/dev": "", "bin/rails": ""])
    defer { railsDone() }
    expectEq(LaunchDetector.candidates(in: rails).map(\.command), ["bin/dev"], "rails prefers bin/dev")

    let (empty, emptyDone) = makeProject(["README.md": "hi"])
    defer { emptyDone() }
    expect(LaunchDetector.candidates(in: empty).isEmpty, "nothing detected in a plain folder")

    let (bad, badDone) = makeProject(["package.json": "{not json"])
    defer { badDone() }
    expect(LaunchDetector.candidates(in: bad).isEmpty, "broken package.json is ignored, not a crash")
}

/// Plain-script projects (most of the user's real folders): no manifest, just
/// an entry file. These used to detect nothing.
func testLaunchDetectionEntryFiles() {
    let (py, pyDone) = makeProject(["serve.py": "", "register.py": "", "requirements.txt": ""])
    defer { pyDone() }
    expectEq(LaunchDetector.candidates(in: py).map(\.command), ["python3 serve.py"],
             "python entry file guessed; helper scripts (register.py) ignored")
    expectEq(LaunchDetector.autoFill(in: py)?.command, "python3 serve.py", "guessed entry is auto-filled")

    let (node, nodeDone) = makeProject(["server.mjs": "", "README.md": ""])
    defer { nodeDone() }
    expectEq(LaunchDetector.autoFill(in: node)?.command, "node server.mjs", "node entry file without package.json")

    let (both, bothDone) = makeProject(["package.json": #"{"scripts":{"dev":"vite"}}"#, "server.js": ""])
    defer { bothDone() }
    expectEq(LaunchDetector.candidates(in: both).map(\.command), ["npm run dev"],
             "package.json present → its scripts, no bare node guess")

    let (uv, uvDone) = makeProject([
        "pyproject.toml": "[project]\nname='x'\n[project.scripts]\ncodebuddy-proxy = \"codebuddy_proxy:main\"\n# c = \"x\"\n[build-system]\nrequires=[]\n",
        "uv.lock": "",
    ])
    defer { uvDone() }
    expectEq(LaunchDetector.candidates(in: uv).map(\.command), ["uv run codebuddy-proxy"],
             "pyproject [project.scripts] → uv run <script>")

    let (sh, shDone) = makeProject([
        "start.sh": "git fetch --all\ngit reset --hard origin/main\npython web.py\n",
        "run.sh": "# rm -rf / is just a comment here\nexec python app.py\n",
        "web.py": "",
    ])
    defer { shDone() }
    let c = LaunchDetector.candidates(in: sh)
    expectEq(c.map(\.command), ["python3 web.py", "./start.sh", "./run.sh"], "shell scripts listed after entry files")
    expectEq(c.first { $0.command == "./start.sh" }?.destructive, true, "git reset --hard flagged")
    expectEq(c.first { $0.command == "./run.sh" }?.destructive, false, "commented-out rm -rf not flagged")
    expectEq(LaunchDetector.autoFill(in: sh)?.command, "python3 web.py", "scripts never auto-filled")

    let (onlySh, onlyShDone) = makeProject(["start.sh": "npm start"])
    defer { onlyShDone() }
    expectEq(LaunchDetector.autoFill(in: onlySh)?.command, nil, "only a shell script → nothing auto-filled")
    expectEq(LaunchDetector.candidates(in: onlySh).map(\.command), ["./start.sh"], "but it is offered")
}

func testRunningCommandMapping() {
    let (dir, done) = makeProject([
        "package.json": #"{"scripts":{"dev":"next dev --turbo","start":"next start","x":"vite"}}"#,
        "pnpm-lock.yaml": "",
    ])
    defer { done() }
    let nextDev = ["node", dir + "/node_modules/next/dist/bin/next", "dev", "--turbo"]
    expectEq(LaunchDetector.command(forRunning: nextDev, in: dir), "pnpm run dev", "running next dev → its script")
    let nextStart = ["node", dir + "/node_modules/next/dist/bin/next", "start"]
    expectEq(LaunchDetector.command(forRunning: nextStart, in: dir), "pnpm run start", "next start → start script")
    let vite = ["node", dir + "/node_modules/.bin/vite"]
    expectEq(LaunchDetector.command(forRunning: vite, in: dir), "pnpm run x", ".bin tool → matching script")

    let py = ["/opt/homebrew/bin/python3", dir + "/server.py", "--port", "8000"]
    expectEq(LaunchDetector.command(forRunning: py, in: dir), "python3 server.py --port 8000",
             "no script match → command line with project paths made relative, interpreter by name")
    let spaced = ["/usr/bin/python3", "-m", "http.server", "--directory", "my site"]
    expectEq(LaunchDetector.command(forRunning: spaced, in: "/elsewhere"),
             "python3 -m http.server --directory 'my site'", "arguments with spaces are quoted")
    expectEq(LaunchDetector.command(forRunning: [], in: dir), nil, "no arguments → nil")

    let framework = ["/Library/Frameworks/Python.framework/Versions/3.12/Resources/Python.app/Contents/MacOS/Python",
                     "-u", dir + "/run.py", "--port", "4555"]
    expectEq(LaunchDetector.command(forRunning: framework, in: dir), "python3 -u run.py --port 4555",
             "python.org framework binary → python3")
    expectEq(LaunchDetector.command(forRunning: ["/opt/homebrew/bin/python3.12", "app.py"], in: "/x"),
             "python3 app.py", "versioned python → python3")
    let venv = [dir + "/.venv/bin/python", "main.py"]
    expectEq(LaunchDetector.command(forRunning: venv, in: dir), ".venv/bin/python main.py", "project venv kept relative")

    // Inline code often carries secrets (auth headers, tokens) — never captured.
    let inline = ["node", "-e", "fetch(url, {headers: {authorization: 'Bearer sk-123'}})"]
    expectEq(LaunchDetector.command(forRunning: inline, in: dir), nil, "node -e inline code is not saved")
    expectEq(LaunchDetector.command(forRunning: ["python3", "-c", "import x"], in: dir), nil, "python -c not saved")
    expectEq(LaunchDetector.command(forRunning: ["/bin/sh", "-c", "TOKEN=abc ./run"], in: dir), nil, "sh -c not saved")
    expectEq(LaunchDetector.command(forRunning: ["node", "server.js", "--note", "a\nb"], in: dir), nil,
             "multi-line argument not saved")
    expectEq(LaunchDetector.command(forRunning: ["node", String(repeating: "x", count: 600)], in: dir), nil,
             "absurdly long command not saved")
}

func testWorkspaceMatching() {
    let a = Favorite(name: "web", directory: "/Users/me/code/web/", command: "pnpm run dev", commandSource: .detected)
    let b = Favorite(name: "api", directory: "/Users/me/code/web/api", command: "make dev", commandSource: .detected)
    expectEq(a.directory, "/Users/me/code/web", "directory normalized (trailing slash)")

    func project(_ id: String, _ dir: String?) -> Project {
        Project(id: id, name: id, directory: dir, listeners: [], helpers: [], ports: [], memoryBytes: 0)
    }
    let m = WorkspaceMatcher.match([a, b], [
        project("root", "/Users/me/code/web"),
        project("sub", "/Users/me/code/web/packages/ui"),
        project("api", "/Users/me/code/web/api"),
        project("other", "/Users/me/code/website"),
        project("nodir", nil),
    ])
    expectEq(m[a.id]?.map(\.id), ["root", "sub"], "favorite owns its folder and subfolders")
    expectEq(m[b.id]?.map(\.id), ["api"], "nested favorite keeps its own project")
    expect(!(m.values.flatMap { $0 }.contains { $0.id == "other" }), "prefix without / boundary doesn't match")
    expectEq(WorkspaceMatcher.favorite(for: "/Users/me/code/web/", in: [a, b])?.id, a.id, "exact folder lookup")

    let data = try? JSONEncoder().encode([a])
    let back = data.flatMap { try? JSONDecoder().decode([Favorite].self, from: $0) }
    expectEq(back, [a], "favorites round-trip through JSON")
}

/// Runs the generated script for real: right folder, command executed once,
/// paths/commands with spaces and quotes survive.
func testLaunchScriptExecutes() {
    let (dir, done) = makeProject(["marker.txt": "x"])
    defer { done() }
    let weird = dir + "/it's a dir"
    try? FileManager.default.createDirectory(atPath: weird, withIntermediateDirectories: true)

    let command = "pwd > out.txt; printf '%s' \"a b\" >> out.txt"
    let script = LaunchScript.contents(directory: weird, command: command, title: "t",
                                       shell: "/bin/sh", interactiveLogin: false)
    let url = URL(fileURLWithPath: dir + "/launch.command")
    do { try LaunchScript.write(script, to: url) } catch { expect(false, "write script: \(error)"); return }

    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
    expectEq((attrs?[.posixPermissions] as? NSNumber)?.intValue, 0o700, "script is executable, owner-only")

    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = [url.path]
    p.standardOutput = FileHandle.nullDevice
    do { try p.run() } catch { expect(false, "run script: \(error)"); return }
    p.waitUntilExit()
    expectEq(p.terminationStatus, Int32(0), "script exits cleanly")

    let out = (try? String(contentsOfFile: weird + "/out.txt", encoding: .utf8)) ?? ""
    let resolved = (weird as NSString).resolvingSymlinksInPath
    expect(out.hasPrefix(resolved) || out.hasPrefix(weird), "ran inside the project folder (got \(out))")
    expect(out.hasSuffix("a b"), "command ran with its own quoting intact")

    let missing = LaunchScript.contents(directory: dir + "/nope", command: "touch should-not-exist",
                                        title: "t", shell: "/bin/sh", interactiveLogin: false)
    let url2 = URL(fileURLWithPath: dir + "/missing.command")
    try? LaunchScript.write(missing, to: url2)
    let p2 = Process()
    p2.executableURL = URL(fileURLWithPath: "/bin/sh")
    p2.arguments = [url2.path]
    p2.currentDirectoryURL = URL(fileURLWithPath: dir)
    p2.standardOutput = FileHandle.nullDevice
    try? p2.run()
    p2.waitUntilExit()
    expect(p2.terminationStatus != 0, "missing folder → script stops")
    expect(!FileManager.default.fileExists(atPath: dir + "/should-not-exist"), "command not run in the wrong folder")
}
