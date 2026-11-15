import Darwin
import Foundation

/// Reads process / socket / memory info via libproc + sysctl (the same kernel
/// APIs `lsof` and Activity Monitor use). Read-only; current user's processes only.
///
/// Raw buffers are confined to this file and always scoped through
/// `withUnsafe…` on Swift arrays/structs — no manual allocation.
public enum ProcessScanner {
    public static func scan() -> [ProcessSnapshot] {
        let uid = getuid()
        var result: [ProcessSnapshot] = []
        for pid in allPIDs() where pid > 0 {
            autoreleasepool {
                guard let info = bsdInfo(pid), info.pbi_uid == uid else { return }
                let ports = listeningPorts(pid)
                let listening = !ports.isEmpty
                // Needed for every process: per-app memory rolls up by .app bundle.
                let path = executablePath(pid)
                // Chrome browser processes need their flags (profile dir, debug
                // port) even when not listening; helpers are skipped by name.
                let isChrome = ChromeInstances.isChromeExecutable(path: path, argv0: nil)
                let procName = name(of: info).lowercased()
                let isProxy = procName.contains("mihomo") || procName.contains("clash") || procName.contains("sing-box")
                // Details (CWD & arguments) are fetched on-demand for listening projects, Chrome profiles,
                // and proxy instances. Generic background scripts fetch them on-demand if they trigger CPUDoctor.
                let shouldFetchDetails = listening || isChrome || isProxy

                let ru = rusage(pid)
                let startTime: Date? = {
                    if info.pbi_start_tvsec > 0 {
                        return Date(timeIntervalSince1970: Double(info.pbi_start_tvsec) + Double(info.pbi_start_tvusec) / 1_000_000.0)
                    }
                    return nil
                }()

                result.append(ProcessSnapshot(
                    pid: pid,
                    ppid: Int32(info.pbi_ppid),
                    name: name(of: info),
                    executablePath: path,
                    cwd: shouldFetchDetails ? currentDirectory(pid) : nil,
                    arguments: shouldFetchDetails ? arguments(pid) : [],
                    memoryBytes: ru.footprint,
                    ports: ports,
                    cpuTimeNs: ru.cpuTimeNs,
                    startTime: startTime
                ))
            }
        }
        return result
    }

    // MARK: - libproc

