import Foundation

public enum ProjectGrouper {
    private static let systemPrefixes = [
        "/System/", "/usr/libexec/", "/usr/sbin/", "/Library/Apple/",
        "/Applications/", "/System/Applications/",
    ]

    /// Background apps / daemons (AirPlay receiver, Spotify, Docker Desktop UI…) are
    /// launched by launchd with cwd "/" or live in app bundles; dev servers aren't.
    public static func isSystemProcess(_ p: ProcessSnapshot) -> Bool {
        if let path = p.executablePath, systemPrefixes.contains(where: path.hasPrefix) {
            return true
        }
        return p.cwd == nil || p.cwd == "/"
    }

    public static func group(_ all: [ProcessSnapshot],
                             homeDirectory: String = NSHomeDirectory(),
                             includeSystem: Bool = false) -> [Project] {
        let listeners = all.filter { !$0.ports.isEmpty && (includeSystem || !isSystemProcess($0)) }
        let listenerPIDs = Set(listeners.map(\.pid))

        var children: [Int32: [ProcessSnapshot]] = [:]
        for p in all where p.pid != p.ppid {
            children[p.ppid, default: []].append(p)
        }

        // Stable bucket order: first listener wins the bucket position.
        var order: [String] = []
        var buckets: [String: [ProcessSnapshot]] = [:]
        for p in listeners.sorted(by: { ($0.ports.first?.port ?? 0) < ($1.ports.first?.port ?? 0) }) {
            let key = bucketKey(p, home: homeDirectory)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(p)
        }

        var claimed = listenerPIDs
        var projects: [Project] = []
        for key in order {
            let members = buckets[key] ?? []
            var helpers: [ProcessSnapshot] = []
            var queue = members.map(\.pid)
            while let pid = queue.popLast() {
                for child in children[pid] ?? [] where !claimed.contains(child.pid) {
                    claimed.insert(child.pid)
                    helpers.append(child)
                    queue.append(child.pid)
                }
            }
            let dir = usableDirectory(members.first?.cwd, home: homeDirectory)
            let name = displayName(dir: dir, process: members.first)
            let memory = (members + helpers).reduce(UInt64(0)) { $0 + $1.memoryBytes }
            projects.append(Project(
                id: key,
                name: name,
                directory: dir ?? members.first?.cwd,
                listeners: members.sorted { $0.pid < $1.pid },
                helpers: helpers.sorted { $0.pid < $1.pid },
                ports: ListeningPort.merged(members.flatMap(\.ports)),
                memoryBytes: memory
            ))
        }
        return projects.sorted { ($0.ports.first?.port ?? 0) < ($1.ports.first?.port ?? 0) }
    }

    /// cwd of "/" or $HOME says nothing about which project a process belongs to.
    static func usableDirectory(_ cwd: String?, home: String) -> String? {
        guard let cwd, cwd != "/", cwd != home, cwd != home + "/" else { return nil }
        return cwd
    }

    /// Package-manager services (brew services mongod/redis…) run from data dirs
    /// whose folder name says little; the binary name is clearer.
    private static let serviceRoots = ["/opt/homebrew", "/usr/local", "/opt/local"]

    static func displayName(dir: String?, process: ProcessSnapshot?) -> String {
        let procName = process?.name ?? "?"
        guard let dir else { return procName }
        if serviceRoots.contains(where: { dir == $0 || dir.hasPrefix($0 + "/") }) { return procName }
        return (dir as NSString).lastPathComponent
    }

    static func bucketKey(_ p: ProcessSnapshot, home: String) -> String {
        usableDirectory(p.cwd, home: home) ?? "pid:\(p.pid)"
    }
}
