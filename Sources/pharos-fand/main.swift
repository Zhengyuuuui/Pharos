import Darwin
import Foundation
import PharosCore

// pharos-fand: the only part of Pharos that runs as root. Installed by the
// user from the Fans & Temperature page (admin password), launched by launchd from
// /Library/LaunchDaemons/local.pharos.fand.plist.
//
// It accepts only the commands in `FanProtocol` over a 0600 Unix socket owned
// by the installing user, and re-evaluates `FanPolicy` every second:
//   - fans are never left pinned: no heartbeat for 15 s → back to macOS
//   - any CPU/GPU sensor ≥ 95 °C → every fan to max until < 88 °C
//   - on exit (SIGTERM from launchd / uninstall) → back to macOS
// Unlock sequence from agoodkind/macos-smc-fan research (MIT).

setvbuf(stdout, nil, _IOLBF, 0)
private let logDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()
private let logLock = NSLock()

func log(_ s: String) {
    let ts: String
    logLock.lock()
    ts = logDateFormatter.string(from: Date())
    logLock.unlock()
    print("[\(ts)] pharos-fand: \(s)")
}

guard getuid() == 0 else {
    log("must run as root (installed from Pharos → Fans & Temperature → Install Fan Control)")
    exit(1)
}
guard CommandLine.arguments.count == 2, let ownerUID = uid_t(CommandLine.arguments[1]) else {
    log("usage: pharos-fand <uid allowed to connect>")
    exit(2)
}
guard let smc = SMCClient() else {
    log("cannot open AppleSMC")
    exit(1)
}

if rotateLogIfNeeded(path: FanHelperInstall.logPath) {
    log("rotated log file \(FanHelperInstall.logPath): truncated to last \(LogRotation.defaultKeepBytes / 1024) KB")
}

final class FanDaemon: @unchecked Sendable {
    private let smc: SMCClient
    private let lock = NSLock()
    private var request: FanRequest = .system
    private var lastHeartbeat: Date?
    private var policy = FanPolicy.State()
    private var holding = false
    private var unsupported = false
    private let modeTemplate: String
    private let hasUnlock: Bool

    init(smc: SMCClient) {
        self.smc = smc
        modeTemplate = smc.exists("F0md") ? "F%dmd" : "F%dMd"
        hasUnlock = smc.exists("Ftst")
    }

    // MARK: Commands (socket threads)

    func handle(_ command: FanProtocol.Command) -> FanProtocol.Reply {
        lock.lock()
        defer { lock.unlock() }
        switch command {
        case .status: break
        case .heartbeat: lastHeartbeat = Date()
        case .set(let r):
            request = r
            lastHeartbeat = Date()
            unsupported = false
            log("request \(FanProtocol.encode(.set(r)))")
        }
        let reply = FanProtocol.Reply(ok: true, request: request, overheating: policy.overheating, unsupported: unsupported)
        if case .set = command { DispatchQueue.global().async { self.tick() } }
        return reply
    }

    // MARK: Control loop

    func tick() {
        lock.lock()
        defer { lock.unlock() }
        guard let snap = Thermals.read(using: smc), !snap.fans.isEmpty else { return }
        let action = FanPolicy.decide(request: request, fans: snap.fans, chipCelsius: snap.peakChipTemperature,
                                      lastHeartbeat: lastHeartbeat, now: Date(), state: &policy)
        switch action {
        case .release:
            if holding || snap.unlockEngaged || snap.fans.contains(where: { $0.mode == .manual }) {
                releaseLocked(fans: snap.fans.count)
            }
            if request != .system, lastHeartbeat.map({ Date().timeIntervalSince($0) > FanPolicy.heartbeatTimeout }) ?? true {
                if holding { log("no heartbeat from Pharos — fans back to macOS") }
                request = .system
            }
        case .hold(let targets):
            if !holding || snap.fans.contains(where: { $0.mode != .manual }) {
                guard takeManualLocked(fans: snap.fans.count) else {
                    unsupported = true
                    request = .system
                    releaseLocked(fans: snap.fans.count)
                    log("manual mode rejected by firmware — left fans with macOS")
                    return
                }
                holding = true
            }
            for (i, rpm) in targets.enumerated() where snap.fans[i].targetRPM != rpm {
                smc.write("F\(i)Tg", SMCCodec.bytes(Float(rpm)))
            }
        }
    }

