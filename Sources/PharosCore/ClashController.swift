import Darwin
import Foundation

/// Core network controller for communicating with Clash and Mihomo (Clash Meta) engines.
/// Supports both Unix Domain Sockets (used by Mihomo Party) and HTTP REST APIs (used by Clash Verge, ClashX, etc.).
public enum ClashController {

    /// Connection endpoint for an external controller.
    public struct ControllerEndpoint: Sendable, Equatable {
        public enum Channel: Sendable, Equatable {
            case unixSocket(path: String)
            case http(host: String, port: Int)
        }

        public let channel: Channel
        public let secret: String?
        public let clientKind: ClashClientKind
        public let configPath: String?

        public init(channel: Channel, secret: String? = nil, clientKind: ClashClientKind = .genericMihomo, configPath: String? = nil) {
            self.channel = channel
            self.secret = secret
            self.clientKind = clientKind
            self.configPath = configPath
        }

        public var displayString: String {
            switch channel {
            case .unixSocket(let path):
                return "unix://\(path)"
            case .http(let host, let port):
                return "http://\(host):\(port)"
            }
        }
    }

    // MARK: - Active Endpoint Detection

    /// Extracts command-line options such as -ext-ctl-unix, -ext-ctl, -d, -f from process arguments.
    public static func parseProcessArguments(_ args: [String]) -> (sockPath: String?, extCtl: String?, workDir: String?, configPath: String?) {
        var sockPath: String?
        var extCtl: String?
        var workDir: String?
        var configPath: String?

        for i in 0..<args.count {
            let arg = args[i]
            if arg == "-ext-ctl-unix", i + 1 < args.count {
                sockPath = args[i + 1]
            } else if arg.hasPrefix("-ext-ctl-unix=") {
                sockPath = String(arg.dropFirst("-ext-ctl-unix=".count))
            } else if arg == "-ext-ctl", i + 1 < args.count {
                extCtl = args[i + 1]
            } else if arg.hasPrefix("-ext-ctl=") {
                extCtl = String(arg.dropFirst("-ext-ctl=".count))
            } else if arg == "-d", i + 1 < args.count {
                workDir = args[i + 1]
            } else if arg.hasPrefix("-d=") {
                workDir = String(arg.dropFirst("-d=".count))
            } else if arg == "-f", i + 1 < args.count {
                configPath = args[i + 1]
            } else if arg.hasPrefix("-f=") {
                configPath = String(arg.dropFirst("-f=".count))
            }
        }
        return (sockPath, extCtl, workDir, configPath)
    }

    /// Probes running processes for active mihomo / clash-meta / clash / sing-box daemons
    /// and extracts controller endpoint, secret, and config path directly from CLI arguments.
    public static func detectFromRunningProcesses(processes: [ProcessSnapshot]? = nil) -> ControllerEndpoint? {
        let procs = processes ?? ProcessScanner.scan()
        for p in procs {
            let name = p.name.lowercased()
            let exe = (p.executablePath ?? "").lowercased()
            let isProxyCore = name.contains("mihomo") || name.contains("clash") || name.contains("sing-box") ||
                              exe.contains("mihomo") || exe.contains("clash") || exe.contains("sing-box")
            guard isProxyCore else { continue }

            var (sockPath, extCtl, workDir, configPath) = parseProcessArguments(p.arguments)

            if configPath == nil, let w = workDir {
                let candidate = w + "/config.yaml"
                if FileManager.default.fileExists(atPath: candidate) {
                    configPath = candidate
                }
            }

            var secret: String?
            if let cp = configPath, let content = try? String(contentsOfFile: cp, encoding: .utf8) {
                secret = parseYamlString(named: "secret", in: content) ?? parseYamlString(named: "verge_clash_secret", in: content)
                if extCtl == nil {
                    extCtl = parseYamlString(named: "external-controller", in: content)
                }
            }

            let kind: ClashClientKind = {
                let combined = (exe + " " + p.arguments.joined(separator: " ")).lowercased()
                if combined.contains("mihomo-party") || combined.contains("clash party") { return .mihomoParty }
                if combined.contains("clash-verge") { return .clashVerge }
                if combined.contains("nyanpasu") { return .clashNyanpasu }
                if combined.contains("flclash") { return .flclash }
                if combined.contains("sing-box") { return .singBox }
                if combined.contains("clashx") { return .clashX }
                return .genericMihomo
            }()

            // Priority 1: Unix Socket
            if let sock = sockPath, canConnectUnixSocket(path: sock) {
                return ControllerEndpoint(channel: .unixSocket(path: sock), secret: secret, clientKind: kind, configPath: configPath)
            }

            // Priority 2: TCP Host/Port
            if let ctl = extCtl {
                let portStr = ctl.components(separatedBy: ":").last ?? "9090"
                if let port = Int(portStr) {
                    let host = ctl.contains(":") ? ctl.components(separatedBy: ":").first! : "127.0.0.1"
                    let effHost = (host.isEmpty || host == "0.0.0.0" || host == "::") ? "127.0.0.1" : host
                    if canConnectTCP(port: port, host: effHost) {
                        return ControllerEndpoint(channel: .http(host: effHost, port: port), secret: secret, clientKind: kind, configPath: configPath)
                    }
                }
            }
        }
        return nil
    }

