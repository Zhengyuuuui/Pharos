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
func log(_ s: String) { print("pharos-battd: \(s)") }

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

final class BatteryDaemon: @unchecked Sendable {
    private let smc: SMCClient
    private let lock = NSLock()
    private var mode: BatteryMode = .system
    private var syncMagSafe = true
    private var lastHeartbeat: Date?
    private var policyState = BatteryPolicy.State()
    private var sleepAssertionID: IOPMAssertionID = 0

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
        log("SMC capabilities: CHTE=\(hasCHTE), CH0C=\(hasCH0C), CHIE=\(hasCHIE), ACLC=\(hasACLC)")
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
            log("mode set to \(BatteryProtocol.encode(.setMode(m)))")
        case .syncMagSafe(let on):
            syncMagSafe = on
            if !on, hasACLC { smc.write("ACLC", [0]) }
        }

        let reply = BatteryProtocol.Reply(
            ok: true,
            mode: mode,
            isHolding: policyState.isHolding,
            isAdapterBypassed: policyState.isAdapterBypassed,
            magSafeSync: syncMagSafe,
            unsupported: unsupported
        )
        if case .setMode = command {
            DispatchQueue.global().async { self.tick() }
        }
        return reply
    }

    // MARK: - Control Loop

    func tick() {
        lock.lock()
        defer { lock.unlock() }

        guard !unsupported else { return }

        let reading = BatteryScanner.read() ?? BatteryReading()
        let isAC = (reading.powerSource == .acPower)
        let now = Date()

        let decision = BatteryPolicy.decide(
            mode: mode,
            currentPercent: reading.currentPercent,
            isACConnected: isAC,
            temperatureCelsius: reading.temperatureCelsius,
            syncMagSafe: syncMagSafe,
            lastHeartbeat: lastHeartbeat,
            now: now,
            state: &policyState
        )

        // Heartbeat timeout fallback
        if mode != .system, let beat = lastHeartbeat, now.timeIntervalSince(beat) > BatteryPolicy.heartbeatTimeout {
            log("no heartbeat from Pharos — control returned to macOS")
            mode = .system
        }

        // Apply hardware action
        switch decision.action {
        case .release:
            releaseHardwareLocked()

        case .inhibitCharge:
            if hasCHTE {
                smc.write("CHTE", [1, 0, 0, 0])
            } else if hasCH0C {
                smc.write("CH0C", [1])
            }
            if hasCHIE { smc.write("CHIE", [0]) }
            if hasCH0J { smc.write("CH0J", [0]) }
            if syncMagSafe && hasACLC {
                smc.write("ACLC", [decision.magSafeColor.rawValue])
            }

        case .allowCharge:
            if hasCHTE {
                smc.write("CHTE", [0, 0, 0, 0])
            } else if hasCH0C {
                smc.write("CH0C", [0])
            }
            if hasCHIE { smc.write("CHIE", [0]) }
            if hasCH0J { smc.write("CH0J", [0]) }
            if syncMagSafe && hasACLC {
                smc.write("ACLC", [decision.magSafeColor.rawValue])
            }

        case .bypassAdapter:
            // Safe fallback: never cut the AC adapter. Inhibit charging with continuous adapter power.
            if hasCHTE {
                smc.write("CHTE", [1, 0, 0, 0])
            } else if hasCH0C {
                smc.write("CH0C", [1])
            }
            if hasCHIE { smc.write("CHIE", [0]) }
            if hasCH0J { smc.write("CH0J", [0]) }
            if syncMagSafe && hasACLC {
                smc.write("ACLC", [BatteryPolicy.MagSafeColor.green.rawValue])
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

    private func releaseHardwareLocked() {
        if hasCHTE { smc.write("CHTE", [0, 0, 0, 0]) }
        if hasCH0C { smc.write("CH0C", [0]) }
        if hasCHIE { smc.write("CHIE", [0]) }
        if hasCH0J { smc.write("CH0J", [0]) }
        if hasACLC { smc.write("ACLC", [0]) }
    }

    func releaseAll() {
        lock.lock()
        defer { lock.unlock() }
        releaseHardwareLocked()
        updateSleepAssertionLocked(.allowSleep)
        mode = .system
        policyState = BatteryPolicy.State()
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
        log("stopped — charging returned to macOS")
        exit(0)
    }
    src.resume()
    signalSources.append(src)
}

daemon.releaseAll()

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
timer.schedule(deadline: .now() + 1, repeating: 1)
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
