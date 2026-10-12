import Foundation

/// A saved workspace: a project folder plus the command that starts it.
public struct Favorite: Codable, Identifiable, Hashable, Sendable {
    public enum CommandSource: String, Codable, Sendable {
        /// Picked from the project files (package.json, Makefile…).
        case detected
        /// Taken from the process that was running when the project was pinned.
        case running
        /// Typed by the user.
        case custom
    }

    public var id: String
    public var name: String
    public var directory: String
    public var command: String
    public var commandSource: CommandSource
    /// Ports seen the last time it ran; shown as a hint while it's stopped.
    public var lastPorts: [UInt16]
    public var addedAt: Date

    public init(id: String = UUID().uuidString, name: String, directory: String, command: String,
                commandSource: CommandSource, lastPorts: [UInt16] = [], addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.directory = WorkspaceMatcher.normalize(directory)
        self.command = command
        self.commandSource = commandSource
        self.lastPorts = lastPorts
        self.addedAt = addedAt
    }
}

public struct LaunchCandidate: Hashable, Sendable {
    public enum Confidence: Int, Comparable, Sendable {
        /// Declared start entry (package.json dev script, manage.py…): auto-filled.
        case declared = 2
        /// Guessed from file names (server.mjs, run.py): auto-filled if nothing better.
        case guessed = 1
        /// Shell scripts: shown, never auto-filled — they may do anything.
        case script = 0

        public static func < (a: Confidence, b: Confidence) -> Bool { a.rawValue < b.rawValue }
    }

    public let command: String
    /// Where it came from, e.g. "package.json · dev". Shown under the command.
    public let origin: String
    public let confidence: Confidence
    /// Script contains commands that discard work (git reset --hard, rm -rf…).
    public let destructive: Bool

    public init(command: String, origin: String, confidence: Confidence = .declared, destructive: Bool = false) {
        self.command = command
        self.origin = origin
        self.confidence = confidence
        self.destructive = destructive
    }
}

/// Reads a project folder's own files to guess how it is started. Read-only;
/// only looks at a fixed set of well-known files in the folder itself.
public enum LaunchDetector {
    /// Script names worth offering, most likely first. Build/test/lint scripts
    /// are not "how you start the project" and are left out.
    static let preferredScripts = ["dev", "start", "serve", "develop", "preview", "watch"]
    static let makeTargets = ["dev", "run", "serve", "start", "up"]

    public static func candidates(in directory: String) -> [LaunchCandidate] {
        let dir = WorkspaceMatcher.normalize(directory)
        func has(_ name: String) -> Bool { FileManager.default.fileExists(atPath: dir + "/" + name) }
        var out: [LaunchCandidate] = []

        if let package = readJSON(dir + "/package.json") {
            let pm = packageManager(package: package, has: has)
            let scripts = (package["scripts"] as? [String: Any])?.compactMapValues { $0 as? String } ?? [:]
            for name in rankedScripts(Array(scripts.keys)) {
                out.append(LaunchCandidate(command: runScript(name, with: pm), origin: "package.json · \(name)"))
            }
        }
        if let deno = readJSON(dir + "/deno.json"), let tasks = deno["tasks"] as? [String: Any] {
            for name in rankedScripts(Array(tasks.keys)) {
                out.append(LaunchCandidate(command: "deno task \(ShellQuote.quote(name))", origin: "deno.json · \(name)"))
            }
        }
        if has("manage.py") {
            out.append(LaunchCandidate(command: "\(python(has: has)) manage.py runserver", origin: "manage.py"))
        }
        if has("bin/dev") {
            out.append(LaunchCandidate(command: "bin/dev", origin: "bin/dev"))
        } else if has("bin/rails") {
            out.append(LaunchCandidate(command: "bin/rails server", origin: "bin/rails"))
        }
        for target in makefileTargets(dir) {
            out.append(LaunchCandidate(command: "make \(target)", origin: "Makefile · \(target)"))
        }
        if ["compose.yaml", "compose.yml", "docker-compose.yml", "docker-compose.yaml"].contains(where: has) {
            out.append(LaunchCandidate(command: "docker compose up", origin: "docker compose"))
        }
        if has("Cargo.toml") { out.append(LaunchCandidate(command: "cargo run", origin: "Cargo.toml")) }
        if has("go.mod") { out.append(LaunchCandidate(command: "go run .", origin: "go.mod")) }
        if has("Package.swift") { out.append(LaunchCandidate(command: "swift run", origin: "Package.swift")) }
        for (name, _) in pyprojectScripts(dir) {
            out.append(LaunchCandidate(command: "\(python(has: has, module: true)) \(ShellQuote.quote(name))",
                                       origin: "pyproject.toml · \(name)"))
        }

        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        if !has("manage.py") {
            for entry in pythonEntries(files) {
                out.append(LaunchCandidate(command: "\(python(has: has)) \(ShellQuote.quote(entry))",
                                           origin: entry, confidence: .guessed))
            }
        }
        if !has("package.json") {
            for entry in nodeEntries(files) {
                out.append(LaunchCandidate(command: "node \(ShellQuote.quote(entry))", origin: entry, confidence: .guessed))
            }
        }
        for script in shellScripts(files) {
            let body = (try? String(contentsOfFile: dir + "/" + script, encoding: .utf8)) ?? ""
            out.append(LaunchCandidate(command: "./\(ShellQuote.quote(script))", origin: script,
                                       confidence: .script, destructive: isDestructive(body)))
        }

        var seen = Set<String>()
        return out.filter { seen.insert($0.command).inserted }
    }

