import Foundation
import PharosCore

func testContainerAndToolchainScanningAndCleaning() {
    let tempHome = NSTemporaryDirectory() + "pharos-toolchain-\(UUID().uuidString)"
    let simDevices = tempHome + "/Library/Developer/CoreSimulator/Devices/7365DD84-A881-4CCF-9CAC-E0F1EC9A6A55"
    let iosDeviceSupport = tempHome + "/Library/Developer/Xcode/iOS DeviceSupport/iPhone14,2 18.7.8 (22H352)"
    let dockerDir = tempHome + "/Library/Containers/com.docker.docker/Data/vms/0/data"
    defer { try? FileManager.default.removeItem(atPath: tempHome) }

    try? FileManager.default.createDirectory(atPath: simDevices + "/data", withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: iosDeviceSupport, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: dockerDir, withIntermediateDirectories: true)

    // Device plist for simulator
    let plistContent = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>UDID</key>
        <string>7365DD84-A881-4CCF-9CAC-E0F1EC9A6A55</string>
        <key>name</key>
        <string>iPhone 17 Pro</string>
        <key>runtime</key>
        <string>com.apple.CoreSimulator.SimRuntime.iOS-26-3</string>
    </dict>
    </plist>
    """
    FileManager.default.createFile(atPath: simDevices + "/device.plist", contents: plistContent.data(using: .utf8))
    // Create > 50MB dummy in data folder to exceed threshold
    FileManager.default.createFile(atPath: simDevices + "/data/sim.img", contents: Data(repeating: 1, count: 52 * 1024 * 1024))

    // Create > 1MB dummy in iOS DeviceSupport
    FileManager.default.createFile(atPath: iosDeviceSupport + "/Symbols.dyld", contents: Data(repeating: 2, count: 2 * 1024 * 1024))

    // Create Docker.raw
    FileManager.default.createFile(atPath: dockerDir + "/Docker.raw", contents: Data(repeating: 3, count: 1024))

    let items = ContainerAndToolchainCleaner.scanToolchainItems(home: tempHome)
    expectEq(items.count, 3, "detected 3 toolchain items")

    let simItem = items.first { $0.category == .xcodeSimulators }
    expect(simItem != nil, "found Xcode simulator item")
    expectEq(simItem?.name, "iPhone 17 Pro", "extracted simulator name")

    let devSupportItem = items.first { $0.category == .iosDeviceSupport }
    expect(devSupportItem != nil, "found iOS DeviceSupport item")

    let dockerItem = items.first { $0.category == .dockerVM }
    expect(dockerItem != nil, "found Docker.raw item")

    // Test cleaning DeviceSupport
    if let devItem = devSupportItem {
        let cleaned = (try? ContainerAndToolchainCleaner.cleanToolchainItem(devItem, home: tempHome)) ?? false
        expect(cleaned, "cleanToolchainItem for DeviceSupport succeeded")
        expect(!FileManager.default.fileExists(atPath: devItem.path), "DeviceSupport path removed")
    }

    // Test cleaning Simulator
    if let sItem = simItem {
        let cleaned = (try? ContainerAndToolchainCleaner.cleanToolchainItem(sItem, home: tempHome)) ?? false
        expect(cleaned, "cleanToolchainItem for Simulator succeeded")
        expect(!FileManager.default.fileExists(atPath: simDevices + "/data/sim.img"), "Simulator data removed")
    }
}
