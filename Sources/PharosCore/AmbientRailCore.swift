import Darwin
import Foundation

// MARK: - Local Network & Debug Endpoints

public enum LocalNetwork {
    public struct LANInfo: Sendable, Hashable {
        public let ipv4: String
        public let interfaceName: String

        public init(ipv4: String, interfaceName: String) {
            self.ipv4 = ipv4
            self.interfaceName = interfaceName
        }
    }

    public struct WebDebugURL: Sendable, Hashable, Identifiable {
        public var id: String { "\(lanIP):\(port)" }
        public let port: UInt16
        public let lanIP: String
        public let isLoopbackOnly: Bool

        public init(port: UInt16, lanIP: String, isLoopbackOnly: Bool) {
            self.port = port
            self.lanIP = lanIP
            self.isLoopbackOnly = isLoopbackOnly
        }

        public var lanURL: String { "http://\(lanIP):\(port)" }
        public var localURL: String { "http://127.0.0.1:\(port)" }
    }

    public struct BackgroundDaemon: Sendable, Hashable, Identifiable {
        public var id: String { name }
        public let name: String
        public let port: UInt16
        public let icon: String
        public let isRunning: Bool

        public init(name: String, port: UInt16, icon: String, isRunning: Bool) {
            self.name = name
            self.port = port
            self.icon = icon
            self.isRunning = isRunning
        }
    }

    public static let commonWebPorts: Set<UInt16> = [
        80, 443, 3000, 3001, 3002, 4000, 4200, 4321, 5000, 5001, 5173, 5174,
        8000, 8008, 8080, 8081, 8888, 9000, 9001, 19000, 19006
    ]

    public static let daemonDefinitions: [(name: String, port: UInt16, icon: String)] = [
        ("PostgreSQL", 5432, "cylinder"),
        ("Redis", 6379, "bolt.horizontal"),
        ("MySQL", 3306, "cylinder.split.1x2"),
        ("MongoDB", 27017, "leaf"),
        ("Docker", 2375, "shippingbox"),
        ("Elastic", 9200, "magnifyingglass")
    ]

    /// Scans active local network interfaces (using Darwin getifaddrs) and returns the primary LAN IPv4.
    /// Prefers Wi-Fi/Ethernet (`en0`, `en1`) on standard private subnets (192.168.*, 10.*, 172.16-31.*).
    public static func activeLANIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        var candidates: [(name: String, ip: String, priority: Int)] = []

        while let curr = ptr {
            defer { ptr = curr.pointee.ifa_next }
            let flags = Int32(curr.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0,
                  (flags & IFF_RUNNING) != 0,
                  (flags & IFF_LOOPBACK) == 0,
                  let addr = curr.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            var addrIn = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            if inet_ntop(AF_INET, &addrIn.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                let ip = String(cString: buffer)
                let name = String(cString: curr.pointee.ifa_name)
                if !ip.hasPrefix("169.254.") && !ip.hasPrefix("127.") && !ip.isEmpty {
                    var prio = 0
                    if name.hasPrefix("en") { prio += 10 }
                    if name == "en0" { prio += 20 }
                    if ip.hasPrefix("192.168.") { prio += 5 }
                    else if ip.hasPrefix("10.") { prio += 4 }
                    else if ip.hasPrefix("172.") { prio += 3 }
                    candidates.append((name, ip, prio))
                }
            }
        }

        candidates.sort { $0.priority > $1.priority }
        return candidates.first?.ip
    }

    /// Evaluates which known background daemons are actively listening among current listening ports.
    public static func auditDaemons(listeningPorts: [ListeningPort]) -> [BackgroundDaemon] {
        let activePortNumbers = Set(listeningPorts.map(\.port))
        return daemonDefinitions.map { item in
            BackgroundDaemon(
                name: item.name,
                port: item.port,
                icon: item.icon,
                isRunning: activePortNumbers.contains(item.port)
            )
        }
    }

