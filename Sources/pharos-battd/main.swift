import Darwin
import Foundation
import IOKit.pwr_mgt
import PharosCore

// pharos-battd: the battery charging control daemon running as root.
// Installed by the user from Pharos → Battery & Charging page (admin password prompt),
// launched by launchd from /Library/LaunchDaemons/local.pharos.battd.plist.
//
// Strictly isolated from fan control (pharos-fand). Accepts only commands in
// `BatteryProtocol` over a 0600 Unix socket owned by the installing user.
// Evaluates `BatteryPolicy` every second:
//   - charging is never left locked: no heartbeat for 15 s → back to macOS
//   - on exit (SIGTERM / uninstall) → all SMC keys restored to default
//   - prevents sleep ONLY while actively charging towards target limit;
//     restores sleep as soon as limit is reached (or on battery).

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
    print("[\(ts)] pharos-battd: \(s)")
}

guard getuid() == 0 else {
    log("must run as root (installed from Pharos → Battery & Charging)")
    exit(1)
}
guard CommandLine.arguments.count == 2, let ownerUID = uid_t(CommandLine.arguments[1]) else {
    log("usage: pharos-battd <uid allowed to connect>")
    exit(2)
}
guard let smc = SMCClient() else {
    log("cannot open AppleSMC")
    exit(1)
}

if rotateLogIfNeeded(path: BatteryHelperInstall.logPath) {
    log("rotated log file \(BatteryHelperInstall.logPath): truncated to last \(LogRotation.defaultKeepBytes / 1024) KB")
}

final class BatteryDaemon: @unchecked Sendable {
    static let statePath = "/Library/PrivilegedHelperTools/local.pharos.battd.state"

    private let smc: SMCClient
    private let lock = NSLock()
    private var mode: BatteryMode = .system
    private var syncMagSafe = true
    private var persistentGuard = true
    private var lastHeartbeat: Date?
    private var policyState = BatteryPolicy.State()
    private var sleepAssertionID: IOPMAssertionID = 0
    private var hardwareEngaged = true
    private var lastAppliedAction: BatteryPolicy.Action?
    private var lastAppliedMagSafe: BatteryPolicy.MagSafeColor?
    private var lastHardwareWriteTime: Date = .distantPast

    let hasCHTE: Bool
    let hasCH0C: Bool
    let hasCHIE: Bool
    let hasCH0J: Bool
    let hasACLC: Bool
    let unsupported: Bool

    init(smc: SMCClient) {
        self.smc = smc
        hasCHTE = smc.exists("CHTE")
        hasCH0C = smc.exists("CH0C")
        hasCHIE = smc.exists("CHIE")
        hasCH0J = smc.exists("CH0J")
        hasACLC = smc.exists("ACLC")
        unsupported = !(hasCHTE || hasCH0C)
        loadStateLocked()
        log("SMC capabilities: CHTE=\(hasCHTE), CH0C=\(hasCH0C), CHIE=\(hasCHIE), ACLC=\(hasACLC), mode=\(BatteryProtocol.encode(.setMode(mode))), persistentGuard=\(persistentGuard)")
    }