    /// The command to pre-fill for a new favorite: the best non-script
    /// candidate. Shell scripts are never auto-filled.
    public static func autoFill(in directory: String) -> LaunchCandidate? {
        let candidates = candidates(in: directory).filter { $0.confidence > .script }
        return candidates.first { $0.confidence == .declared } ?? candidates.first
    }

    /// Turns a running listener's command line back into a start command.
    /// Prefers the package.json script that launches the same tool (a running
    /// `node …/node_modules/.bin/vite` → `pnpm run dev`); otherwise rebuilds
    /// the command line with paths made relative to the project folder.
    public static func command(forRunning arguments: [String], in directory: String) -> String? {
        guard !arguments.isEmpty else { return nil }
        let dir = WorkspaceMatcher.normalize(directory)
        if let package = readJSON(dir + "/package.json"),
           let scripts = (package["scripts"] as? [String: Any])?.compactMapValues({ $0 as? String }),
           let tool = nodeTool(in: arguments),
           let name = bestScript(for: tool, arguments: arguments, scripts: scripts) {
            func has(_ n: String) -> Bool { FileManager.default.fileExists(atPath: dir + "/" + n) }
            return runScript(name, with: packageManager(package: package, has: has))
        }
        return rebuild(arguments, relativeTo: dir)
    }

    // MARK: - Node

    static func rankedScripts(_ names: [String]) -> [String] {
        let preferred = preferredScripts.filter(names.contains)
        let related = names.filter { name in
            !preferred.contains(name) && preferredScripts.contains { name.hasPrefix($0 + ":") || name.hasPrefix($0 + "-") }
        }.sorted()
        return preferred + related
    }

    static func runScript(_ name: String, with pm: String) -> String {
        if pm == "npm", name == "start" { return "npm start" }
        return "\(pm) run \(ShellQuote.quote(name))"
    }

    static func packageManager(package: [String: Any], has: (String) -> Bool) -> String {
        if let field = package["packageManager"] as? String,
           let name = field.split(separator: "@").first.map(String.init),
           ["npm", "pnpm", "yarn", "bun"].contains(name) {
            return name
        }
        if has("pnpm-lock.yaml") { return "pnpm" }
        if has("yarn.lock") { return "yarn" }
        if has("bun.lockb") || has("bun.lock") { return "bun" }
        return "npm"
    }

    /// The JS tool a node process is running: `…/node_modules/.bin/vite` → vite,
    /// `node …/node_modules/next/dist/bin/next dev` → next.
    static func nodeTool(in arguments: [String]) -> String? {
        for arg in arguments.prefix(3) {
            if let range = arg.range(of: "/node_modules/.bin/") {
                return String(arg[range.upperBound...]).split(separator: "/").first.map(String.init)
            }
            if let range = arg.range(of: "/node_modules/", options: .backwards) {
                let rest = arg[range.upperBound...].split(separator: "/")
                guard let first = rest.first else { continue }
                // Scoped packages: @scope/name
                if first.hasPrefix("@"), rest.count > 1 { return "\(first)/\(rest[1])" }
                return String(first)
            }
        }
        return nil
    }