    static func allPIDs() -> [Int32] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(estimate) + 64)
        let n = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard n > 0 else { return [] }
        let validCount = min(Int(n), pids.count)
        if validCount < pids.count {
            pids.removeSubrange(validCount..<pids.count)
        }
        return pids
    }

    static func bsdInfo(_ pid: Int32) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let r = withUnsafeMutableBytes(of: &info) {
            proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, $0.baseAddress, size)
        }
        return r == size ? info : nil
    }

    static func name(of info: proc_bsdinfo) -> String {
        var copy = info
        let long = withUnsafeBytes(of: &copy.pbi_name) { cString($0) }
        if !long.isEmpty { return long }
        return withUnsafeBytes(of: &copy.pbi_comm) { cString($0) }
    }

    /// Reads memory footprint and cumulative CPU time in nanoseconds via proc_pid_rusage.
    public static func rusage(_ pid: Int32) -> (footprint: UInt64, cpuTimeNs: UInt64) {
        var usage = rusage_info_v4()
        let r = withUnsafeMutablePointer(to: &usage) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        if r == 0 {
            return (usage.ri_phys_footprint, usage.ri_user_time + usage.ri_system_time)
        }
        return (0, 0)
    }

    /// Same "Memory" figure Activity Monitor shows.
    public static func footprint(_ pid: Int32) -> UInt64 {
        rusage(pid).footprint
    }

    public static func executablePath(_ pid: Int32) -> String? {
        withUnsafeTemporaryAllocation(of: CChar.self, capacity: 4 * Int(MAXPATHLEN)) { buffer in
            guard let baseAddress = buffer.baseAddress else { return nil }
            let ret = proc_pidpath(pid, baseAddress, UInt32(buffer.count))
            guard ret > 0 else { return nil }
            return String(cString: baseAddress)
        }
    }

    public static func currentDirectory(_ pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        let r = withUnsafeMutableBytes(of: &info) {
            proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, $0.baseAddress, size)
        }
        guard r == size else { return nil }
        let path = withUnsafeBytes(of: &info.pvi_cdir.vip_path) { cString($0) }
        return path.isEmpty ? nil : path
    }

    static func listeningPorts(_ pid: Int32) -> [ListeningPort] {
        let bytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bytes > 0 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        let fdCount = Int(bytes) / stride + 16
        return withUnsafeTemporaryAllocation(of: proc_fdinfo.self, capacity: fdCount) { buffer in
            guard let baseAddress = buffer.baseAddress else { return [] }
            let used = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, baseAddress, Int32(buffer.count * stride))
            guard used > 0 else { return [] }
            let validCount = min(Int(used) / stride, buffer.count)
            var ports: [ListeningPort] = []
            for i in 0..<validCount {
                let fd = buffer[i]
                guard fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) else { continue }
                var si = socket_fdinfo()
                let size = Int32(MemoryLayout<socket_fdinfo>.size)
                let r = withUnsafeMutableBytes(of: &si) {
                    proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, $0.baseAddress, size)
                }
                guard r == size,
                      si.psi.soi_kind == Int32(SOCKINFO_TCP),
                      si.psi.soi_proto.pri_tcp.tcpsi_state == Int32(TSI_S_LISTEN) else { continue }
                let ini = si.psi.soi_proto.pri_tcp.tcpsi_ini
                let port = UInt16(bigEndian: UInt16(truncatingIfNeeded: ini.insi_lport))
                guard port > 0 else { continue }
                ports.append(ListeningPort(port: port, loopbackOnly: isLoopback(ini)))
            }
            return ListeningPort.merged(ports)
        }
    }

    static func isLoopback(_ ini: in_sockinfo) -> Bool {
        if ini.insi_vflag & UInt8(INI_IPV4) != 0 {
            let addr = UInt32(bigEndian: ini.insi_laddr.ina_46.i46a_addr4.s_addr)
            return addr >> 24 == 127
        }
        var a6 = ini.insi_laddr.ina_6
        return withUnsafeBytes(of: &a6) { b in
            b.prefix(15).allSatisfy { $0 == 0 } && b[15] == 1
        }
    }

    // MARK: - sysctl

    /// KERN_PROCARGS2 layout: argc (Int32), exec path, NUL padding, argv[0..argc).
    public static func arguments(_ pid: Int32) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return [] }
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: size) { buf in
            guard let baseAddress = buf.baseAddress else { return [] }
            var actualSize = size
            let ok = sysctl(&mib, 3, baseAddress, &actualSize, nil, 0) == 0
            guard ok else { return [] }
            let slice = UnsafeBufferPointer(start: baseAddress, count: actualSize)
            return parseProcArgs(slice)
        }
    }

    public static func parseProcArgs(_ buf: [UInt8]) -> [String] {
        buf.withUnsafeBufferPointer { parseProcArgs($0) }
    }

    public static func parseProcArgs(_ buf: UnsafeBufferPointer<UInt8>) -> [String] {
        guard buf.count > 4, let base = buf.baseAddress else { return [] }
        let argc = Int(base.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee })
        var i = 4
        while i < buf.count, buf[i] != 0 { i += 1 }   // exec path
        while i < buf.count, buf[i] == 0 { i += 1 }   // padding
        var args: [String] = []
        while args.count < argc, i < buf.count {
            let start = i
            while i < buf.count, buf[i] != 0 { i += 1 }
            let len = i - start
            if len > 0 {
                let slice = UnsafeBufferPointer(start: base + start, count: len)
                args.append(String(decoding: slice, as: UTF8.self))
            }
            i += 1
        }
        return args
    }

    private static func cString(_ raw: UnsafeRawBufferPointer) -> String {
        let bytes = raw.prefix { $0 != 0 }
        return String(decoding: bytes, as: UTF8.self)
    }
}

public enum ProcessControl {
    public enum Signal { case terminate, kill }

    /// Returns PIDs that could not be signalled (already gone, or not ours).
    @discardableResult
    public static func send(_ signal: Signal, to pids: [Int32]) -> [Int32] {
        let sig = signal == .terminate ? SIGTERM : SIGKILL
        return pids.filter { $0 > 1 && Darwin.kill($0, sig) != 0 }
    }

    public static func isAlive(_ pid: Int32) -> Bool {
        Darwin.kill(pid, 0) == 0
    }

    /// Polls every `interval` until none of `pids` is alive; returns false on timeout.
    public static func waitForExit(_ pids: [Int32], timeout: Double, interval: Double = 0.1) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while pids.contains(where: isAlive) {
            if Date() >= deadline { return false }
            try? await Task.sleep(for: .seconds(interval))
        }
        return true
    }
}
