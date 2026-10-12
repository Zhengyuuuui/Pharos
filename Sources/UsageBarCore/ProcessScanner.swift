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
            guard let info = bsdInfo(pid), info.pbi_uid == uid else { continue }
            let ports = listeningPorts(pid)
            let listening = !ports.isEmpty
            // Needed for every process: per-app memory rolls up by .app bundle.
            let path = executablePath(pid)
            // Chrome browser processes need their flags (profile dir, debug
            // port) even when not listening; helpers are skipped by name.
            let isChrome = ChromeInstances.isChromeExecutable(path: path, argv0: nil)
            result.append(ProcessSnapshot(
                pid: pid,
                ppid: Int32(info.pbi_ppid),
                name: name(of: info),
                executablePath: path,
                cwd: listening ? currentDirectory(pid) : nil,
                arguments: listening || isChrome ? arguments(pid) : [],
                memoryBytes: footprint(pid),
                ports: ports
            ))
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
        return n > 0 ? Array(pids.prefix(Int(n))) : []
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

    /// Same "Memory" figure Activity Monitor shows.
    static func footprint(_ pid: Int32) -> UInt64 {
        var usage = rusage_info_v4()
        let r = withUnsafeMutablePointer(to: &usage) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return r == 0 ? usage.ri_phys_footprint : 0
    }

    static func executablePath(_ pid: Int32) -> String? {
        var buf = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let n = buf.withUnsafeMutableBytes {
            proc_pidpath(pid, $0.baseAddress, UInt32($0.count))
        }
        guard n > 0 else { return nil }
        return String(decoding: buf.prefix(Int(n)), as: UTF8.self)
    }

    static func currentDirectory(_ pid: Int32) -> String? {
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
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bytes) / stride + 16)
        let used = fds.withUnsafeMutableBytes {
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count))
        }
        guard used > 0 else { return [] }

        var ports: [ListeningPort] = []
        for fd in fds.prefix(Int(used) / stride) where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
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
    static func arguments(_ pid: Int32) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return [] }
        var buf = [UInt8](repeating: 0, count: size)
        let ok = buf.withUnsafeMutableBytes {
            sysctl(&mib, 3, $0.baseAddress, &size, nil, 0) == 0
        }
        guard ok else { return [] }
        return parseProcArgs(Array(buf.prefix(size)))
    }

    public static func parseProcArgs(_ buf: [UInt8]) -> [String] {
        guard buf.count > 4 else { return [] }
        let argc = buf.prefix(4).withUnsafeBytes { Int($0.loadUnaligned(as: Int32.self)) }
        var i = 4
        while i < buf.count, buf[i] != 0 { i += 1 }   // exec path
        while i < buf.count, buf[i] == 0 { i += 1 }   // padding
        var args: [String] = []
        while args.count < argc, i < buf.count {
            let start = i
            while i < buf.count, buf[i] != 0 { i += 1 }
            args.append(String(decoding: buf[start..<i], as: UTF8.self))
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
}