    /// Script whose first word is `tool`; ties broken by how many of the
    /// script's other words appear in the running command (`next dev` vs `next start`).
    static func bestScript(for tool: String, arguments: [String], scripts: [String: String]) -> String? {
        let toolName = tool.split(separator: "/").last.map(String.init) ?? tool
        let argSet = Set(arguments)
        var best: (name: String, score: Int)?
        for name in rankedScripts(Array(scripts.keys)) + scripts.keys.sorted() {
            guard let value = scripts[name] else { continue }
            let words = value.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let first = words.first, first == toolName || first == tool else { continue }
            let rest = words.dropFirst().filter { !$0.hasPrefix("-") }
            let matched = rest.filter(argSet.contains).count
            guard matched == rest.count else { continue }
            if best == nil || matched > best!.score { best = (name, matched) }
        }
        return best?.name
    }

    // MARK: - Others

    /// How to run Python here. `module: true` = running a console script name
    /// (uv run X / poetry run X), not a .py file.
    static func python(has: (String) -> Bool, module: Bool = false) -> String {
        if has("uv.lock") { return "uv run" }
        if has("poetry.lock") { return module ? "poetry run" : "poetry run python" }
        if has(".venv/bin/python") { return module ? ".venv/bin/python -m" : ".venv/bin/python" }
        return module ? "python3 -m" : "python3"
    }

    /// Typical server entry files, most likely first. Helper scripts
    /// (register.py, checkin.py…) are deliberately not guessed.
    static let pythonEntryNames = ["main.py", "app.py", "server.py", "run.py", "serve.py", "web.py",
                                   "gateway.py", "bridge.py", "api.py", "wsgi.py", "asgi.py"]
    static let nodeEntryNames = ["server.mjs", "server.js", "index.mjs", "index.js", "main.mjs", "main.js",
                                 "app.mjs", "app.js", "console_server.mjs"]
    static let shellScriptNames = ["start.sh", "run.sh", "dev.sh", "serve.sh"]

    static func pythonEntries(_ files: [String]) -> [String] { pythonEntryNames.filter(files.contains) }
    static func nodeEntries(_ files: [String]) -> [String] { nodeEntryNames.filter(files.contains) }
    static func shellScripts(_ files: [String]) -> [String] { shellScriptNames.filter(files.contains) }

    static let destructivePatterns = [
        #"git\s+reset\s+--hard"#, #"git\s+clean\s+-[a-z]*f"#, #"git\s+checkout\s+--\s"#,
        #"rm\s+-[a-z]*r[a-z]*f"#, #"rm\s+-[a-z]*f[a-z]*r"#, #"\bsudo\b"#,
    ]

    static func isDestructive(_ script: String) -> Bool {
        let code = script.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .joined(separator: "\n")
        return destructivePatterns.contains { code.range(of: $0, options: .regularExpression) != nil }
    }

