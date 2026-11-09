import Foundation
import PharosCore

func testClashModels() {
    expectEq(ClashRoutingMode.rule.rawValue, "rule", "ClashRoutingMode.rule")
    expectEq(ClashRoutingMode.direct.rawValue, "direct", "ClashRoutingMode.direct")
    expectEq(ClashRoutingMode.global.rawValue, "global", "ClashRoutingMode.global")
    expectEq(ClashRoutingMode.script.rawValue, "script", "ClashRoutingMode.script")

    expectEq(ClashClientKind.mihomoParty.iconName, "point.3.connected.trianglepath.dotted", "Mihomo party icon")
    expectEq(ClashClientKind.clashVerge.iconName, "shield.lefthalf.filled", "Clash verge icon")
    expectEq(ClashClientKind.clashNyanpasu.iconName, "arrow.triangle.branch", "Clash nyanpasu icon")
    expectEq(ClashClientKind.genericMihomo.iconName, "network", "Generic mihomo icon")

    let snapshot = ClashStatusSnapshot(
        isRunning: true,
        clientKind: .mihomoParty,
        mode: .rule,
        mixedPort: 7890,
        socksPort: 7891,
        httpPort: 7892,
        isTunEnabled: true,
        uploadBytesPerSec: 1024,
        downloadBytesPerSec: 2048,
        totalUploadBytes: 100_000,
        totalDownloadBytes: 200_000,
        activeConnectionCount: 5,
        controllerEndpoint: "unix:///tmp/test.sock"
    )
    expect(snapshot.isRunning, "snapshot isRunning")
    expectEq(snapshot.clientKind, .mihomoParty, "snapshot clientKind")
    expectEq(snapshot.mode, .rule, "snapshot mode")
    expectEq(snapshot.mixedPort, 7890, "snapshot mixedPort")
    expect(snapshot.isTunEnabled, "snapshot isTunEnabled")
    expectEq(snapshot.activeConnectionCount, 5, "snapshot activeConnectionCount")
}

func testBrowserProxyStrategy() {
    var c = ChromeConfig(browser: .chrome)
    expectEq(c.proxyStrategy, .followSystem, "default config follows system")

    c.proxyStrategy = .direct
    expectEq(c.proxyServer, "direct://", "direct sets proxyServer")
    expect(c.extraFlags.contains("--no-proxy-server"), "direct includes --no-proxy-server in extraFlags")
    let directArgs = ChromeInstances.launchArguments(c)
    expect(directArgs.contains("--proxy-server=direct://"), "launchArgs has --proxy-server=direct://")
    expect(directArgs.contains("--no-proxy-server"), "launchArgs has --no-proxy-server")

    c.proxyStrategy = .clashMixedPort(7890)
    expectEq(c.proxyServer, "http://127.0.0.1:7890", "clashMixedPort sets proxyServer")
    expect(!c.extraFlags.contains("--no-proxy-server"), "clash clears --no-proxy-server")
    expect(c.extraFlags.contains("--proxy-bypass-list=<local>;localhost;127.0.0.1;*.local"), "clash sets bypass list")

    c.proxyStrategy = .custom("socks5://10.0.0.1:1080")
    expectEq(c.proxyServer, "socks5://10.0.0.1:1080", "custom sets proxyServer")

    c.proxyStrategy = .followSystem
    expectEq(c.proxyServer, nil, "followSystem clears proxyServer")
    expect(!c.extraFlags.contains("--no-proxy-server"), "followSystem clears --no-proxy-server")

    // Convenience generators
    let directConfig = ChromeInstances.directConfig(for: .chrome)
    expectEq(directConfig.proxyStrategy, .direct, "directConfig strategy is direct")
    expect(directConfig.userDataDir?.contains("chrome-direct") == true, "directConfig custom userDataDir")

    let clashConfig = ChromeInstances.clashConfig(for: .edge, port: 7897)
    expectEq(clashConfig.proxyStrategy, .clashMixedPort(7897), "clashConfig strategy is clashMixedPort(7897)")

    // Terminal command helpers
    let (exportCmd, unsetCmd) = ChromeInstances.terminalProxyCommands(mixedPort: 7890)
    expect(exportCmd.contains("http://127.0.0.1:7890"), "exportCmd sets http_proxy")
    expect(exportCmd.contains("socks5://127.0.0.1:7890"), "exportCmd sets all_proxy")
    expectEq(unsetCmd, "unset http_proxy https_proxy all_proxy", "unsetCmd")
}

