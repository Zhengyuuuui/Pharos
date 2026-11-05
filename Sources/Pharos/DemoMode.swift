import Foundation
import AppKit
import PharosCore

/// Global demo mode controller.
/// When running inside `Pharos Demo.app` or with `--demo` / `--capture-screenshots`,
/// all modules lock onto realistic developer mock data and cease scanning real disks or PIDs,
/// ensuring zero leaks of private unreleased projects while providing a complete interactive stage.
@MainActor
enum DemoMode {
    static var isEnabled: Bool {
        if CommandLine.arguments.contains("--demo") ||
           CommandLine.arguments.contains("--capture-screenshots") ||
           CommandLine.arguments.contains("--capture-light") {
            return true
        }
        let bundleName = Bundle.main.bundleURL.lastPathComponent
        return bundleName.localizedCaseInsensitiveContains("Demo")
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
