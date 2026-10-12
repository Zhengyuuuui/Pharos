import Foundation
import PharosCore

func testDiskVolumeClassify() {
    let probes = [
        // Values seen on this machine (startup disk, a simulator runtime, a mounted .dmg).
        DiskVolumes.Probe(path: "/", name: "Macintosh HD", total: 4_000, available: 3_569,
                          availableForImportantUsage: 3_579, isRoot: true, isInternal: true,
                          isReadOnly: true, deviceProtocol: "Apple Fabric", format: "APFS"),
        DiskVolumes.Probe(path: "/System/Volumes/VM", name: "VM", total: 4_000, available: 3_569,
                          isInternal: true, isBrowsable: false),
        DiskVolumes.Probe(path: "/Library/Developer/CoreSimulator/Volumes/iOS", name: "iOS Simulator",
                          total: 17, available: 1, isBrowsable: false, isEjectable: true),
        DiskVolumes.Probe(path: "/Volumes/Antigravity", name: "Antigravity", total: 520, available: 54,
                          isReadOnly: true, isEjectable: true, deviceProtocol: "Disk Image"),
        DiskVolumes.Probe(path: "/Volumes/T7", name: "T7", total: 2_000, available: 500,
                          isInternal: false, isEjectable: true, deviceProtocol: "USB", format: "ExFAT"),
        DiskVolumes.Probe(path: "/Volumes/share", name: "share", total: 10_000, available: 9_000,
                          isLocal: false, deviceProtocol: nil),
        DiskVolumes.Probe(path: "/Volumes/empty", name: "empty", total: 0, available: 0),
    ]
    let v = DiskVolumes.classify(probes)
    expectEq(v.map(\.name), ["Macintosh HD", "T7", "share", "Antigravity"],
             "hidden system volumes and 0-byte mounts dropped; startup, external, network, disk image order")
    expectEq(v.map(\.kind), [.startup, .external, .network, .diskImage], "kinds")
    expectEq(v[0].available, 3_579, "startup disk uses Finder's available (incl. purgeable)")
    expectEq(v[0].used, 421, "used = total - available")
    expect(!v[0].isReadOnly && !v[0].isEjectable, "sealed system snapshot isn't shown as read-only / ejectable")
    expectEq(v[1].connection, "USB", "external drive keeps its interface")
    expect(v[1].isEjectable && v[2].isEjectable, "external and network volumes are ejectable")
    expect(v[3].isReadOnly, "read-only disk image flagged")

    let over = DiskVolume(path: "/x", name: "x", kind: .external, total: 10, available: 20)
    expectEq(over.used, 0, "available is clamped to total")
}

func testDiskVolumeReadLive() {
    let v = DiskVolumes.read()
    expectEq(v.first?.kind, .startup, "live: startup disk listed first")
    expect((v.first?.total ?? 0) > 0, "live: startup disk has a capacity")
    expect(!v.contains { $0.path.hasPrefix("/System/Volumes/") }, "live: no hidden system volumes")
}