    /// Automatically scans and returns the active Clash/Mihomo controller endpoint.
    public static func detectActiveEndpoint() -> ControllerEndpoint? {
        // 0. Probing Running Processes (Priority 0: Direct CLI arguments and active daemon inspection)
        if let procEndpoint = detectFromRunningProcesses() {
            return procEndpoint
        }

        // 1. Probing Unix Domain Sockets (Priority 1: Mihomo Party / Clash Party)
        if let partySocket = findActiveMihomoPartySocket() {
            let workDir = NSHomeDirectory() + "/Library/Application Support/mihomo-party/work/config.yaml"
            let cfg = FileManager.default.fileExists(atPath: workDir) ? workDir : nil
            return ControllerEndpoint(channel: .unixSocket(path: partySocket), secret: nil, clientKind: .mihomoParty, configPath: cfg)
        }

        // 2. Probing Verge Unix Sockets
        if let vergeSocket = findActiveVergeSocket() {
            return ControllerEndpoint(channel: .unixSocket(path: vergeSocket), secret: nil, clientKind: .clashVerge)
        }

        // 3. Probing Known Configuration Files for Port & Secret
        let home = NSHomeDirectory()

        // 3.1 Clash Verge Rev
        let vergeDirs = [
            home + "/.config/clash-verge-rev",
            home + "/Library/Application Support/clash-verge-rev",
            home + "/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
        ]
        let vergeFilenames = ["verge.yaml", "clash-meta.yaml", "config.yaml"]
        for dir in vergeDirs {
            for file in vergeFilenames {
                let path = dir + "/" + file
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    let port = parseYamlInt(named: "verge_external_controller_port", in: content) ?? parseYamlPort(in: content) ?? 9097
                    let secret = parseYamlString(named: "verge_clash_secret", in: content) ?? parseYamlString(named: "secret", in: content)
                    if canConnectTCP(port: port) {
                        return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .clashVerge, configPath: path)
                    }
                }
            }
        }

        // 3.2 Clash Nyanpasu
        let nyanpasuDirs = [
            home + "/.config/clash-nyanpasu",
            home + "/Library/Application Support/mo.yanpasu.clash-nyanpasu"
        ]
        let nyanpasuFilenames = ["config.yaml", "nyanpasu.yaml"]
        for dir in nyanpasuDirs {
            for file in nyanpasuFilenames {
                let path = dir + "/" + file
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    let port = parseYamlPort(in: content) ?? 9090
                    let secret = parseYamlString(named: "secret", in: content)
                    if canConnectTCP(port: port) {
                        return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .clashNyanpasu, configPath: path)
                    }
                }
            }
        }

        // 3.3 ClashX.Meta / ClashX
        let clashXPaths = [
            home + "/.config/clash.meta/config.yaml",
            home + "/.config/clash/config.yaml",
            home + "/Library/Application Support/com.metacubex.ClashX.Meta/config.yaml",
            home + "/Library/Application Support/com.west2online.ClashX/config.yaml"
        ]
        for path in clashXPaths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let port = parseYamlPort(in: content) ?? 9090
                let secret = parseYamlString(named: "secret", in: content)
                if canConnectTCP(port: port) {
                    return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .clashX, configPath: path)
                }
            }
        }

        // 3.4 Sing-Box
        let singBoxPaths = [
            home + "/.config/sing-box/config.json",
            home + "/Library/Application Support/sing-box/config.json",
            home + "/Library/Application Support/io.nekohasekai.sagernet/config.json"
        ]
        for path in singBoxPaths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8),
               let parsed = parseSingBoxConfig(content: content) {
                if canConnectTCP(port: parsed.port) {
                    return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: parsed.port), secret: parsed.secret, clientKind: .singBox, configPath: path)
                }
            }
        }

        // 3.5 Flclash
        let flclashPaths = [
            home + "/.config/flclash/config.yaml",
            home + "/Library/Application Support/com.flclash.flclash/config.yaml"
        ]
        for path in flclashPaths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let port = parseYamlPort(in: content) ?? 9090
                let secret = parseYamlString(named: "secret", in: content)
                if canConnectTCP(port: port) {
                    return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .flclash, configPath: path)
                }
            }
        }

        // 3.6 GUI.for.Clash
        let guiDirs = [
            home + "/.config/GUI.for.Clash",
            home + "/Library/Application Support/GUI.for.Clash"
        ]
        for dir in guiDirs {
            let path = dir + "/config.yaml"
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let port = parseYamlPort(in: content) ?? 9090
                let secret = parseYamlString(named: "secret", in: content)
                if canConnectTCP(port: port) {
                    return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .genericMihomo, configPath: path)
                }
            }
        }

        // 3.7 Generic Mihomo Core CLI / Homebrew
        let genericPaths = [
            home + "/.config/mihomo/config.yaml",
            "/opt/homebrew/etc/mihomo/config.yaml",
            "/usr/local/etc/mihomo/config.yaml"
        ]
        for path in genericPaths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let port = parseYamlPort(in: content) ?? 9090
                let secret = parseYamlString(named: "secret", in: content)
                if canConnectTCP(port: port) {
                    return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .genericMihomo, configPath: path)
                }
            }
        }

        // 4. Default TCP Ports Probing (9097 Verge, 9090 Standard)
        if canConnectTCP(port: 9097) {
            return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: 9097), secret: nil, clientKind: .clashVerge)
        }
        if canConnectTCP(port: 9090) {
            let kind = detectClientFromRunningApps() ?? .genericMihomo
            return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: 9090), secret: nil, clientKind: kind)
        }

        return nil
    }

    // MARK: - High-level API Calls

    /// Fetches the current core configuration: routing mode, proxy ports, TUN status.
    public static func fetchConfig(
        endpoint: ControllerEndpoint
    ) async throws -> (mode: ClashRoutingMode, mixedPort: Int, socksPort: Int, httpPort: Int, isTun: Bool) {
        let (statusCode, data) = try await sendRequest(endpoint: endpoint, method: "GET", uri: "/configs")
        guard statusCode == 200 else {
            throw NSError(domain: "ClashController", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode)"])
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw NSError(domain: "ClashController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }

        let modeStr = json["mode"] as? String ?? "rule"
        let mode = ClashRoutingMode(rawValue: modeStr) ?? .rule
        let mixedPort = json["mixed-port"] as? Int ?? 7890
        let socksPort = json["socks-port"] as? Int ?? 7891
        let httpPort = json["port"] as? Int ?? 0
        let tunMap = json["tun"] as? [String: Any]
        let isTun = tunMap?["enable"] as? Bool ?? false

        return (mode, mixedPort, socksPort, httpPort, isTun)
    }

    /// Millisecond-level hot mode switching (rule / direct / global).
    public static func switchMode(_ mode: ClashRoutingMode, endpoint: ControllerEndpoint) async throws -> Bool {
        let payload = "{\"mode\":\"\(mode.rawValue)\"}".data(using: .utf8)
        let (statusCode, _) = try await sendRequest(endpoint: endpoint, method: "PATCH", uri: "/configs", body: payload)
        return statusCode == 200 || statusCode == 204
    }

    /// Closes all active connections so new traffic migrates immediately.
    public static func closeAllConnections(endpoint: ControllerEndpoint) async throws -> Bool {
        let (statusCode, _) = try await sendRequest(endpoint: endpoint, method: "DELETE", uri: "/connections")
        return statusCode == 200 || statusCode == 204
    }

    /// Fetches connection statistics: active count and cumulative byte totals.
    public static func fetchConnections(
        endpoint: ControllerEndpoint
    ) async throws -> (activeCount: Int, totalUpload: UInt64, totalDownload: UInt64) {
        let (statusCode, data) = try await sendRequest(endpoint: endpoint, method: "GET", uri: "/connections")
        guard statusCode == 200 else {
            throw NSError(domain: "ClashController", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode)"])
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return (0, 0, 0)
        }

        let connections = json["connections"] as? [Any] ?? []
        let uploadTotal = (json["uploadTotal"] as? NSNumber)?.uint64Value ?? 0
        let downloadTotal = (json["downloadTotal"] as? NSNumber)?.uint64Value ?? 0

        return (connections.count, uploadTotal, downloadTotal)
    }

    /// Takes a complete snapshot with calculated upload/download speed based on elapsed time.
    public static func fetchFullSnapshot(
        endpoint: ControllerEndpoint,
        previousSnapshot: ClashStatusSnapshot? = nil,
        elapsedSeconds: Double = 2.0
    ) async -> ClashStatusSnapshot {
        do {
            async let configTask = fetchConfig(endpoint: endpoint)
            async let connTask = fetchConnections(endpoint: endpoint)

            let config = try await configTask
            let (connCount, totalUp, totalDown) = (try? await connTask) ?? (0, 0, 0)

            let dt = max(elapsedSeconds, 0.5)
            var upSpeed: UInt64 = 0
            var downSpeed: UInt64 = 0

            if let prev = previousSnapshot, prev.isRunning, totalUp >= prev.totalUploadBytes, totalDown >= prev.totalDownloadBytes {
                upSpeed = UInt64(Double(totalUp - prev.totalUploadBytes) / dt)
                downSpeed = UInt64(Double(totalDown - prev.totalDownloadBytes) / dt)
            }

            return ClashStatusSnapshot(
                isRunning: true,
                clientKind: endpoint.clientKind,
                mode: config.mode,
                mixedPort: config.mixedPort,
                socksPort: config.socksPort,
                httpPort: config.httpPort,
                isTunEnabled: config.isTun,
                uploadBytesPerSec: upSpeed,
                downloadBytesPerSec: downSpeed,
                totalUploadBytes: totalUp,
                totalDownloadBytes: totalDown,
                activeConnectionCount: connCount,
                controllerEndpoint: endpoint.displayString
            )
        } catch {
            return ClashStatusSnapshot(
                isRunning: false,
                clientKind: endpoint.clientKind,
                controllerEndpoint: endpoint.displayString
            )
        }
    }

    // MARK: - Proxy Node Management & Hot Switching

    /// Fetches the list of all available outbound proxy leaf nodes from the daemon.
    public static func fetchProxies(
        endpoint: ControllerEndpoint
    ) async throws -> [MihomoProxyNode] {
        let (statusCode, data) = try await sendRequest(endpoint: endpoint, method: "GET", uri: "/proxies")
        guard statusCode == 200 else {
            throw NSError(domain: "ClashController", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode)"])
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let proxiesDict = json["proxies"] as? [String: [String: Any]] else {
            throw NSError(domain: "ClashController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid /proxies JSON response"])
        }

        var nodes: [MihomoProxyNode] = []
        let nonLeafTypes: Set<String> = [
            "selector", "urltest", "fallback", "loadbalance", "relay",
            "compatible", "reject", "rejectdrop", "pass"
        ]
        let excludedNames: Set<String> = [
            "global", "direct", "reject", "reject-drop", "pass", "compatible"
        ]

        for (name, dict) in proxiesDict {
            let typeStr = dict["type"] as? String ?? ""
            let typeLower = typeStr.lowercased()
            let nameLower = name.lowercased()

            if nonLeafTypes.contains(typeLower) || excludedNames.contains(nameLower) {
                continue
            }

            let alive = dict["alive"] as? Bool ?? true
            var lastDelay: Int? = nil
            if let history = dict["history"] as? [[String: Any]], let last = history.last {
                lastDelay = last["delay"] as? Int
            } else if let extra = dict["extra"] as? [String: Any] {
                for (_, testVal) in extra {
                    if let tDict = testVal as? [String: Any],
                       let tHistory = tDict["history"] as? [[String: Any]],
                       let last = tHistory.last,
                       let d = last["delay"] as? Int, d > 0 {
                        lastDelay = d
                        break
                    }
                }
            }

            nodes.append(MihomoProxyNode(name: name, type: typeStr, delay: lastDelay, alive: alive))
        }

        return nodes.sorted { a, b in
            a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    /// Dynamically mounts an instance-specific listener and selector group into the Mihomo configuration.
    public static func ensureListenerAndGroup(
        port: Int,
        groupName: String,
        availableNodeNames: [String],
        configPath: String?,
        endpoint: ControllerEndpoint
    ) async throws {
        guard let cfgPath = configPath, FileManager.default.isWritableFile(atPath: cfgPath) else {
            return
        }

        guard var content = try? String(contentsOfFile: cfgPath, encoding: .utf8) else {
            return
        }

        var modified = false

        // 1. Check or inject listener
        let listenerKey = "port: \(port)"
        if !content.contains(listenerKey) {
            let listenerBlock = """

listeners:
  - name: Pharos-\(port)
    type: mixed
    port: \(port)
    listen: 127.0.0.1
    proxy: \(groupName)
"""
            if content.contains("listeners:") {
                let insertion = """
  - name: Pharos-\(port)
    type: mixed
    port: \(port)
    listen: 127.0.0.1
    proxy: \(groupName)

"""
                content = content.replacingOccurrences(of: "listeners:\n", with: "listeners:\n" + insertion)
            } else {
                content += listenerBlock
            }
            modified = true
        }

        // 2. Check or inject proxy group
        let groupKey = "name: \(groupName)"
        if !content.contains(groupKey) {
            var proxiesList = "      - DIRECT\n"
            for node in availableNodeNames.prefix(50) {
                let cleanNode = node.replacingOccurrences(of: "\"", with: "\\\"")
                proxiesList += "      - \"\(cleanNode)\"\n"
            }

            let groupBlock = """

proxy-groups:
  - name: \(groupName)
    type: select
    proxies:
\(proxiesList)
"""
            if content.contains("proxy-groups:") {
                let insertion = """
  - name: \(groupName)
    type: select
    proxies:
\(proxiesList)
"""
                content = content.replacingOccurrences(of: "proxy-groups:\n", with: "proxy-groups:\n" + insertion)
            } else {
                content += groupBlock
            }
            modified = true
        }

        if modified {
            try content.write(toFile: cfgPath, atomically: true, encoding: .utf8)
            // Hot reload daemon configuration
            let payload = try JSONSerialization.data(withJSONObject: ["path": cfgPath])
            _ = try await sendRequest(endpoint: endpoint, method: "PUT", uri: "/configs?force=true", body: payload)
        }
    }

    /// Millisecond-level hot node switching for a specific proxy group.
    public static func switchGroupProxy(
        groupName: String,
        nodeName: String,
        endpoint: ControllerEndpoint
    ) async throws -> Bool {
        guard let encodedGroup = groupName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return false
        }
        let payload = try JSONSerialization.data(withJSONObject: ["name": nodeName])
        let (code, _) = try await sendRequest(
            endpoint: endpoint,
            method: "PUT",
            uri: "/proxies/\(encodedGroup)",
            body: payload
        )
        return code == 200 || code == 204
    }

    // MARK: - Low-level Request Dispatcher

    /// Sends a request to either Unix Domain Socket or standard HTTP loopback port.
    public static func sendRequest(
        endpoint: ControllerEndpoint,
        method: String,
        uri: String,
        body: Data? = nil
    ) async throws -> (statusCode: Int, data: Data) {
        switch endpoint.channel {
        case .unixSocket(let path):
            return try await sendUnixSocketRequest(path: path, method: method, uri: uri, body: body)
        case .http(let host, let port):
            return try await sendHttpRequest(host: host, port: port, secret: endpoint.secret, method: method, uri: uri, body: body)
        }
    }

    // MARK: - Unix Domain Socket HTTP Client (Pure Darwin POSIX)

    private static func sendUnixSocketRequest(
        path: String,
        method: String,
        uri: String,
        body: Data?
    ) async throws -> (statusCode: Int, data: Data) {
        try await Task.detached(priority: .utility) {
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else {
                throw NSError(domain: "ClashController", code: -1, userInfo: [NSLocalizedDescriptionKey: "socket creation failed"])
            }
            defer { close(fd) }

            var tv = timeval(tv_sec: 2, tv_usec: 0)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
            var on: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            let pathBytes = Array(path.utf8)
            let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
            guard pathBytes.count < maxLen else {
                throw NSError(domain: "ClashController", code: -1, userInfo: [NSLocalizedDescriptionKey: "socket path too long"])
            }
            withUnsafeMutableBytes(of: &addr.sun_path) { buf in
                for (i, b) in pathBytes.enumerated() { buf[i] = b }
                buf[pathBytes.count] = 0
            }

            let connected = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard connected == 0 else {
                throw NSError(domain: "ClashController", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "connect failed: \(errno)"])
            }

            // Build HTTP 1.1 request
            var req = "\(method) \(uri) HTTP/1.1\r\n"
            req += "Host: localhost\r\n"
            req += "Connection: close\r\n"
            req += "User-Agent: Pharos\r\n"
            if let body = body {
                req += "Content-Type: application/json\r\n"
                req += "Content-Length: \(body.count)\r\n"
            } else {
                req += "Content-Length: 0\r\n"
            }
            req += "\r\n"

            var reqData = Data(req.utf8)
            if let body = body { reqData.append(body) }

            let sent = reqData.withUnsafeBytes { ptr in
                write(fd, ptr.baseAddress, ptr.count)
            }
            guard sent == reqData.count else {
                throw NSError(domain: "ClashController", code: -1, userInfo: [NSLocalizedDescriptionKey: "write error"])
            }

            // Read response
            var responseData = Data()
            var chunk = [UInt8](repeating: 0, count: 4096)
            while true {
                let n = chunk.withUnsafeMutableBytes { ptr in
                    read(fd, ptr.baseAddress, ptr.count)
                }
                if n <= 0 { break }
                responseData.append(contentsOf: chunk.prefix(n))
                if responseData.count > 8 * 1024 * 1024 { break } // 8MB safety limit
            }

            return try parseHttpResponse(data: responseData)
        }.value
    }

    /// Parses a raw HTTP/1.1 response buffer with chunked decoding support.
    public static func parseHttpResponse(data: Data) throws -> (statusCode: Int, data: Data) {
        let separatorCRLF = Data("\r\n\r\n".utf8)
        let separatorLF = Data("\n\n".utf8)

        var headerData: Data
        var bodyData: Data

        if let range = data.range(of: separatorCRLF) {
            headerData = data.subdata(in: 0..<range.lowerBound)
            bodyData = data.subdata(in: range.upperBound..<data.count)
        } else if let range = data.range(of: separatorLF) {
            headerData = data.subdata(in: 0..<range.lowerBound)
            bodyData = data.subdata(in: range.upperBound..<data.count)
        } else {
            throw NSError(domain: "ClashController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Malformed HTTP response"])
        }

        guard let headerStr = String(data: headerData, encoding: .utf8),
              let statusLine = headerStr.components(separatedBy: "\r\n").first ?? headerStr.components(separatedBy: "\n").first else {
            throw NSError(domain: "ClashController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid status line"])
        }

        let parts = statusLine.components(separatedBy: " ")
        guard parts.count >= 2, let code = Int(parts[1]) else {
            throw NSError(domain: "ClashController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP code in \(statusLine)"])
        }

        let isChunked = headerStr.localizedCaseInsensitiveContains("Transfer-Encoding: chunked")
        let finalBody = isChunked ? decodeChunkedBody(data: bodyData) : bodyData

        return (code, finalBody)
    }

    /// Decodes an HTTP/1.1 chunked transfer-encoded payload.
    public static func decodeChunkedBody(data: Data) -> Data {
        var result = Data()
        var offset = 0
        let crlf = Data("\r\n".utf8)

        while offset < data.count {
            guard let range = data.range(of: crlf, in: offset..<data.count) else { break }
            let lineData = data.subdata(in: offset..<range.lowerBound)
            offset = range.upperBound

            guard let lineStr = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !lineStr.isEmpty else { continue }

            let sizeStr = lineStr.components(separatedBy: ";")[0].trimmingCharacters(in: .whitespaces)
            guard let chunkSize = Int(sizeStr, radix: 16) else { break }
            if chunkSize == 0 { break }

            let chunkEnd = offset + chunkSize
            guard chunkEnd <= data.count else { break }
            result.append(data.subdata(in: offset..<chunkEnd))
            offset = chunkEnd

            if offset + 2 <= data.count && data.subdata(in: offset..<offset + 2) == crlf {
                offset += 2
            }
        }
        return result.isEmpty ? data : result
    }

    // MARK: - HTTP TCP Client (URLSession)

    private static func sendHttpRequest(
        host: String,
        port: Int,
        secret: String?,
        method: String,
        uri: String,
        body: Data?
    ) async throws -> (statusCode: Int, data: Data) {
        guard let url = URL(string: "http://\(host):\(port)\(uri)") else {
            throw NSError(domain: "ClashController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var req = URLRequest(url: url, timeoutInterval: 2.0)
        req.httpMethod = method
        if let s = secret, !s.isEmpty {
            req.setValue("Bearer \(s)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 2.0
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: req)
        let httpResponse = response as? HTTPURLResponse
        let code = httpResponse?.statusCode ?? 200
        return (code, data)
    }

    // MARK: - Detection Helpers

    private static func findActiveMihomoPartySocket() -> String? {
        let fileManager = FileManager.default
        let tmpDirs = ["/private/tmp", "/tmp"]
        var candidates: [String] = []

        for dir in tmpDirs {
            guard let files = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            for f in files where f.hasPrefix("mihomo-party-") && f.hasSuffix(".sock") {
                candidates.append(dir + "/" + f)
            }
        }

        // Sort by modification time descending
        let sorted = candidates.sorted { a, b in
            let dateA = (try? fileManager.attributesOfItem(atPath: a))?[.modificationDate] as? Date ?? Date.distantPast
            let dateB = (try? fileManager.attributesOfItem(atPath: b))?[.modificationDate] as? Date ?? Date.distantPast
            return dateA > dateB
        }

        for path in sorted {
            if canConnectUnixSocket(path: path) {
                return path
            }
        }
        return nil
    }

    private static func findActiveVergeSocket() -> String? {
        let fileManager = FileManager.default
        for dir in ["/private/tmp", "/tmp"] {
            guard let files = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            for f in files where f.hasPrefix("verge-") && f.hasSuffix(".sock") {
                let path = dir + "/" + f
                if canConnectUnixSocket(path: path) { return path }
            }
        }
        return nil
    }

    public static func canConnectUnixSocket(path: String) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var tv = timeval(tv_sec: 0, tv_usec: 200_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: addr.sun_path) else { return false }
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            for (i, b) in bytes.enumerated() { buf[i] = b }
            buf[bytes.count] = 0
        }

        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        return res == 0
    }

    public static func canConnectTCP(port: Int, host: String = "127.0.0.1") -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var tv = timeval(tv_sec: 0, tv_usec: 200_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)

        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return res == 0
    }

    private static func detectClientFromRunningApps() -> ClashClientKind? {
        let home = NSHomeDirectory()
        let installed = [
            "/Applications/Clash Verge Rev.app": ClashClientKind.clashVerge,
            "/Applications/Clash Verge.app": ClashClientKind.clashVerge,
            home + "/Applications/Clash Verge Rev.app": ClashClientKind.clashVerge,
            "/Applications/Clash Party.app": ClashClientKind.mihomoParty,
            "/Applications/Mihomo Party.app": ClashClientKind.mihomoParty,
            home + "/Applications/Mihomo Party.app": ClashClientKind.mihomoParty,
            "/Applications/Clash Nyanpasu.app": ClashClientKind.clashNyanpasu,
            home + "/Applications/Clash Nyanpasu.app": ClashClientKind.clashNyanpasu,
            "/Applications/ClashX.Meta.app": ClashClientKind.clashX,
            "/Applications/ClashX.app": ClashClientKind.clashX,
            home + "/Applications/ClashX.Meta.app": ClashClientKind.clashX,
            "/Applications/Flclash.app": ClashClientKind.flclash,
            home + "/Applications/Flclash.app": ClashClientKind.flclash,
            "/Applications/Sing-Box.app": ClashClientKind.singBox,
            "/Applications/sing-box.app": ClashClientKind.singBox,
            home + "/Applications/Sing-Box.app": ClashClientKind.singBox,
            home + "/Applications/sing-box.app": ClashClientKind.singBox
        ]
        for (path, kind) in installed {
            if FileManager.default.fileExists(atPath: path) { return kind }
        }
        return nil
    }

    // MARK: - Light JSON & YAML Parser Helpers

    /// Parses Sing-Box's `experimental.clash_api` configuration block from config.json.
    public static func parseSingBoxConfig(content: String) -> (port: Int, secret: String?)? {
        guard let data = content.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        let experimental = json["experimental"] as? [String: Any]
        guard let api = (experimental?["clash_api"] as? [String: Any]) ?? (json["clash_api"] as? [String: Any]) else {
            return nil
        }

        let controllerStr = api["external_controller"] as? String ?? "127.0.0.1:9090"
        let portStr = controllerStr.components(separatedBy: ":").last ?? "9090"
        let port = Int(portStr) ?? 9090
        let secret = api["secret"] as? String
        return (port, secret)
    }

    /// Parses an endpoint string (e.g. "http://127.0.0.1:9097", "127.0.0.1:9090", "unix:///tmp/mihomo.sock") into a typed ControllerEndpoint.
    public static func parseEndpoint(
        from string: String,
        secret: String? = nil,
        clientKind: ClashClientKind = .custom,
        configPath: String? = nil
    ) -> ControllerEndpoint? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cleanSecret = secret?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effSecret = (cleanSecret?.isEmpty == false) ? cleanSecret : nil
        let effConfig = (configPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? configPath : nil

        if trimmed.hasPrefix("unix://") {
            let path = String(trimmed.dropFirst(7))
            return ControllerEndpoint(channel: .unixSocket(path: path), secret: effSecret, clientKind: clientKind, configPath: effConfig)
        } else if trimmed.hasPrefix("/") {
            return ControllerEndpoint(channel: .unixSocket(path: trimmed), secret: effSecret, clientKind: clientKind, configPath: effConfig)
        }

        var hostPort = trimmed
        if hostPort.hasPrefix("http://") {
            hostPort = String(hostPort.dropFirst(7))
        } else if hostPort.hasPrefix("https://") {
            hostPort = String(hostPort.dropFirst(8))
        }
        if let slashIdx = hostPort.firstIndex(of: "/") {
            hostPort = String(hostPort[..<slashIdx])
        }

        let parts = hostPort.components(separatedBy: ":")
        let host = parts.first?.isEmpty == false ? parts[0] : "127.0.0.1"
        let port = parts.count > 1 ? (Int(parts[1]) ?? 9090) : 9090
        return ControllerEndpoint(channel: .http(host: host, port: port), secret: effSecret, clientKind: clientKind, configPath: effConfig)
    }

    // MARK: - Light YAML Parser Helpers

    public static func parseYamlString(named key: String, in content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(key + ":") else { continue }
            var val = trimmed.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
            if val.hasPrefix("\"") && val.hasSuffix("\"") && val.count >= 2 {
                val = String(val.dropFirst().dropLast())
            } else if val.hasPrefix("'") && val.hasSuffix("'") && val.count >= 2 {
                val = String(val.dropFirst().dropLast())
            }
            return String(val)
        }
        return nil
    }

    public static func parseYamlInt(named key: String, in content: String) -> Int? {
        guard let s = parseYamlString(named: key, in: content) else { return nil }
        return Int(s)
    }

    public static func parseYamlPort(in content: String) -> Int? {
        if let p = parseYamlInt(named: "external-controller-port", in: content) { return p }
        if let s = parseYamlString(named: "external-controller", in: content) {
            if let portStr = s.components(separatedBy: ":").last, let p = Int(portStr) {
                return p
            }
        }
        return nil
    }
}