    /// Extracts web debug URLs from all listening ports given the current LAN IP.
    public static func resolveWebURLs(ports: [ListeningPort], lanIP: String?) -> [WebDebugURL] {
        let fallbackIP = lanIP ?? "127.0.0.1"
        return ports
            .filter { commonWebPorts.contains($0.port) || (!($0.port < 1024) && $0.port != 5432 && $0.port != 6379 && $0.port != 3306 && $0.port != 27017) }
            .map { WebDebugURL(port: $0.port, lanIP: fallbackIP, isLoopbackOnly: $0.loopbackOnly) }
    }
}

// MARK: - Project Tech Stack Detection

public enum TechStackBadge: String, CaseIterable, Sendable, Identifiable {
    case nextjs = "Next.js"
    case vite = "Vite"
    case react = "React"
    case vue = "Vue"
    case tailwind = "Tailwind"
    case typescript = "TypeScript"
    case rust = "Rust"
    case go = "Go"
    case swift = "Swift"
    case python = "Python"
    case node = "Node.js"
    case docker = "Docker"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .nextjs: return "triangle.fill"
        case .vite: return "bolt.fill"
        case .react: return "atom"
        case .vue: return "v.square.fill"
        case .tailwind: return "wind"
        case .typescript: return "t.square.fill"
        case .rust: return "gearshape.2.fill"
        case .go: return "shippingbox.fill"
        case .swift: return "swift"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .node: return "hexagon.fill"
        case .docker: return "shippingbox"
        }
    }
}

public enum ProjectTechStack {
    /// Detects tech stack signatures in the project root directory.
    /// Fast and bounded: only inspects presence of manifest files or first few KB of package.json.
    public static func detect(directory: String?) -> [TechStackBadge] {
        guard let dir = directory, !dir.isEmpty else { return [] }
        let fm = FileManager.default
        var results = Set<TechStackBadge>()

        let pkgSwift = (dir as NSString).appendingPathComponent("Package.swift")
        if fm.fileExists(atPath: pkgSwift) { results.insert(.swift) }

        let cargoToml = (dir as NSString).appendingPathComponent("Cargo.toml")
        if fm.fileExists(atPath: cargoToml) { results.insert(.rust) }

        let goMod = (dir as NSString).appendingPathComponent("go.mod")
        if fm.fileExists(atPath: goMod) { results.insert(.go) }

        let reqTxt = (dir as NSString).appendingPathComponent("requirements.txt")
        let pyproject = (dir as NSString).appendingPathComponent("pyproject.toml")
        let pipfile = (dir as NSString).appendingPathComponent("Pipfile")
        if fm.fileExists(atPath: reqTxt) || fm.fileExists(atPath: pyproject) || fm.fileExists(atPath: pipfile) {
            results.insert(.python)
        }

        let dockerfile = (dir as NSString).appendingPathComponent("Dockerfile")
        let compose1 = (dir as NSString).appendingPathComponent("docker-compose.yml")
        let compose2 = (dir as NSString).appendingPathComponent("docker-compose.yaml")
        let compose3 = (dir as NSString).appendingPathComponent("compose.yaml")
        if fm.fileExists(atPath: dockerfile) || fm.fileExists(atPath: compose1) || fm.fileExists(atPath: compose2) || fm.fileExists(atPath: compose3) {
            results.insert(.docker)
        }

        let tsConfig = (dir as NSString).appendingPathComponent("tsconfig.json")
        if fm.fileExists(atPath: tsConfig) { results.insert(.typescript) }

        let pkgJsonPath = (dir as NSString).appendingPathComponent("package.json")
        if fm.fileExists(atPath: pkgJsonPath) {
            results.insert(.node)
            if let handle = FileHandle(forReadingAtPath: pkgJsonPath) {
                defer { try? handle.close() }
                // Read up to 16KB for quick keyword matching
                let data = handle.readData(ofLength: 16384)
                if let str = String(data: data, encoding: .utf8)?.lowercased() {
                    if str.contains("\"next\"") || str.contains("next/") {
                        results.insert(.nextjs)
                        results.insert(.react)
                    }
                    if str.contains("\"vite\"") { results.insert(.vite) }
                    if str.contains("\"react\"") { results.insert(.react) }
                    if str.contains("\"vue\"") || str.contains("\"nuxt\"") { results.insert(.vue) }
                    if str.contains("tailwindcss") { results.insert(.tailwind) }
                    if str.contains("typescript") { results.insert(.typescript) }
                }
            }
        }

        return TechStackBadge.allCases.filter { results.contains($0) }
    }
}