func testClashYamlParsing() {
    let vergeYaml = """
    verge_app_log_level: info
    verge_external_controller_port: 9097
    verge_clash_secret: "secret-token-xyz"
    """
    expectEq(ClashController.parseYamlInt(named: "verge_external_controller_port", in: vergeYaml), 9097, "parse verge port")
    expectEq(ClashController.parseYamlString(named: "verge_clash_secret", in: vergeYaml), "secret-token-xyz", "parse verge secret")

    let clashYaml = """
    port: 7890
    socks-port: 7891
    mixed-port: 7890
    external-controller: 127.0.0.1:9090
    secret: 'clash-meta-secret'
    mode: rule
    """
    expectEq(ClashController.parseYamlPort(in: clashYaml), 9090, "parse external-controller port")
    expectEq(ClashController.parseYamlString(named: "secret", in: clashYaml), "clash-meta-secret", "parse single quoted secret")
}

func testSingBoxConfigParsing() {
    let singBoxJson = """
    {
      "experimental": {
        "clash_api": {
          "external_controller": "127.0.0.1:9095",
          "external_ui": "ui",
          "secret": "my-sing-box-token"
        }
      }
    }
    """
    let parsed = ClashController.parseSingBoxConfig(content: singBoxJson)
    expectEq(parsed?.port, 9095, "parse sing-box port")
    expectEq(parsed?.secret, "my-sing-box-token", "parse sing-box secret")

    let invalidJson = "invalid json string"
    expectEq(ClashController.parseSingBoxConfig(content: invalidJson)?.port, nil, "invalid json returns nil")
}

func testEndpointParsing() {
    let httpEp = ClashController.parseEndpoint(from: "http://127.0.0.1:9097", secret: "secret123")
    expectEq(httpEp?.displayString, "http://127.0.0.1:9097", "http endpoint parsed")
    expectEq(httpEp?.secret, "secret123", "secret preserved")

    let rawHostPort = ClashController.parseEndpoint(from: "127.0.0.1:7890")
    expectEq(rawHostPort?.displayString, "http://127.0.0.1:7890", "raw host:port parsed")

    let unixEp = ClashController.parseEndpoint(from: "unix:///tmp/mihomo.sock")
    expectEq(unixEp?.displayString, "unix:///tmp/mihomo.sock", "unix socket parsed")

    let rawUnix = ClashController.parseEndpoint(from: "/private/tmp/mihomo-party.sock")
    expectEq(rawUnix?.displayString, "unix:///private/tmp/mihomo-party.sock", "raw path parsed as unix socket")
}

