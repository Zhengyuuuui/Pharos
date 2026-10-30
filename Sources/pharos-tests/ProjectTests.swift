import Foundation
import PharosCore

private let home = "/Users/me"

private func proc(_ pid: Int32, ppid: Int32 = 1, name: String = "node", path: String? = "/opt/homebrew/bin/node",
                  cwd: String? = nil, mem: UInt64 = 100, ports: [UInt16] = [], loopback: Bool = true) -> ProcessSnapshot {
    ProcessSnapshot(pid: pid, ppid: ppid, name: name, executablePath: path, cwd: cwd,
                    arguments: [], memoryBytes: mem,
                    ports: ports.map { ListeningPort(port: $0, loopbackOnly: loopback) })
}

func testListeningPortMerge() {
    let merged = ListeningPort.merged([
        ListeningPort(port: 3000, loopbackOnly: true),
        ListeningPort(port: 3000, loopbackOnly: false),
        ListeningPort(port: 80, loopbackOnly: true),
        ListeningPort(port: 80, loopbackOnly: true),
    ])
    expectEq(merged.map(\.port), [80, 3000], "merge dedups and sorts")
    expectEq(merged[0].loopbackOnly, true, "all-loopback stays loopback")
    expectEq(merged[1].loopbackOnly, false, "any wildcard binding → not loopback-only")
}

func testGrouping() {
    let all = [
        proc(10, cwd: "/Users/me/code/web", mem: 200, ports: [5173]),
        proc(11, ppid: 10, name: "esbuild", cwd: nil, mem: 50),            // helper child
        proc(12, ppid: 11, name: "worker", cwd: nil, mem: 25),             // grandchild
        proc(20, cwd: "/Users/me/code/web", mem: 300, ports: [3001]),      // same dir → same project
        proc(30, name: "python3", path: "/usr/bin/python3", cwd: "/Users/me/code/api", mem: 70, ports: [8000]),
        proc(40, name: "ControlCenter", path: "/System/Library/CoreServices/ControlCenter.app/x", cwd: "/", ports: [7000]),
        proc(50, name: "Spotify", path: "/Applications/Spotify.app/Contents/MacOS/Spotify", cwd: "/", ports: [57621]),
        proc(60, name: "proxy", cwd: home, mem: 10, ports: [8788]),          // cwd = $HOME → own bucket
        proc(61, name: "proxy2", cwd: home, mem: 10, ports: [8789]),
        proc(70, name: "idle", cwd: "/Users/me/code/x", mem: 999),           // no port, not a child
    ]
    let projects = ProjectGrouper.group(all, homeDirectory: home)
    expectEq(projects.map(\.name), ["web", "api", "proxy", "proxy2"], "project names, sorted by port")

    let web = projects[0]
    expectEq(web.ports.map(\.port), [3001, 5173], "web ports merged")
    expectEq(web.listeners.map(\.pid), [10, 20], "web listeners")
    expectEq(web.helpers.map(\.pid), [11, 12], "helpers include grandchildren")
    expectEq(web.memoryBytes, 575, "memory sums listeners + helpers")
    expectEq(web.processCount, 4, "process count")
    expectEq(web.directory, "/Users/me/code/web", "directory")
    expectEq(Set(web.allPIDs), Set<Int32>([10, 11, 12, 20]), "allPIDs")

    expectEq(projects[2].directory, home, "home cwd kept as directory for reveal")
    expect(projects[2].id != projects[3].id, "home-cwd processes don't merge")

    let withSystem = ProjectGrouper.group(all, homeDirectory: home, includeSystem: true)
    expectEq(withSystem.count, 6, "includeSystem shows background apps")

    expect(ProjectGrouper.isSystemProcess(all[5]), "/System path is system")
    expect(ProjectGrouper.isSystemProcess(all[6]), "/Applications is system")
    expect(!ProjectGrouper.isSystemProcess(all[0]), "dev server is not system")
    expect(ProjectGrouper.isSystemProcess(proc(1, cwd: nil)), "unknown cwd treated as system")

    expectEq(ProjectGrouper.group([], homeDirectory: home).count, 0, "empty input")

    let brew = ProjectGrouper.group([
        proc(80, name: "mongod", path: "/opt/homebrew/bin/mongod", cwd: "/opt/homebrew", ports: [27017]),
        proc(81, name: "redis-server", path: "/opt/homebrew/bin/redis-server", cwd: "/opt/homebrew/var/db/redis", ports: [6379]),
    ], homeDirectory: home)
    expectEq(brew.map(\.name), ["redis-server", "mongod"], "brew services named by process")
}

func testShortCommand() {
    let p = ProcessSnapshot(pid: 1, ppid: 0, name: "node",
                            arguments: ["/opt/homebrew/bin/node", "/Users/me/web/node_modules/.bin/vite", "--port", "5173", "--host"],
                            memoryBytes: 0)
    expectEq(p.shortCommand, "node vite --port 5173", "short command trims paths & long args")
    let bare = ProcessSnapshot(pid: 1, ppid: 0, name: "redis-server", memoryBytes: 0)
    expectEq(bare.shortCommand, "redis-server", "falls back to name")
}

