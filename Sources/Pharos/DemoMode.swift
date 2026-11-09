import Foundation
import AppKit
import SwiftUI
import PharosCore

/// State holder for interactive demo mode features.
@MainActor
final class DemoModeState: ObservableObject {
    static let shared = DemoModeState()
    @Published var version: DemoMode.DemoVersion = .v3_1_0
    @Published var windowOpacity: Double = 1.0
}

/// Global demo mode controller.
/// When running inside `Pharos Demo.app` or with `--demo` / `--capture-screenshots`,
/// all modules lock onto realistic developer mock data and cease scanning real disks or PIDs,
/// ensuring zero leaks of private unreleased projects while providing a complete interactive stage.
@MainActor
enum DemoMode {
    public enum DemoVersion: String, Sendable {
        case v3_1_0 = "3.1.0"
        case v3_2_0 = "3.2.0"
    }

    public static var currentDemoVersion: DemoVersion {
        get { DemoModeState.shared.version }
        set { DemoModeState.shared.version = newValue }
    }

    public static var windowOpacity: Double {
        get { DemoModeState.shared.windowOpacity }
        set { DemoModeState.shared.windowOpacity = newValue }
    }

    static var isEnabled: Bool {
        if CommandLine.arguments.contains("--demo") ||
           CommandLine.arguments.contains("--capture-screenshots") ||
           CommandLine.arguments.contains("--capture-light") {
            return true
        }
        let bundleName = Bundle.main.bundleURL.lastPathComponent
        return bundleName.localizedCaseInsensitiveContains("Demo")
    }

    // MARK: - Compliant Mock Nodes

    public static let canonicalDemoNodes: [MihomoProxyNode] = [
        MihomoProxyNode(name: "HK-Direct-Alpha", type: "Dedicated", delay: 28, alive: true),
        MihomoProxyNode(name: "JP-Tokyo-Cluster-02", type: "Dedicated", delay: 42, alive: true),
        MihomoProxyNode(name: "SG-SingTel-Dedicated", type: "Dedicated", delay: 56, alive: true),
        MihomoProxyNode(name: "US-SiliconValley-Fast", type: "Direct", delay: 128, alive: true),
        MihomoProxyNode(name: "DE-Frankfurt-Peer", type: "Direct", delay: 145, alive: true),
        MihomoProxyNode(name: "Direct-Office-Intranet", type: "Direct", delay: 0, alive: true)
    ]

    public static let refreshedDemoNodes: [MihomoProxyNode] = [
        MihomoProxyNode(name: "Direct-Office-Intranet", type: "Direct", delay: 0, alive: true),
        MihomoProxyNode(name: "HK-Direct-Alpha", type: "Dedicated", delay: 18, alive: true),
        MihomoProxyNode(name: "JP-Tokyo-Cluster-02", type: "Dedicated", delay: 24, alive: true),
        MihomoProxyNode(name: "SG-SingTel-Dedicated", type: "Dedicated", delay: 32, alive: true),
        MihomoProxyNode(name: "US-SiliconValley-Fast", type: "Direct", delay: 42, alive: true),
        MihomoProxyNode(name: "DE-Frankfurt-Peer", type: "Direct", delay: 46, alive: true)
    ]

    // MARK: - Simulated Update Manifest

