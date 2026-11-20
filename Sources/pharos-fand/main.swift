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
    private var consecutiveLockFailures = 0
    private let modeTemplate: String
    private let hasUnlock: Bool

    // Clamshell Guard state
    private var clamshellConfig = ClamshellConfig(enabled: false)
    private var clamshellState = ClamshellPolicy.State()
    private var sleepDisabledApplied = false
    private var clamshellAbort: ClamshellAbortReason?

    init(smc: SMCClient) {
        self.smc = smc
        modeTemplate = smc.exists("F0md") ? "F%dmd" : "F%dMd"
        hasUnlock = smc.exists("Ftst")
    }

    // MARK: Commands (socket threads)

    func handle(_ command: FanProtocol.Command) -> FanProtocol.Reply {
        lock.lock()
        defer { lock.unlock() }
        var shouldTick = false
        switch command {
        case .status:
            break
        case .heartbeat:
            lastHeartbeat = Date()
        case .set(let r):
            request = r
            lastHeartbeat = Date()
            unsupported = false
            consecutiveLockFailures = 0
            shouldTick = true
            log("request \(FanProtocol.encode(.set(r)))")
        case .setClamshell(let cfg):
            clamshellConfig = cfg
            clamshellState = ClamshellPolicy.State()
            lastHeartbeat = Date()
            if cfg.enabled {
                clamshellAbort = nil
            }
            shouldTick = true
            log("clamshell \(FanProtocol.encode(.setClamshell(cfg)))")
        case .clearClamshellAbort:
            clamshellAbort = nil
        }
        let reply = FanProtocol.Reply(
            ok: true,
            request: request,
            overheating: policy.overheating,
            unsupported: unsupported,
            clamshellEnabled: clamshellConfig.enabled,
            sleepDisabledApplied: sleepDisabledApplied,
            clamshellAbort: clamshellAbort
        )
        if shouldTick {
            DispatchQueue.global().async { self.tick() }
        }
        return reply
    }

    // MARK: Control loop

    func tick() {
        lock.lock()
        defer { lock.unlock() }
        let snap = Thermals.read(using: smc)
        let now = Date()

        // 1. Evaluate Clamshell Guard (works even on fanless Macs)
        var battPercent: Int? = nil
        var onAC = true
        if clamshellConfig.enabled, let batt = BatteryScanner.read() {
            battPercent = batt.currentPercent
            onAC = (batt.powerSource == .acPower)
        }
        let clamshellAction = ClamshellPolicy.decide(
            config: clamshellConfig,
            chipCelsius: snap?.peakChipTemperature,
            batteryPercent: battPercent,
            isOnACPower: onAC,
            lastHeartbeat: lastHeartbeat,
            now: now,
            state: &clamshellState
        )
        switch clamshellAction {
        case .inactive:
            if sleepDisabledApplied {
                applySleepDisabledLocked(false)
            }
        case .active:
            if !sleepDisabledApplied {
                applySleepDisabledLocked(true)
            }
        case .heartbeatRestore:
            clamshellConfig.enabled = false
            clamshellAbort = .heartbeatTimeout
            applySleepDisabledLocked(false)
            log("no heartbeat from Pharos — clamshell sleep restored")
        case .abort(let reason):
            clamshellConfig.enabled = false
            clamshellAbort = reason
            log("EMERGENCY CLAMSHELL ABORT: \(reason) — restoring sleep & forcing sleepnow")
            let fanCount = snap?.fans.count ?? Int(smc.readUInt8("FNum") ?? 0)
            if fanCount > 0 {
                releaseLocked(fans: fanCount)
            }
            request = .system
            applySleepDisabledLocked(false, force: true)
            triggerSleepNow()
            return
        }

        // 2. Evaluate Fan Policy
        guard let snap, !snap.fans.isEmpty else { return }
        let proactive = clamshellConfig.enabled && clamshellConfig.proactiveFanControl
        let action = FanPolicy.decide(
            request: request,
            fans: snap.fans,
            chipCelsius: snap.peakChipTemperature,
            lastHeartbeat: lastHeartbeat,
            now: now,
            state: &policy,
            clamshellProactive: proactive
        )
        switch action {
        case .release:
            consecutiveLockFailures = 0
            if holding || snap.unlockEngaged || snap.fans.contains(where: { $0.mode == .manual }) {
                releaseLocked(fans: snap.fans.count)
            }
            if request != .system, lastHeartbeat.map({ now.timeIntervalSince($0) > FanPolicy.heartbeatTimeout }) ?? true {
                if holding { log("no heartbeat from Pharos — fans back to macOS") }
                request = .system
            }
        case .hold(let targets):
            let needsLock = !holding || snap.fans.contains(where: { $0.mode != .manual })
            if needsLock {
                if takeManualLocked(fans: snap.fans.count) {
                    holding = true
                    consecutiveLockFailures = 0
                } else {
                    consecutiveLockFailures += 1
                    // Only abandon if manual mode repeatedly fails for 5 consecutive ticks
                    if consecutiveLockFailures >= 5 {
                        unsupported = true
                        request = .system
                        releaseLocked(fans: snap.fans.count)
                        log("manual mode repeatedly rejected by firmware (\(consecutiveLockFailures)s) — left fans with macOS")
                        return
                    }
                }
            } else {
                consecutiveLockFailures = 0
            }

            // In manual mode: keep Ftst=1 reinforced so thermalmonitord does not take over
            if hasUnlock { smc.write("Ftst", [1]) }

            // Write target RPMs and re-assert mode if any drifted
            for (i, rpm) in targets.enumerated() {
                if i < snap.fans.count && snap.fans[i].mode != .manual {
                    smc.write(String(format: modeTemplate, i), [1])
                }
                if i < snap.fans.count && snap.fans[i].targetRPM != rpm {
                    smc.write("F\(i)Tg", SMCCodec.bytes(Float(rpm)))
                }
            }
        }
    }

    // MARK: pmset sleep control (root only)

    private func applySleepDisabledLocked(_ disable: Bool, force: Bool = false) {
        guard force || sleepDisabledApplied != disable else { return }
        let ok = runPmset(["-a", "disablesleep", disable ? "1" : "0"])
        if ok {
            sleepDisabledApplied = disable
            log("pmset disablesleep=\(disable ? 1 : 0)")
        } else {
            log("pmset disablesleep=\(disable ? 1 : 0) failed")
        }
    }

    private func triggerSleepNow() {
        _ = runPmset(["sleepnow"])
    }

    @discardableResult
    private func runPmset(_ arguments: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = arguments
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            log("pmset \(arguments.joined(separator: " ")) error: \(error)")
            return false
        }
    }

    /// Ftst=1 makes thermalmonitord yield (M1–M4); then each fan's mode can go to manual.
    /// thermalmonitord typically needs 100ms–500ms to yield the SMC lock after Ftst=1.
    private func takeManualLocked(fans: Int) -> Bool {
        if hasUnlock { smc.write("Ftst", [1]) }
        let deadline = Date().addingTimeInterval(5.0)
        var pending = Set(0..<fans)
        while !pending.isEmpty, Date() < deadline {
            for i in pending where smc.write(String(format: modeTemplate, i), [1]) {
                pending.remove(i)
            }
            if !pending.isEmpty {
                usleep(100_000) // 100ms: wait for macOS thermalmonitord to yield SMC control
            }
        }
        if pending.isEmpty {
            log("manual mode locked for \(fans) fan(s)")
            return true
        }
        log("takeManualLocked timed out; pending fans: \(pending)")
        return false
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
        clamshellConfig.enabled = false
        clamshellState = ClamshellPolicy.State()
        applySleepDisabledLocked(false, force: true)
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
