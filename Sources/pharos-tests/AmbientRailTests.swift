import Foundation
import PharosCore

func testAmbientRailCore() {
    // 1. Local Network Resolution & Daemons
    let ip = LocalNetwork.activeLANIPv4()
    if let ip {
        expect(ip.contains("."), "LAN IP has dot notation")
        expect(!ip.hasPrefix("127."), "LAN IP is not loopback")
    }

    let fakePorts = [
        ListeningPort(port: 5432, loopbackOnly: false),
        ListeningPort(port: 6379, loopbackOnly: true),
        ListeningPort(port: 3000, loopbackOnly: false),
        ListeningPort(port: 5173, loopbackOnly: true)
    ]

    let daemons = LocalNetwork.auditDaemons(listeningPorts: fakePorts)
    let pg = daemons.first(where: { $0.name == "PostgreSQL" })
    let redis = daemons.first(where: { $0.name == "Redis" })
    let mysql = daemons.first(where: { $0.name == "MySQL" })
    expect(pg?.isRunning == true, "PostgreSQL should be detected as running on 5432")
    expect(redis?.isRunning == true, "Redis should be detected as running on 6379")
    expect(mysql?.isRunning == false, "MySQL should be detected as not running")

    let webUrls = LocalNetwork.resolveWebURLs(ports: fakePorts, lanIP: "192.168.1.10")
    expectEq(webUrls.count, 2, "2 web debug ports detected")
    expect(webUrls.contains(where: { $0.port == 3000 && $0.lanURL == "http://192.168.1.10:3000" }), "Port 3000 LAN URL")
    expect(webUrls.contains(where: { $0.port == 5173 && $0.localURL == "http://127.0.0.1:5173" }), "Port 5173 local URL")

    // 2. Project Tech Stack Detection
    let tmpDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("pharos-rail-test-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tmpDir) }

    let pkgJson = """
    {
      "name": "sample-app",
      "dependencies": {
        "next": "14.2.0",
        "react": "18.3.0",
        "tailwindcss": "^3.4.0"
      }
    }
    """
    try? pkgJson.write(toFile: (tmpDir as NSString).appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
    try? "{}".write(toFile: (tmpDir as NSString).appendingPathComponent("tsconfig.json"), atomically: true, encoding: .utf8)
    try? "FROM node:20".write(toFile: (tmpDir as NSString).appendingPathComponent("Dockerfile"), atomically: true, encoding: .utf8)

    let badges = ProjectTechStack.detect(directory: tmpDir)
    expect(badges.contains(.nextjs), "Detected Next.js")
    expect(badges.contains(.react), "Detected React")
    expect(badges.contains(.tailwind), "Detected Tailwind")
    expect(badges.contains(.typescript), "Detected TypeScript")
    expect(badges.contains(.docker), "Detected Docker")
    expect(badges.contains(.node), "Detected Node")

    // 3. Memory Domain Attribution
    let sampleApps = [
        AppUsage(name: "Google Chrome", memoryBytes: 1024 * 1024 * 1024, processCount: 15),
        AppUsage(name: "Xcode", memoryBytes: 2048 * 1024 * 1024, processCount: 5),
        AppUsage(name: "Finder", memoryBytes: 512 * 1024 * 1024, processCount: 1)
    ]
    let breakdown = MemoryAttribution.calculate(apps: sampleApps)
    expectEq(breakdown.browserBytes, 1024 * 1024 * 1024, "Browser bytes match Chrome")
    expectEq(breakdown.devBytes, 2048 * 1024 * 1024, "Dev bytes match Xcode")
    expectEq(breakdown.otherBytes, 512 * 1024 * 1024, "Other bytes match Finder")
    expect(breakdown.devFraction > 0.5, "Dev tools account for majority")

    // 4. Popover Height Estimation
    let estHeight = PopoverHeightEstimator.estimatedHeight(blocks: [.memory, .disk, .devProjects])
    expect(estHeight >= 250 && estHeight <= 450, "Estimated popover height is within expected bounds: \(estHeight)")

    // 5. Thermal Headroom
    let (h1, t1) = ThermalHeadroom.calculate(peakTemp: 55.0)
    expectEq(h1, 45.0, "Headroom for 55C is 45C")
    expect(!t1, "55C is not throttling")

    let (h2, t2) = ThermalHeadroom.calculate(peakTemp: 98.0)
    expectEq(h2, 2.0, "Headroom for 98C is 2C")
    expect(t2, "98C is throttling")

    // 6. Disk Runway
    let (p1, l1) = DiskRunway.evaluate(usedFraction: 0.70)
    expectEq(Int(p1), 30, "Available 30%")
    expectEq(l1, .healthy, "30% is healthy")

    let (p2, l2) = DiskRunway.evaluate(usedFraction: 0.88)
    expectEq(Int(p2), 12, "Available 12%")
    expectEq(l2, .warning, "12% is warning")

    let (p3, l3) = DiskRunway.evaluate(usedFraction: 0.95)
    expectEq(Int(p3), 5, "Available 5%")
    expectEq(l3, .critical, "5% is critical")
}