func testProcArgsParse() {
    var buf: [UInt8] = []
    withUnsafeBytes(of: Int32(3)) { buf.append(contentsOf: $0) }
    func cstr(_ s: String) -> [UInt8] { Array(s.utf8) + [0] }
    buf += cstr("/usr/bin/python3")
    buf += [0, 0, 0]
    buf += cstr("python3")
    buf += cstr("-m")
    buf += cstr("http.server")
    buf += cstr("PATH=/usr/bin")       // env must be ignored
    expectEq(ProcessScanner.parseProcArgs(buf), ["python3", "-m", "http.server"], "procargs2 parse")
    expectEq(ProcessScanner.parseProcArgs([1, 0]), [], "short buffer")
}

func testByteFormat() {
    expectEq(ByteFormat.short(512 * 1024), "512K", "KB")
    expectEq(ByteFormat.short(84 * 1024 * 1024), "84M", "MB")
    expectEq(ByteFormat.short(UInt64(1.25 * 1024 * 1024 * 1024)), "1.2G", "GB 1 decimal")
    expectEq(ByteFormat.short(12 * 1024 * 1024 * 1024), "12G", "GB no decimal ≥10")
    expectEq(ByteFormat.disk(3_996_329_328_640), "4.0 TB", "disk: decimal units like Finder")
    expectEq(ByteFormat.disk(416_000_000_000), "416 GB", "disk: GB")
    expectEq(ByteFormat.disk(54_000_000), "54 MB", "disk: MB")
}

/// Live smoke test: our own test process opens a loopback listener and must find it.
func testLiveScan() {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { expect(false, "socket()"); return }
    defer { close(fd) }
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_addr.s_addr = UInt32(0x7F00_0001).bigEndian
    addr.sin_port = 0
    let bound = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    expectEq(bound, 0, "bind")
    expectEq(listen(fd, 1), 0, "listen")
    var len = socklen_t(MemoryLayout<sockaddr_in>.size)
    _ = withUnsafeMutablePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
    }
    let port = UInt16(bigEndian: addr.sin_port)

    let me = ProcessScanner.scan().first { $0.pid == getpid() }
    expect(me != nil, "scan finds own process")
    expect(me?.ports.contains(ListeningPort(port: port, loopbackOnly: true)) == true,
           "scan finds own loopback listener on \(port)")
    expect((me?.memoryBytes ?? 0) > 0, "footprint > 0")
    expectEq(me?.cwd, FileManager.default.currentDirectoryPath, "cwd")
    expect(me?.executablePath?.hasSuffix("pharos-tests") == true, "exec path")
}

func testChromeFilteringInProjectGrouper() {
    let home = "/Users/me"
    let chromeExe = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    let helperExe = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/1.0/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"

    let procs = [
        // Real dev project in /Users/me/code/web
        ProcessSnapshot(pid: 10, ppid: 1, name: "node", executablePath: "/opt/homebrew/bin/node",
                        cwd: "/Users/me/code/web", memoryBytes: 150_000_000,
                        ports: [ListeningPort(port: 3000, loopbackOnly: true)]),

        // Chrome browser launched from terminal inside /Users/me/code/web with debug port 9222
        ProcessSnapshot(pid: 20, ppid: 1, name: "Google Chrome", executablePath: chromeExe,
                        cwd: "/Users/me/code/web",
                        arguments: [chromeExe, "--remote-debugging-port=9222", "--user-data-dir=/Users/me/.chrome-debug"],
                        memoryBytes: 250_000_000,
                        ports: [ListeningPort(port: 9222, loopbackOnly: true)]),

        // Helper process child of Chrome
        ProcessSnapshot(pid: 21, ppid: 20, name: "Google Chrome Helper", executablePath: helperExe,
                        cwd: "/Users/me/code/web",
                        arguments: [helperExe, "--type=renderer"],
                        memoryBytes: 400_000_000,
                        ports: [])
    ]

    // Normal mode (includeSystem: false)
    let normalProjects = ProjectGrouper.group(procs, homeDirectory: home, includeSystem: false)
    expectEq(normalProjects.count, 1, "only 1 dev project")
    expectEq(normalProjects.first?.name, "web", "project is web")
    expectEq(normalProjects.first?.ports.map(\.port), [3000], "only port 3000, debug port 9222 excluded")
    expectEq(normalProjects.first?.listeners.map(\.pid), [10], "Chrome PID 20 excluded from listeners")
    expectEq(normalProjects.first?.helpers.map(\.pid), [], "Chrome helper PID 21 excluded from helpers")
    expectEq(normalProjects.first?.memoryBytes, 150_000_000, "Chrome memory not added to dev project")

    // System mode (includeSystem: true, e.g. --check --all CLI)
    let allProjects = ProjectGrouper.group(procs, homeDirectory: home, includeSystem: true)
    expectEq(allProjects.count, 1, "even with includeSystem: true, Chrome is not treated as a dev project")
    expectEq(allProjects.first?.ports.map(\.port), [3000], "debug port 9222 excluded in includeSystem mode")
    expectEq(allProjects.first?.allPIDs, [10], "Chrome PIDs never present in allPIDs")
}
