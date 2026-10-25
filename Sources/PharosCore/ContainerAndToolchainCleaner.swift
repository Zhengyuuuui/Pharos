import Darwin
import Foundation

/// Scans and manages heavy container VM images and Xcode toolchain caches.
///
/// Developer environments on macOS frequently accumulate huge disk footprints:
/// - Docker Desktop VM raw disk (`~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw`)
/// - Colima VM virtual disk images (`~/.colima/*/diff_disk`)
/// - Xcode iOS DeviceSupport debug symbols (`~/Library/Developer/Xcode/iOS DeviceSupport`)
/// - Xcode CoreSimulator device data partitions (`~/Library/Developer/CoreSimulator/Devices/<UUID>/data`)
///
/// ContainerAndToolchainCleaner inspects these specialized stores, identifies device names
/// and runtime versions, and enables targeted disk reclamation.
public enum ContainerAndToolchainCleaner {

    public enum Category: String, Sendable, CaseIterable {
        case dockerVM = "Docker Virtual Disk"
        case colimaVM = "Colima Disk"
        case iosDeviceSupport = "iOS Device Support"
        case xcodeSimulators = "Xcode Simulator Data"

        public var localizedKey: String {
            switch self {
            case .dockerVM: return "toolchainDockerVM"
            case .colimaVM: return "toolchainColimaVM"
            case .iosDeviceSupport: return "toolchainIOSDeviceSupport"
            case .xcodeSimulators: return "toolchainSimulators"
            }
        }
    }

    public struct ToolchainItem: Identifiable, Hashable, Sendable {
        public var id: String { path }
        public let name: String
        public let category: Category
        public let path: String
        public let size: UInt64
        public let subtitle: String?
        public let lastModified: Date?
        public let canCleanDirectly: Bool

        public init(
            name: String,
            category: Category,
            path: String,
            size: UInt64,
            subtitle: String?,
            lastModified: Date?,
            canCleanDirectly: Bool = true
        ) {
            self.name = name
            self.category = category
            self.path = path
            self.size = size
            self.subtitle = subtitle
            self.lastModified = lastModified
            self.canCleanDirectly = canCleanDirectly
        }
    }

    // MARK: - Scanning

