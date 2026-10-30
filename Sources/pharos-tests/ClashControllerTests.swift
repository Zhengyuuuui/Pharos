import Foundation
import PharosCore

func testClashModels() {
    expectEq(ClashRoutingMode.rule.rawValue, "rule", "ClashRoutingMode.rule")
    expectEq(ClashRoutingMode.direct.rawValue, "direct", "ClashRoutingMode.direct")
    expectEq(ClashRoutingMode.global.rawValue, "global", "ClashRoutingMode.global")
    expectEq(ClashRoutingMode.script.rawValue, "script", "ClashRoutingMode.script")

    expectEq(ClashClientKind.mihomoParty.iconName, "party.popper.fill", "Mihomo party icon")
    expectEq(ClashClientKind.clashVerge.iconName, "shield.lefthalf.filled", "Clash verge icon")
    expectEq(ClashClientKind.clashNyanpasu.iconName, "cat.fill", "Clash nyanpasu icon")
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
