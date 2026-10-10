import Darwin
import Foundation

public enum MemoryPressure: Int, Sendable {
    case normal = 1, warning = 2, critical = 4
}

/// Machine-wide memory, using the same breakdown as Activity Monitor's Memory tab.
public struct SystemMemoryStats: Hashable, Sendable {
    public let total: UInt64
    public let appMemory: UInt64
    public let wired: UInt64
    public let compressed: UInt64
    public let cachedFiles: UInt64
    public let swapUsed: UInt64
    public let swapTotal: UInt64
    public let pressure: MemoryPressure

    public init(total: UInt64, appMemory: UInt64, wired: UInt64, compressed: UInt64,
                cachedFiles: UInt64, swapUsed: UInt64 = 0, swapTotal: UInt64 = 0,
                pressure: MemoryPressure = .normal) {
        self.total = total
        self.appMemory = appMemory
        self.wired = wired
        self.compressed = compressed
        self.cachedFiles = cachedFiles
        self.swapUsed = swapUsed
        self.swapTotal = swapTotal
        self.pressure = pressure
    }

    /// Activity Monitor "Memory Used" = App + Wired + Compressed.
    public var used: UInt64 { min(total, appMemory + wired + compressed) }
    public var free: UInt64 { total - min(total, used + cachedFiles) }
    /// Cached files are reclaimable on demand, so they count as available.
    public var available: UInt64 { total - used }
    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    /// Activity Monitor formulas applied to raw page counts.
    public static func from(pageSize: UInt64, internalPages: UInt64, purgeablePages: UInt64,
                            externalPages: UInt64, wiredPages: UInt64, compressorPages: UInt64,
                            total: UInt64, swapUsed: UInt64 = 0, swapTotal: UInt64 = 0,
                            pressure: MemoryPressure = .normal) -> SystemMemoryStats {
        let app = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        return SystemMemoryStats(
            total: total,
            appMemory: app * pageSize,
            wired: wiredPages * pageSize,
            compressed: compressorPages * pageSize,
            cachedFiles: (externalPages + purgeablePages) * pageSize,
            swapUsed: swapUsed,
            swapTotal: swapTotal,
            pressure: pressure
        )
    }
}

public enum SystemMemory {
    public static func read() -> SystemMemoryStats? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let r = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(sysctlValue("hw.pagesize", as: Int64.self) ?? Int64(getpagesize()))
        let total = UInt64(sysctlValue("hw.memsize", as: Int64.self) ?? 0)
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapOK = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0
        let level = sysctlValue("kern.memorystatus_vm_pressure_level", as: Int32.self) ?? 1

        return .from(
            pageSize: pageSize,
            internalPages: UInt64(stats.internal_page_count),
            purgeablePages: UInt64(stats.purgeable_count),
            externalPages: UInt64(stats.external_page_count),
            wiredPages: UInt64(stats.wire_count),
            compressorPages: UInt64(stats.compressor_page_count),
            total: total,
            swapUsed: swapOK ? swap.xsu_used : 0,
            swapTotal: swapOK ? swap.xsu_total : 0,
            pressure: MemoryPressure(rawValue: Int(level)) ?? .normal
        )
    }

    private static func sysctlValue<T: FixedWidthInteger>(_ name: String, as: T.Type) -> T? {
        var value: T = 0
        var size = MemoryLayout<T>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
    }
}