func testHttpResponseParsing() {
    let rawHttp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 15\r\n\r\n{\"status\":\"ok\"}"
    let parsed = try? ClashController.parseHttpResponse(data: Data(rawHttp.utf8))
    expectEq(parsed?.statusCode, 200, "status code 200")
    if let data = parsed?.data, let str = String(data: data, encoding: .utf8) {
        expectEq(str, "{\"status\":\"ok\"}", "parsed body")
    } else {
        expect(false, "body should decode")
    }

    let noContentHttp = "HTTP/1.1 204 No Content\r\nDate: Mon, 26 Oct 2026 05:00:00 GMT\r\n\r\n"
    let parsed204 = try? ClashController.parseHttpResponse(data: Data(noContentHttp.utf8))
    expectEq(parsed204?.statusCode, 204, "status code 204")
    expectEq(parsed204?.data.isEmpty, true, "no content has empty body")
}

func testMihomoProxyNodeAndStrategy() {
    let ssNode = MihomoProxyNode(name: "HK-01", type: "ss", delay: 45, alive: true)
    expect(ssNode.isLeaf, "ss is leaf")
    expectEq(ssNode.name, "HK-01", "ss name")
    expectEq(ssNode.delay, 45, "ss delay")
    expect(ssNode.alive, "ss alive")

    let selectorNode = MihomoProxyNode(name: "PROXY", type: "Selector")
    expect(!selectorNode.isLeaf, "selector is not leaf")

    let urlTestNode = MihomoProxyNode(name: "Auto", type: "URLTest")
    expect(!urlTestNode.isLeaf, "urltest is not leaf")

    var config = ChromeConfig(browser: .chrome, debugPort: 9222)
    expectEq(config.dedicatedProxyPort, 19222, "dedicated proxy port is 10000 + 9222")
    expectEq(config.dedicatedGroupName, "Pharos-9222", "dedicated group name")

    config.proxyStrategy = .node(name: "HK-01", port: 19222)
    expectEq(config.proxyNodeName, "HK-01", "node name stored")
    expectEq(config.proxyServer, "http://127.0.0.1:19222", "node sets proxyServer")
    expect(config.proxyStrategy.isClash, "node isClash")
    expectEq(config.proxyStrategy.nodeName, "HK-01", "strategy nodeName")
    expect(config.extraFlags.contains("--proxy-bypass-list=<local>;localhost;127.0.0.1;*.local"), "node sets bypass")

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    if let data = try? encoder.encode(config.proxyStrategy),
       let decoded = try? decoder.decode(BrowserProxyStrategy.self, from: data) {
        expectEq(decoded, config.proxyStrategy, "node strategy codable roundtrip")
    } else {
        expect(false, "node strategy failed codable")
    }

    // Test ProxyNodeRegion classification
    expectEq(MihomoProxyNode(name: "[IPLC] 专线-香港01-BGP", type: "ss").region, .hongKong, "detect HK")
    expectEq(MihomoProxyNode(name: "JP Tokyo 03", type: "vmess").region, .japan, "detect JP")
    expectEq(MihomoProxyNode(name: "SG 新加坡 02", type: "trojan").region, .singapore, "detect SG")
    expectEq(MihomoProxyNode(name: "US Los Angeles 01", type: "ss").region, .unitedStates, "detect US")
    expectEq(MihomoProxyNode(name: "TW 台北 05", type: "vmess").region, .taiwan, "detect TW")
    expectEq(MihomoProxyNode(name: "KR 首尔 01", type: "ss").region, .korea, "detect KR")
    expectEq(MihomoProxyNode(name: "UK London 02", type: "ss").region, .europe, "detect EU")
    expectEq(MihomoProxyNode(name: "DIRECT", type: "direct").region, .other, "detect other")

    // Test isHealthy, statusRank and validDelay
    let healthyNode = MihomoProxyNode(name: "Fast-01", type: "ss", delay: 45, alive: true)
    let slowNode = MihomoProxyNode(name: "Slow-02", type: "ss", delay: 350, alive: true)
    let untestedNode = MihomoProxyNode(name: "Untested-03", type: "ss", delay: nil, alive: true)
    let timeout0Node = MihomoProxyNode(name: "Timeout-04", type: "ss", delay: 0, alive: false)
    let timeoutAliveNode = MihomoProxyNode(name: "Timeout-05", type: "ss", delay: 0, alive: true)

    expect(healthyNode.isHealthy, "healthy is healthy")
    expectEq(healthyNode.validDelay, 45, "healthy validDelay")
    expectEq(healthyNode.statusRank, 0, "healthy statusRank 0")

    expect(!untestedNode.isHealthy, "untested not healthy")
    expectEq(untestedNode.validDelay, nil, "untested validDelay nil")
    expectEq(untestedNode.statusRank, 1, "untested statusRank 1")

    expect(!timeout0Node.isHealthy, "timeout 0 not healthy")
    expectEq(timeout0Node.validDelay, nil, "timeout 0 validDelay nil")
    expectEq(timeout0Node.statusRank, 2, "timeout 0 statusRank 2")

    expect(!timeoutAliveNode.isHealthy, "timeout alive not healthy")
    expectEq(timeoutAliveNode.statusRank, 2, "timeout alive statusRank 2")

    // Test sort guarantee: healthy nodes MUST precede timeout nodes!
    var testList = [timeout0Node, slowNode, timeoutAliveNode, healthyNode, untestedNode]
    testList.sort { a, b in
        if a.statusRank != b.statusRank { return a.statusRank < b.statusRank }
        if let d1 = a.validDelay, let d2 = b.validDelay, d1 != d2 { return d1 < d2 }
        return a.name < b.name
    }
    expectEq(testList.map(\.name), ["Fast-01", "Slow-02", "Untested-03", "Timeout-04", "Timeout-05"], "healthy nodes precede timeout nodes in sort")
}

func testChunkedHttpDecoding() {
    let singleChunk = "d\r\nHello, world!\r\n0\r\n\r\n"
    let decodedSingle = ClashController.decodeChunkedBody(data: Data(singleChunk.utf8))
    expectEq(String(data: decodedSingle, encoding: .utf8), "Hello, world!", "single chunk decoded")

    let multiChunk = "4\r\nWiki\r\n6\r\npedia \r\n0\r\n\r\n"
    let decodedMulti = ClashController.decodeChunkedBody(data: Data(multiChunk.utf8))
    expectEq(String(data: decodedMulti, encoding: .utf8), "Wikipedia ", "multi chunk decoded")

    let nonChunked = "Raw plain text content"
    let decodedPlain = ClashController.decodeChunkedBody(data: Data(nonChunked.utf8))
    expectEq(String(data: decodedPlain, encoding: .utf8), "Raw plain text content", "non-chunked returns as is")
}

func testProcessArgvParsing() {
    let args1 = ["/usr/local/bin/mihomo", "-d", "/Users/test/.config/mihomo", "-ext-ctl-unix", "/tmp/mihomo-test.sock"]
    let parsed1 = ClashController.parseProcessArguments(args1)
    expectEq(parsed1.sockPath, "/tmp/mihomo-test.sock", "parse unix socket")
    expectEq(parsed1.workDir, "/Users/test/.config/mihomo", "parse workdir")

    let args2 = ["mihomo", "-ext-ctl=127.0.0.1:9099", "-f=/etc/mihomo/config.yaml"]
    let parsed2 = ClashController.parseProcessArguments(args2)
    expectEq(parsed2.extCtl, "127.0.0.1:9099", "parse extCtl with equal sign")
    expectEq(parsed2.configPath, "/etc/mihomo/config.yaml", "parse configPath with equal sign")
}

func testLiveClashControllerIfPresent() {
    guard let endpoint = ClashController.detectActiveEndpoint() else {
        // No client running in this environment, test passed
        return
    }

    print("Detected live Clash/Mihomo daemon at: \(endpoint.displayString) (\(endpoint.clientKind.rawValue))")
    let expectation = DispatchSemaphore(value: 0)

    Task {
        do {
            let config = try await ClashController.fetchConfig(endpoint: endpoint)
            expect(config.mixedPort > 0, "live mixed port > 0")
            let (connCount, _, _) = try await ClashController.fetchConnections(endpoint: endpoint)
            expect(connCount >= 0, "live connections count >= 0")
            print("  - Mode: \(config.mode.rawValue), Mixed Port: \(config.mixedPort), Active Conns: \(connCount), TUN: \(config.isTun)")
        } catch {
            print("  - Live probe note: \(error)")
        }
        expectation.signal()
    }

    _ = expectation.wait(timeout: .now() + 3.0)
}