// MARK: - Memory Attribution Domains

public struct MemoryDomainBreakdown: Sendable, Hashable {
    public let devBytes: UInt64
    public let browserBytes: UInt64
    public let otherBytes: UInt64
    public let totalBytes: UInt64

    public init(devBytes: UInt64, browserBytes: UInt64, otherBytes: UInt64, totalBytes: UInt64) {
        self.devBytes = devBytes
        self.browserBytes = browserBytes
        self.otherBytes = otherBytes
        self.totalBytes = totalBytes
    }

    public var devFraction: Double { totalBytes > 0 ? Double(devBytes) / Double(totalBytes) : 0 }
    public var browserFraction: Double { totalBytes > 0 ? Double(browserBytes) / Double(totalBytes) : 0 }
    public var otherFraction: Double { totalBytes > 0 ? Double(otherBytes) / Double(totalBytes) : 0 }
}

public enum MemoryAttribution {
    private static let devKeywords = [
        "xcode", "cursor", "windsurf", "code", "vscode", "terminal", "iterm", "ghostty",
        "warp", "node", "python", "go", "cargo", "rustc", "swift", "docker", "colima",
        "lldb", "git", "npm", "pnpm", "bun", "yarn", "simulator", "java", "gradle"
    ]
    private static let browserKeywords = [
        "chrome", "safari", "edge", "arc", "brave", "firefox", "chromium", "opera", "webkit"
    ]

    public static func calculate(apps: [AppUsage]) -> MemoryDomainBreakdown {
        var dev: UInt64 = 0
        var browser: UInt64 = 0
        var other: UInt64 = 0

        for a in apps {
            let lower = a.name.lowercased()
            if browserKeywords.contains(where: { lower.contains($0) }) {
                browser += a.memoryBytes
            } else if devKeywords.contains(where: { lower.contains($0) }) {
                dev += a.memoryBytes
            } else {
                other += a.memoryBytes
            }
        }
        let total = dev + browser + other
        return MemoryDomainBreakdown(devBytes: dev, browserBytes: browser, otherBytes: other, totalBytes: total)
    }
}

// MARK: - Popover Height Estimation

public enum PopoverHeightEstimator {
    public static func estimatedHeight(blocks: [PopoverBlock]) -> Int {
        var h = 50 // header + footer padding
        for b in blocks {
            switch b {
            case .memory: h += 90
            case .disk: h += 75
            case .thermals: h += 75
            case .battery: h += 70
            case .devProjects: h += 95
            case .topApps: h += 110
            case .projects: h += 130
            case .browsers: h += 85
            case .favorites: h += 80
            }
        }
        return h
    }
}

// MARK: - Thermal Headroom

public enum ThermalHeadroom {
    public static func calculate(peakTemp: Double) -> (headroom: Double, isThrottling: Bool) {
        let maxLimit = 100.0
        let headroom = max(0.0, maxLimit - peakTemp)
        return (headroom, peakTemp >= 95.0)
    }
}

// MARK: - Disk Runway Health

public enum DiskRunwayLevel: String, Sendable, Hashable {
    case healthy
    case warning
    case critical
}

public enum DiskRunway {
    public static func evaluate(usedFraction: Double) -> (availablePercent: Double, level: DiskRunwayLevel) {
        let availFraction = max(0.0, 1.0 - usedFraction)
        let percent = availFraction * 100.0
        let level: DiskRunwayLevel
        if percent >= 20.0 {
            level = .healthy
        } else if percent >= 10.0 {
            level = .warning
        } else {
            level = .critical
        }
        return (percent, level)
    }
}