    private func saveStateLocked() {
        let dict: [String: Any] = [
            "mode": BatteryProtocol.encode(.setMode(mode)),
            "syncMagSafe": syncMagSafe,
            "persistentGuard": persistentGuard
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: Self.statePath), options: .atomic)
        }
    }

    private func loadStateLocked() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.statePath)),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        if let modeStr = dict["mode"] as? String, let cmd = BatteryProtocol.decode(modeStr), case .setMode(let m) = cmd {
            self.mode = m
            log("restored mode from state: \(modeStr)")
        }
        if let sync = dict["syncMagSafe"] as? Bool {
            self.syncMagSafe = sync
        }
        if let guardOn = dict["persistentGuard"] as? Bool {
            self.persistentGuard = guardOn
        }
    }

    // MARK: - Commands

    func handle(_ command: BatteryProtocol.Command) -> BatteryProtocol.Reply {
        lock.lock()
        defer { lock.unlock() }

        switch command {
        case .status:
            break
        case .heartbeat:
            lastHeartbeat = Date()
        case .setMode(let m):
            mode = m
            lastHeartbeat = Date()
            lastHardwareWriteTime = .distantPast
            saveStateLocked()
            log("mode set to \(BatteryProtocol.encode(.setMode(m)))")
        case .syncMagSafe(let on):
            syncMagSafe = on
            if !on, hasACLC { write("ACLC", [0]) }
            lastHardwareWriteTime = .distantPast
            saveStateLocked()
            DispatchQueue.global().async { self.tick() }
        case .setPersistentGuard(let on):
            persistentGuard = on
            saveStateLocked()
            log("persistent guard set to \(on)")
        }

        let reply = BatteryProtocol.Reply(
            ok: true,
            mode: mode,
            isHolding: policyState.isHolding,
            isAdapterBypassed: policyState.isAdapterBypassed,
            magSafeSync: syncMagSafe,
            persistentGuard: persistentGuard,
            unsupported: unsupported
        )
        if case .setMode = command {
            DispatchQueue.global().async { self.tick() }
        } else if case .setPersistentGuard = command {
            DispatchQueue.global().async { self.tick() }
        }
        return reply
    }

    // MARK: - Control Loop

    func tick() {
        lock.lock()
        defer { lock.unlock() }

        guard !unsupported else { return }

        // When in system mode and hardware locks are already released, skip reading IOKit
        if mode == .system && !hardwareEngaged {
            return
        }

        let reading = BatteryScanner.read() ?? BatteryReading()
        let isAC = (reading.powerSource == .acPower)
        let now = Date()

        let decision = BatteryPolicy.decide(
            mode: mode,
            currentPercent: reading.currentPercent,
            isACConnected: isAC,
            temperatureCelsius: reading.temperatureCelsius,
            syncMagSafe: syncMagSafe,
            persistentGuard: persistentGuard,
            lastHeartbeat: lastHeartbeat,
            now: now,
            state: &policyState
        )

        // Heartbeat timeout fallback only if persistentGuard is explicitly turned off
        if !persistentGuard && mode != .system, let beat = lastHeartbeat, now.timeIntervalSince(beat) > BatteryPolicy.heartbeatTimeout {
            log("no heartbeat from Pharos — control returned to macOS")
            mode = .system
            saveStateLocked()
        }

        // Apply hardware action. Adapter-bypass keys (CHIE/CH0J) are only ever reset to 0:
        // the Mac must stay on adapter power while charging is inhibited.
        switch decision.action {
        case .release:
            releaseHardwareLocked()

        case .inhibitCharge, .allowCharge:
            let targetMagSafe: BatteryPolicy.MagSafeColor = syncMagSafe ? decision.magSafeColor : .system
            let isSameAction = (decision.action == lastAppliedAction)
            let isSameMagSafe = (targetMagSafe == lastAppliedMagSafe)
            let isWithin60s = now.timeIntervalSince(lastHardwareWriteTime) < 60

            if isSameAction && isSameMagSafe && isWithin60s {
                // Deduplicate repetitive SMC writes; keepalive write occurs every 60s
            } else {
                let inhibit: UInt8 = decision.action == .inhibitCharge ? 1 : 0
                if hasCHTE {
                    write("CHTE", [inhibit, 0, 0, 0])
                }
                if hasCH0C {
                    write("CH0C", [inhibit])
                }
                if hasCHIE { write("CHIE", [0]) }
                if hasCH0J { write("CH0J", [0]) }
                if hasACLC { write("ACLC", [targetMagSafe.rawValue]) }
                hardwareEngaged = true
                lastAppliedAction = decision.action
                lastAppliedMagSafe = targetMagSafe
                lastHardwareWriteTime = now
            }
        }

        // Apply sleep directive
        updateSleepAssertionLocked(decision.sleepDirective)
    }

    private func updateSleepAssertionLocked(_ directive: BatteryPolicy.SleepDirective) {
        switch directive {
        case .preventSleep:
            if sleepAssertionID == 0 {
                let name = "Pharos Battery Charge To Limit" as CFString
                _ = IOPMAssertionCreateWithName(
                    kIOPMAssertionTypePreventSystemSleep as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    name,
                    &sleepAssertionID
                )
            }
        case .allowSleep:
            if sleepAssertionID != 0 {
                IOPMAssertionRelease(sleepAssertionID)
                sleepAssertionID = 0
            }
        }
    }

    /// Every SMC write funnels through `BatteryPolicy.isSafeWrite` so no code path can
    /// cut the adapter (CHIE=0x08) or switch the MagSafe LED off (ACLC=0x01).
    private func write(_ key: String, _ bytes: [UInt8]) {
        guard BatteryPolicy.isSafeWrite(key: key, bytes: bytes) else {
            log("refused unsafe SMC write \(key)=\(bytes)")
            return
        }
        if !smc.write(key, bytes) { log("SMC write \(key) failed") }
    }

    /// Idempotent: once released, later ticks leave the SMC untouched so macOS keeps full control.
    private func releaseHardwareLocked(force: Bool = false) {
        guard hardwareEngaged || force else { return }
        if hasCHTE { write("CHTE", [0, 0, 0, 0]) }
        if hasCH0C { write("CH0C", [0]) }
        if hasCHIE { write("CHIE", [0]) }
        if hasCH0J { write("CH0J", [0]) }
        if hasACLC { write("ACLC", [0]) }
        hardwareEngaged = false
        lastAppliedAction = .release
        lastAppliedMagSafe = .system
        lastHardwareWriteTime = Date()
    }

    func releaseAll() {
        lock.lock()
        defer { lock.unlock() }
        releaseHardwareLocked(force: true)
        updateSleepAssertionLocked(.allowSleep)
        mode = .system
        policyState = BatteryPolicy.State()
        saveStateLocked()
    }

    func initializeStartup() {
        lock.lock()
        defer { lock.unlock() }
        if persistentGuard && mode != .system {
            log("startup: restoring persistent mode \(BatteryProtocol.encode(.setMode(mode)))")
            lastHardwareWriteTime = .distantPast
            DispatchQueue.global().async { self.tick() }
        } else {
            releaseHardwareLocked(force: true)
            updateSleepAssertionLocked(.allowSleep)
            mode = .system
            policyState = BatteryPolicy.State()
        }
    }
}