    /// `[project.scripts]` names from pyproject.toml — just enough TOML for
    /// `name = "module:func"` lines inside that one table.
    static func pyprojectScripts(_ dir: String) -> [(String, String)] {
        guard let text = try? String(contentsOfFile: dir + "/pyproject.toml", encoding: .utf8) else { return [] }
        var inTable = false
        var out: [(String, String)] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") { inTable = line == "[project.scripts]"; continue }
            guard inTable, !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
            let name = line[..<eq].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || "-_.".contains($0) }) {
                out.append((name, value))
            }
        }
        return out
    }

    static func makefileTargets(_ dir: String) -> [String] {
        guard let text = try? String(contentsOfFile: dir + "/Makefile", encoding: .utf8) else { return [] }
        var targets = Set<String>()
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let first = line.first, !first.isWhitespace, first != "#", first != ".",
                  let colon = line.firstIndex(of: ":") else { continue }
            let after = line.index(after: colon)
            if after < line.endIndex, line[after] == "=" { continue } // `X := …` assignment
            for name in line[..<colon].split(separator: " ") { targets.insert(String(name)) }
        }
        return makeTargets.filter(targets.contains)
    }

    /// Flags that make an interpreter run code given inline on the command line.
    static let inlineCodeFlags: Set<String> = ["-e", "--eval", "-p", "--print", "-c", "-r", "eval"]

    /// nil when the command line can't be saved safely: inline code (it often
    /// embeds tokens/headers and isn't a reusable start command), multi-line
    /// arguments, or absurd length.
    static func rebuild(_ arguments: [String], relativeTo dir: String) -> String? {
        if arguments.dropFirst().prefix(3).contains(where: inlineCodeFlags.contains) { return nil }
        if arguments.contains(where: { $0.contains("\n") }) { return nil }
        let command = arguments.enumerated().map { index, arg in
            if arg.hasPrefix(dir + "/") { return ShellQuote.quote(String(arg.dropFirst(dir.count + 1))) }
            // Interpreters by name (node, python3) so the user's PATH / version manager picks them.
            if index == 0, arg.hasPrefix("/") { return ShellQuote.quote(interpreterName(arg)) }
            return ShellQuote.quote(arg)
        }.joined(separator: " ")
        return command.count <= 500 ? command : nil
    }

    /// python.org's framework build runs as `…/Python.app/Contents/MacOS/Python`;
    /// that name isn't on PATH. Versioned names (python3.12, node22) are kept
    /// generic so the user's current toolchain is used.
    static func interpreterName(_ path: String) -> String {
        let name = (path as NSString).lastPathComponent
        if name == "Python" || name.range(of: #"^python3(\.\d+)?$"#, options: .regularExpression) != nil {
            return "python3"
        }
        return name
    }

    static func readJSON(_ path: String) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

public enum WorkspaceMatcher {
    public static func normalize(_ path: String) -> String {
        var p = (path as NSString).expandingTildeInPath
        while p.count > 1, p.hasSuffix("/") { p.removeLast() }
        return p
    }

    /// Running projects grouped under the favorite whose folder contains them.
    /// The deepest favorite wins, so a nested favorite keeps its own projects.
    public static func match(_ favorites: [Favorite], _ projects: [Project]) -> [String: [Project]] {
        let sorted = favorites.sorted { $0.directory.count > $1.directory.count }
        var result: [String: [Project]] = [:]
        for project in projects {
            guard let dir = project.directory.map(normalize) else { continue }
            if let fav = sorted.first(where: { dir == $0.directory || dir.hasPrefix($0.directory + "/") }) {
                result[fav.id, default: []].append(project)
            }
        }
        return result
    }

    /// The favorite that already covers this exact folder, if any.
    public static func favorite(for directory: String, in favorites: [Favorite]) -> Favorite? {
        let dir = normalize(directory)
        return favorites.first { $0.directory == dir }
    }
}

public enum ShellQuote {
    public static func quote(_ s: String) -> String {
        let safe = "@%+=:,./-_"
        if !s.isEmpty, s.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || safe.contains($0)) }) {
            return s
        }
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// The `.command` script handed to the user's terminal app. It runs the command
/// in the user's own login shell, so PATH, nvm, pyenv etc. behave exactly as
/// when typing it by hand.
public enum LaunchScript {
    public static func contents(directory: String, command: String, title: String,
                                shell: String? = nil, interactiveLogin: Bool = true) -> String {
        let dir = ShellQuote.quote(directory)
        let shellLine = shell.map { "SH=\(ShellQuote.quote($0))" } ?? "SH=\"${SHELL:-/bin/zsh}\""
        return """
        #!/bin/sh
        # Generated by UsageBar on your request: runs one saved start command.
        printf '\\033]0;%s\\007' \(ShellQuote.quote(title))
        cd -- \(dir) || { echo "UsageBar: folder not found: "\(dir); exit 1; }
        \(shellLine)
        printf '%s\\n' \(ShellQuote.quote("$ " + command))
        exec "$SH" \(interactiveLogin ? "-ilc" : "-c") \(ShellQuote.quote(command))

        """
    }

    public static func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }
}