    public static var demoReleaseManifest: ReleaseManifest {
        ReleaseManifest(
            version: "3.2.0",
            tagName: "v3.2.0",
            releaseName: "Pharos v3.2.0: Spotlight 节点调度 · 毫秒探活 · 3.5pt 极窄滚动条",
            publishedAt: "2026-11-09T08:00:00Z",
            notes: """
            ✨ Pharos v3.2.0 重磅发布：
            • Spotlight 节点调度：380×430 悬浮岛设计，支持实例级网络直通与毫秒级模糊检索
            • 高并发毫秒探活：内核级全并发探活与双向往返时延遥测，智能置顶最优链路
            • PharosSlimScroller：3.5pt 极窄浮动滚动条，阻尼悬浮、完全透明槽位、动态微光
            • 边缘原子自更新：Cloudflare Worker 边缘网关毫秒分发，SHA-256 + CodeSign 双重验签
            """,
            sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            dmgName: "Pharos-3.2.0.dmg",
            dmgSize: 26_004_684, // 24.8 MB
            dmgUrl: URL(string: "https://pharos-update.zysgm123.workers.dev/dist/Pharos-3.2.0.dmg")!,
            githubDmgUrl: URL(string: "https://github.com/Zhengyuuuui/Pharos/releases/download/v3.2.0/Pharos-3.2.0.dmg")!,
            htmlUrl: URL(string: "https://github.com/Zhengyuuuui/Pharos/releases/tag/v3.2.0")!
        )
    }

    /// 一键回档至 3.1.0 待更新状态
    public static func resetToPreUpdate() {
        currentDemoVersion = .v3_1_0
        windowOpacity = 1.0
        UpdateStore.shared.setDemoAvailableManifest()
        ClashStore.shared.applyMockNodes(canonicalDemoNodes)
    }

    /// 执行 1.5 秒伪更新动画
    public static func simulateUpdateWorkflow(onComplete: (() -> Void)? = nil) {
        UpdateStore.shared.simulateDownloadAndRelaunch {
            currentDemoVersion = .v3_2_0
            onComplete?()
        }
    }

    /// All canonical mock projects available for interactive launch/stop cycles.
    static var canonicalMockProjects: [String: Project] = [:]

    static func registerCanonicalProjects(_ projects: [Project]) {
        for p in projects {
            canonicalMockProjects[p.name] = p
            canonicalMockProjects[p.id] = p
        }
    }

    /// Simulate stopping a project in Demo mode without sending SIGTERM to real OS processes.
    static func simulateStop(project: Project, in store: ProjectStore) {
        var next = store.state
        next.projects.removeAll { $0.id == project.id || $0.name == project.name }
        let stoppedPorts = Set(project.ports.map(\.port))
        next.listeningPorts.subtract(stoppedPorts)
        store.applyMockState(next)
    }

    /// Simulate starting a project when the user clicks 'Play' / 'Open in Terminal' in Favorites.
    static func simulateStart(favorite: Favorite, in store: ProjectStore) {
        let name = favorite.name
        guard let proto = canonicalMockProjects[name] ?? canonicalMockProjects[favorite.id] else {
            // Synthesize fallback mock project if not found
            let port = favorite.lastPorts.first ?? 3000
            let p = Project(
                id: name,
                name: name,
                directory: favorite.directory,
                listeners: [makeProc(name: "node", pid: Int32(port + 1), port: port, memory: 150_000_000)],
                helpers: [],
                ports: [ListeningPort(port: port, loopbackOnly: true)],
                memoryBytes: 150_000_000
            )
            var next = store.state
            if !next.projects.contains(where: { $0.name == name }) {
                next.projects.insert(p, at: 0)
            }
            next.listeningPorts.insert(port)
            store.applyMockState(next)
            return
        }

        var next = store.state
        if !next.projects.contains(where: { $0.id == proto.id || $0.name == proto.name }) {
            next.projects.insert(proto, at: 0)
        }
        for lp in proto.ports {
            next.listeningPorts.insert(lp.port)
        }
        store.applyMockState(next)
    }

    /// Simulate toggling battery 80% charge limit in Demo mode without root helper tool errors.
    static func simulateToggleBatteryLimit() {
        BatteryStore.shared.toggleDemoModeBypass()
    }

    private static func makeProc(name: String, pid: Int32, port: UInt16, memory: UInt64) -> ProcessSnapshot {
        ProcessSnapshot(
            pid: pid,
            ppid: 1,
            name: name,
            executablePath: "/usr/local/bin/\(name)",
            cwd: "/Users/developer/Projects",
            arguments: [name, "server"],
            memoryBytes: memory,
            ports: [ListeningPort(port: port, loopbackOnly: true)]
        )
    }
}
