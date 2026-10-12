import DiskArbitration
import Foundation

/// One mounted volume as Finder shows it: the startup disk, external drives,
/// network shares and mounted disk images.
public struct DiskVolume: Identifiable, Hashable, Sendable {
    public enum Kind: Int, Comparable, Sendable {
        case startup, internalDisk, external, network, diskImage
        public static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }
    }

    public let path: String
    public let name: String
    public let kind: Kind
    public let total: UInt64
    /// Matches Finder's "Available": includes purgeable space macOS frees on demand.
    public let available: UInt64
    public let format: String?
    /// Device interface, e.g. "USB", "Thunderbolt", "Apple Fabric".
    public let connection: String?
    public let isReadOnly: Bool
    public let isEjectable: Bool

    public init(path: String, name: String, kind: Kind, total: UInt64, available: UInt64,
                format: String? = nil, connection: String? = nil, isReadOnly: Bool = false, isEjectable: Bool = false) {
        self.path = path
        self.name = name
        self.kind = kind
        self.total = total
        self.available = min(available, total)
        self.format = format
        self.connection = connection
        self.isReadOnly = isReadOnly
        self.isEjectable = isEjectable
    }

    public var id: String { path }
    public var used: UInt64 { total - available }
    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

public enum DiskVolumes {
    /// Facts about one mount, gathered from URL resource values, statfs and DiskArbitration.
    public struct Probe: Sendable {
        public var path: String
        public var name: String
        public var total: UInt64
        public var available: UInt64
        public var availableForImportantUsage: UInt64?
        public var isRoot: Bool
        public var isInternal: Bool?
        public var isLocal: Bool
        public var isBrowsable: Bool
        public var isReadOnly: Bool
        public var isEjectable: Bool
        public var deviceProtocol: String?
        public var format: String?

        public init(path: String, name: String, total: UInt64, available: UInt64,
                    availableForImportantUsage: UInt64? = nil, isRoot: Bool = false, isInternal: Bool? = nil,
                    isLocal: Bool = true, isBrowsable: Bool = true, isReadOnly: Bool = false,
                    isEjectable: Bool = false, deviceProtocol: String? = nil, format: String? = nil) {
            self.path = path
            self.name = name
            self.total = total
            self.available = available
            self.availableForImportantUsage = availableForImportantUsage
            self.isRoot = isRoot
            self.isInternal = isInternal
            self.isLocal = isLocal
            self.isBrowsable = isBrowsable
            self.isReadOnly = isReadOnly
            self.isEjectable = isEjectable
            self.deviceProtocol = deviceProtocol
            self.format = format
        }
    }

    /// Pure classification, kept separate from the system calls so it can be unit-tested.
    public static func classify(_ probes: [Probe]) -> [DiskVolume] {
        probes.compactMap { p -> DiskVolume? in
            // System volumes (VM, Preboot, simulator runtimes…) aren't browsable; Finder hides them too.
            guard p.isRoot || p.isBrowsable, p.total > 0 else { return nil }
            let kind: DiskVolume.Kind
            if p.isRoot { kind = .startup }
            else if !p.isLocal { kind = .network }
            else if p.deviceProtocol?.localizedCaseInsensitiveContains("virtual") == true
                        || p.deviceProtocol?.localizedCaseInsensitiveContains("disk image") == true { kind = .diskImage }
            else if p.isInternal == true { kind = .internalDisk }
            else { kind = .external }
            let available = kind == .startup ? max(p.available, p.availableForImportantUsage ?? 0) : p.available
            return DiskVolume(path: p.path, name: p.name, kind: kind, total: p.total, available: available,
                              format: p.format, connection: kind == .network ? nil : p.deviceProtocol,
                              // The startup disk is a sealed read-only snapshot; that isn't a property users care about.
                              isReadOnly: kind != .startup && p.isReadOnly,
                              isEjectable: kind != .startup && (p.isEjectable || kind == .network || kind == .external))
        }
        .sorted { ($0.kind, $0.name.lowercased()) < ($1.kind, $1.name.lowercased()) }
    }

    /// Reads every mounted volume. Can block briefly on slow network shares,
    /// so call it off the main thread.
    public static func read() -> [DiskVolume] {
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeLocalizedNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey, .volumeIsRootFileSystemKey, .volumeIsInternalKey,
            .volumeIsLocalKey, .volumeIsBrowsableKey, .volumeIsReadOnlyKey, .volumeIsEjectableKey,
            .volumeIsRemovableKey, .volumeLocalizedFormatDescriptionKey,
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) ?? []
        let session = DASessionCreate(kCFAllocatorDefault)
        let probes = urls.compactMap { url -> Probe? in
            guard let v = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            var proto: String?
            if let session, let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
               let d = DADiskCopyDescription(disk) as? [String: Any] {
                proto = d[kDADiskDescriptionDeviceProtocolKey as String] as? String
                if d[kDADiskDescriptionDeviceModelKey as String] as? String == "Disk Image" { proto = "Disk Image" }
            }
            return Probe(
                path: url.path,
                name: v.volumeLocalizedName ?? v.volumeName ?? url.lastPathComponent,
                total: UInt64(max(0, v.volumeTotalCapacity ?? 0)),
                available: UInt64(max(0, v.volumeAvailableCapacity ?? 0)),
                availableForImportantUsage: v.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) },
                isRoot: v.volumeIsRootFileSystem ?? (url.path == "/"),
                isInternal: v.volumeIsInternal,
                isLocal: v.volumeIsLocal ?? true,
                isBrowsable: v.volumeIsBrowsable ?? false,
                isReadOnly: v.volumeIsReadOnly ?? false,
                isEjectable: (v.volumeIsEjectable ?? false) || (v.volumeIsRemovable ?? false),
                deviceProtocol: proto,
                format: v.volumeLocalizedFormatDescription
            )
        }
        return classify(probes)
    }
}
