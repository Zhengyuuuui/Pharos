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

        public init(channel: Channel, secret: String? = nil, clientKind: ClashClientKind = .genericMihomo) {
            self.channel = channel
            self.secret = secret
            self.clientKind = clientKind
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

    /// Automatically scans and returns the active Clash/Mihomo controller endpoint.
    public static func detectActiveEndpoint() -> ControllerEndpoint? {
        // 1. Probing Unix Domain Sockets (Priority 1: Mihomo Party / Clash Party)
        if let partySocket = findActiveMihomoPartySocket() {
            return ControllerEndpoint(channel: .unixSocket(path: partySocket), secret: nil, clientKind: .mihomoParty)
        }

        // 2. Probing Verge Unix Sockets
        if let vergeSocket = findActiveVergeSocket() {
            return ControllerEndpoint(channel: .unixSocket(path: vergeSocket), secret: nil, clientKind: .clashVerge)
        }

        // 3. Probing Known Configuration Files for Port & Secret
        let home = NSHomeDirectory()

        // 3.1 Clash Verge Rev
        let vergeConfigPath = home + "/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/verge.yaml"
        if let content = try? String(contentsOfFile: vergeConfigPath, encoding: .utf8) {
            let port = parseYamlInt(named: "verge_external_controller_port", in: content) ?? 9097
            let secret = parseYamlString(named: "verge_clash_secret", in: content)
            if canConnectTCP(port: port) {
                return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .clashVerge)
            }
        }

        // 3.2 Clash Nyanpasu
        let nyanpasuConfig = home + "/Library/Application Support/mo.yanpasu.clash-nyanpasu/config.yaml"
        if let content = try? String(contentsOfFile: nyanpasuConfig, encoding: .utf8) {
            let port = parseYamlPort(in: content) ?? 9090
            let secret = parseYamlString(named: "secret", in: content)
            if canConnectTCP(port: port) {
                return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .clashNyanpasu)
            }
        }

        // 3.3 ClashX.Meta / ClashX
        for path in [home + "/.config/clash.meta/config.yaml", home + "/.config/clash/config.yaml"] {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                let port = parseYamlPort(in: content) ?? 9090
                let secret = parseYamlString(named: "secret", in: content)
                if canConnectTCP(port: port) {
                    return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .clashX)
                }
            }
        }

        // 3.4 Flclash
        let flclashConfig = home + "/Library/Application Support/com.flclash.flclash/config.yaml"
        if let content = try? String(contentsOfFile: flclashConfig, encoding: .utf8) {
            let port = parseYamlPort(in: content) ?? 9090
            let secret = parseYamlString(named: "secret", in: content)
            if canConnectTCP(port: port) {
                return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .flclash)
            }
        }

        // 3.5 Generic Mihomo Core CLI
        let genericConfig = home + "/.config/mihomo/config.yaml"
        if let content = try? String(contentsOfFile: genericConfig, encoding: .utf8) {
            let port = parseYamlPort(in: content) ?? 9090
            let secret = parseYamlString(named: "secret", in: content)
            if canConnectTCP(port: port) {
                return ControllerEndpoint(channel: .http(host: "127.0.0.1", port: port), secret: secret, clientKind: .genericMihomo)
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
                if responseData.count > 2 * 1024 * 1024 { break } // 2MB limit
            }

            return try parseHttpResponse(data: responseData)
        }.value
    }

    /// Parses a raw HTTP/1.1 response buffer.
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

        return (code, bodyData)
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
        let installed = [
            "/Applications/Clash Verge Rev.app": ClashClientKind.clashVerge,
            "/Applications/Clash Verge.app": ClashClientKind.clashVerge,
            "/Applications/Clash Party.app": ClashClientKind.mihomoParty,
            "/Applications/Mihomo Party.app": ClashClientKind.mihomoParty,
            "/Applications/Clash Nyanpasu.app": ClashClientKind.clashNyanpasu,
            "/Applications/ClashX.Meta.app": ClashClientKind.clashX,
            "/Applications/ClashX.app": ClashClientKind.clashX,
            "/Applications/Flclash.app": ClashClientKind.flclash
        ]
        for (path, kind) in installed {
            if FileManager.default.fileExists(atPath: path) { return kind }
        }
        return nil
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