let daemon = BatteryDaemon(smc: smc)

// MARK: - Exit Signal Handling

let signalQueue = DispatchQueue(label: "signals")
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT, SIGHUP] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: signalQueue)
    src.setEventHandler {
        daemon.releaseAll()
        unlink(BatteryProtocol.socketPath)
        unlink(BatteryDaemon.statePath)
        log("stopped — charging returned to macOS")
        exit(0)
    }
    src.resume()
    signalSources.append(src)
}

daemon.initializeStartup()

// MARK: - Unix Socket Setup

unlink(BatteryProtocol.socketPath)
let fd = socket(AF_UNIX, SOCK_STREAM, 0)
guard fd >= 0 else { log("socket() failed: \(errno)"); exit(1) }

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
let pathBytes = Array(BatteryProtocol.socketPath.utf8)
withUnsafeMutableBytes(of: &addr.sun_path) { buf in
    for (i, b) in pathBytes.prefix(buf.count - 1).enumerated() { buf[i] = b }
}

let bound = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
}
guard bound == 0,
      chown(BatteryProtocol.socketPath, ownerUID, 0) == 0,
      chmod(BatteryProtocol.socketPath, 0o600) == 0,
      listen(fd, 8) == 0 else {
    log("socket setup failed: \(errno)")
    exit(1)
}
log("listening on \(BatteryProtocol.socketPath) for uid \(ownerUID)")

let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "battery-tick"))
timer.schedule(deadline: .now() + 3, repeating: 3)
timer.setEventHandler { daemon.tick() }
timer.resume()

func serve(_ client: Int32) {
    defer { close(client) }
    var tv = timeval(tv_sec: 2, tv_usec: 0)
    setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    var on: Int32 = 1
    setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

    var peerUID: uid_t = 0, peerGID: gid_t = 0
    guard getpeereid(client, &peerUID, &peerGID) == 0, peerUID == ownerUID || peerUID == 0 else { return }

    var buf = [UInt8](repeating: 0, count: BatteryProtocol.maxLineBytes)
    let n = buf.withUnsafeMutableBytes { read(client, $0.baseAddress, $0.count) }
    guard n > 0, n < BatteryProtocol.maxLineBytes else { return }

    let reply: BatteryProtocol.Reply
    if let cmd = BatteryProtocol.decode(String(decoding: buf.prefix(n), as: UTF8.self)) {
        reply = daemon.handle(cmd)
    } else {
        reply = BatteryProtocol.Reply(
            ok: false,
            error: "bad request",
            mode: .system,
            isHolding: false,
            isAdapterBypassed: false,
            magSafeSync: false,
            unsupported: false
        )
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