    /// Scans container VM images and Xcode simulator / device caches.
    public static func scanToolchainItems(home: String = NSHomeDirectory()) -> [ToolchainItem] {
        var items: [ToolchainItem] = []

        // 1. Docker Desktop VM Raw Disk
        let dockerRawPath = ((home as NSString).appendingPathComponent("Library/Containers/com.docker.docker/Data/vms/0/data") as NSString)
            .appendingPathComponent("Docker.raw")
        if FileManager.default.fileExists(atPath: dockerRawPath) {
            var st = stat()
            if lstat(dockerRawPath, &st) == 0 {
                let size = UInt64(st.st_size)
                let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
                items.append(ToolchainItem(
                    name: "Docker Desktop VM (Docker.raw)",
                    category: .dockerVM,
                    path: dockerRawPath,
                    size: size,
                    subtitle: "Docker Desktop 虚拟机磁盘镜像",
                    lastModified: mtime,
                    canCleanDirectly: true
                ))
            }
        }

        // 2. Colima VM Disks
        let colimaDir = (home as NSString).appendingPathComponent(".colima")
        if FileManager.default.fileExists(atPath: colimaDir),
           let profiles = try? FileManager.default.contentsOfDirectory(atPath: colimaDir) {
            for profile in profiles {
                if profile.hasPrefix(".") { continue }
                let diskPath = ((colimaDir as NSString).appendingPathComponent(profile) as NSString).appendingPathComponent("diff_disk")
                if FileManager.default.fileExists(atPath: diskPath) {
                    var st = stat()
                    if lstat(diskPath, &st) == 0 {
                        let size = UInt64(st.st_size)
                        let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
                        items.append(ToolchainItem(
                            name: "Colima VM (\(profile))",
                            category: .colimaVM,
                            path: diskPath,
                            size: size,
                            subtitle: "Colima 容器环境磁盘镜像",
                            lastModified: mtime,
                            canCleanDirectly: true
                        ))
                    }
                }
            }
        }

        // 3. Xcode iOS Device Support Symbols
        let deviceSupportDir = ((home as NSString).appendingPathComponent("Library/Developer/Xcode") as NSString)
            .appendingPathComponent("iOS DeviceSupport")
        if FileManager.default.fileExists(atPath: deviceSupportDir),
           let entries = try? FileManager.default.contentsOfDirectory(atPath: deviceSupportDir) {
            for entry in entries {
                if entry.hasPrefix(".") { continue }
                let fullPath = (deviceSupportDir as NSString).appendingPathComponent(entry)
                var st = stat()
                guard lstat(fullPath, &st) == 0, (st.st_mode & S_IFMT) == S_IFDIR else { continue }
                let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
                let (size, _) = PackageScanner.directorySize(at: fullPath, maxFiles: 10_000)
                guard size > 1024 * 1024 else { continue } // > 1MB

                items.append(ToolchainItem(
                    name: entry,
                    category: .iosDeviceSupport,
                    path: fullPath,
                    size: size,
                    subtitle: "真机调试符号缓存",
                    lastModified: mtime,
                    canCleanDirectly: true
                ))
            }
        }

        // 4. Xcode CoreSimulator Devices
        let simDevicesDir = ((home as NSString).appendingPathComponent("Library/Developer/CoreSimulator") as NSString)
            .appendingPathComponent("Devices")
        if FileManager.default.fileExists(atPath: simDevicesDir),
           let uuids = try? FileManager.default.contentsOfDirectory(atPath: simDevicesDir) {
            for uuid in uuids {
                if uuid.hasPrefix(".") { continue }
                let deviceDir = (simDevicesDir as NSString).appendingPathComponent(uuid)
                let plistPath = (deviceDir as NSString).appendingPathComponent("device.plist")
                guard FileManager.default.fileExists(atPath: plistPath) else { continue }

                var deviceName = uuid
                var runtimeStr: String? = nil
                if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                    if let n = plist["name"] as? String {
                        deviceName = n
                    }
                    if let r = plist["runtime"] as? String {
                        // "com.apple.CoreSimulator.SimRuntime.iOS-26-3" -> "iOS 26.3"
                        let trimmed = r.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
                            .replacingOccurrences(of: "-", with: " ")
                        runtimeStr = trimmed
                    }
                }

                // Check size of the data subfolder
                let dataDir = (deviceDir as NSString).appendingPathComponent("data")
                guard FileManager.default.fileExists(atPath: dataDir) else { continue }

                let (dataSize, _) = PackageScanner.directorySize(at: dataDir, maxFiles: 15_000)
                // Only report simulators taking > 50MB (skips brand new empty placeholders)
                if dataSize > 50 * 1024 * 1024 {
                    var st = stat()
                    let mtime = lstat(dataDir, &st) == 0 ? Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec)) : nil
                    let sub = runtimeStr != nil ? "\(runtimeStr!) (UUID: \(uuid.prefix(8))...)" : "UUID: \(uuid.prefix(8))..."
                    items.append(ToolchainItem(
                        name: deviceName,
                        category: .xcodeSimulators,
                        path: deviceDir,
                        size: dataSize,
                        subtitle: sub,
                        lastModified: mtime,
                        canCleanDirectly: true
                    ))
                }
            }
        }

        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Cleaning

    /// Cleans a toolchain item safely.
    @discardableResult
    public static func cleanToolchainItem(_ item: ToolchainItem, home: String = NSHomeDirectory()) throws -> Bool {
        let path = item.path

        switch item.category {
        case .dockerVM:
            let expectedPrefix = (home as NSString).appendingPathComponent("Library/Containers/com.docker.docker")
            guard path.hasPrefix(expectedPrefix), path.hasSuffix("Docker.raw") else { return false }
            guard FileManager.default.fileExists(atPath: path) else { return false }
            try FileManager.default.removeItem(atPath: path)
            return true

        case .colimaVM:
            let expectedPrefix = (home as NSString).appendingPathComponent(".colima")
            guard path.hasPrefix(expectedPrefix), path.hasSuffix("diff_disk") else { return false }
            guard FileManager.default.fileExists(atPath: path) else { return false }
            try FileManager.default.removeItem(atPath: path)
            return true

        case .iosDeviceSupport:
            let expectedPrefix = (home as NSString).appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport")
            guard path.hasPrefix(expectedPrefix + "/") else { return false }
            guard FileManager.default.fileExists(atPath: path) else { return false }
            try FileManager.default.removeItem(atPath: path)
            return true

        case .xcodeSimulators:
            let expectedPrefix = (home as NSString).appendingPathComponent("Library/Developer/CoreSimulator/Devices")
            guard path.hasPrefix(expectedPrefix + "/") else { return false }
            guard FileManager.default.fileExists(atPath: path) else { return false }

            // To safely reset simulator without breaking simulator database registration:
            // Wipe contents inside device/data folder, or delete device folder
            let dataDir = (path as NSString).appendingPathComponent("data")
            if FileManager.default.fileExists(atPath: dataDir) {
                try FileManager.default.removeItem(atPath: dataDir)
                // Recreate empty data directory with standard permissions
                try? FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
                return true
            } else {
                try FileManager.default.removeItem(atPath: path)
                return true
            }
        }
    }
}