    /// Ftst=1 makes thermalmonitord yield (M1–M4); then each fan's mode can go to manual.
    private func takeManualLocked(fans: Int) -> Bool {
        if hasUnlock { smc.write("Ftst", [1]) }
        let deadline = Date().addingTimeInterval(10)
        var pending = Set(0..<fans)
        while !pending.isEmpty, Date() < deadline {
            for i in pending where smc.write(String(format: modeTemplate, i), [1]) { pending.remove(i) }
            if !pending.isEmpty { usleep(100_000) }
        }
        return pending.isEmpty
    }

    private func releaseLocked(fans: Int) {
        for i in 0..<fans { smc.write(String(format: modeTemplate, i), [0]) }
        if hasUnlock { smc.write("Ftst", [0]) }
        holding = false
    }

    func releaseAll() {
        lock.lock()
        defer { lock.unlock() }
        let count = Int(smc.readUInt8("FNum") ?? 0)
        releaseLocked(fans: count)
        request = .system
    }
}

let daemon = FanDaemon(smc: smc)

// MARK: Exit → always hand fans back

let signalQueue = DispatchQueue(label: "signals")
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT, SIGHUP] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: signalQueue)
    src.setEventHandler {
        daemon.releaseAll()
        unlink(FanProtocol.socketPath)
        log("stopped — fans back to macOS")
        exit(0)
    }
    src.resume()
    signalSources.append(src)
}
// Sleep resets the unlock flag in firmware; the 1 s loop simply re-applies on wake.
daemon.releaseAll()

// MARK: Socket

unlink(FanProtocol.socketPath)
let fd = socket(AF_UNIX, SOCK_STREAM, 0)
guard fd >= 0 else { log("socket() failed: \(errno)"); exit(1) }
var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
let pathBytes = Array(FanProtocol.socketPath.utf8)
withUnsafeMutableBytes(of: &addr.sun_path) { buf in
    for (i, b) in pathBytes.prefix(buf.count - 1).enumerated() { buf[i] = b }
}
let bound = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
}
guard bound == 0, chown(FanProtocol.socketPath, ownerUID, 0) == 0, chmod(FanProtocol.socketPath, 0o600) == 0,
      listen(fd, 8) == 0 else {
    log("socket setup failed: \(errno)")
    exit(1)
}
log("listening on \(FanProtocol.socketPath) for uid \(ownerUID)")

let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "tick"))
timer.schedule(deadline: .now() + 1, repeating: 1)
timer.setEventHandler { daemon.tick() }
timer.resume()

func serve(_ client: Int32) {
    defer { close(client) }
    var tv = timeval(tv_sec: 2, tv_usec: 0)
    setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    var on: Int32 = 1
    setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    // Socket is 0600 + owned by the user, but check the peer anyway.
    var peerUID: uid_t = 0, peerGID: gid_t = 0
    guard getpeereid(client, &peerUID, &peerGID) == 0, peerUID == ownerUID || peerUID == 0 else { return }
    var buf = [UInt8](repeating: 0, count: FanProtocol.maxLineBytes)
    let n = buf.withUnsafeMutableBytes { read(client, $0.baseAddress, $0.count) }
    guard n > 0, n < FanProtocol.maxLineBytes else { return }
    let reply: FanProtocol.Reply
    if let cmd = FanProtocol.decode(String(decoding: buf.prefix(n), as: UTF8.self)) {
        reply = daemon.handle(cmd)
    } else {
        reply = FanProtocol.Reply(ok: false, error: "bad request", request: .system, overheating: false, unsupported: false)
    }
    var data = (try? JSONEncoder().encode(reply)) ?? Data()
    data.append(0x0A)
    _ = data.withUnsafeBytes { write(client, $0.baseAddress, $0.count) }
}

while true {
    let client = accept(fd, nil, nil)
    if client < 0 { continue }
    DispatchQueue.global().async { serve(client) }
}
