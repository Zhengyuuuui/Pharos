import Foundation
import PharosCore

func testPackageModels() {
    expectEq(PackageEcosystem.node.displayName, "Node.js / npm", "node display name")
    expectEq(PackageEcosystem.python.displayName, "Python", "python display name")
    expectEq(PackageEcosystem.java.displayName, "Java / Maven", "java display name")
    expectEq(PackageEcosystem.rust.displayName, "Rust / Cargo", "rust display name")
    expectEq(PackageEcosystem.go.displayName, "Go Modules", "go display name")
    expectEq(PackageEcosystem.swift.displayName, "SwiftPM", "swift display name")
    expectEq(PackageEcosystem.homebrew.displayName, "Homebrew", "homebrew display name")

    expectEq(PackageEcosystem.node.iconName, "hexagon.fill", "node icon")
    expectEq(PackageEcosystem.python.iconName, "snake.fill", "python icon")
    expectEq(PackageEcosystem.swift.iconName, "swift", "swift icon")

    let item = LocalPackageItem(
        id: "cli:test",
        name: "test-cli",
        installedVersion: "1.2.3",
        declaredVersion: "^1.0.0",
        ecosystem: .node,
        scope: .globalCli,
        healthStatus: .normal,
        summary: "A test CLI",
        license: "MIT",
        installPath: "/tmp/test",
        executablePath: "/tmp/bin/test-cli",
        fileSizeBytes: 1024,
        lastModified: Date(timeIntervalSince1970: 1700000000),
        projectName: "MyProject",
        isDevDependency: true,
        isFeatured: true,
        categoryTag: "AI 助手"
    )

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    if let data = try? encoder.encode(item),
       let decoded = try? decoder.decode(LocalPackageItem.self, from: data) {
        expectEq(decoded.id, item.id, "LocalPackageItem roundtrip id")
        expectEq(decoded.name, item.name, "LocalPackageItem roundtrip name")
        expectEq(decoded.installedVersion, "1.2.3", "version")
        expectEq(decoded.declaredVersion, "^1.0.0", "declared")
        expectEq(decoded.ecosystem, .node, "ecosystem")
        expectEq(decoded.healthStatus, .normal, "health")
        expectEq(decoded.isDevDependency, true, "isDev")
        expectEq(decoded.isFeatured, true, "isFeatured roundtrip")
        expectEq(decoded.categoryTag, "AI 助手", "categoryTag roundtrip")
    } else {
        expect(false, "Failed to encode/decode LocalPackageItem")
    }

    // Test catalog
    expect(PackageScanner.featuredCliCatalog["claude"]?.tag == "AI 助手", "claude catalog tag")
    expect(PackageScanner.featuredCliCatalog["grok"]?.tag == "AI 助手", "grok catalog tag")
    expect(PackageScanner.featuredCliCatalog["uv"]?.tag == "包管理", "uv catalog tag")
    expect(PackageScanner.featuredCliCatalog["cargo-tauri"]?.tag == "开发构建", "cargo-tauri catalog tag")
    expect(PackageScanner.featuredCliCatalog["gh"]?.tag == "终端效率", "gh catalog tag")

    // Test uninstallCommand generator
    let nodeItem = LocalPackageItem(id: "1", name: "grok", installedVersion: "1.0", ecosystem: .node, scope: .globalCli, installPath: "/path/npm")
    expectEq(nodeItem.uninstallCommand, "npm uninstall -g grok", "node uninstall command")

    let brewItem = LocalPackageItem(id: "2", name: "ripgrep", installedVersion: "14.1", ecosystem: .homebrew, scope: .globalCli, installPath: "/opt/homebrew/bin/rg")
    expectEq(brewItem.uninstallCommand, "brew uninstall ripgrep", "brew uninstall command")

    let rustItem = LocalPackageItem(id: "3", name: "cargo-tauri", installedVersion: "2.0", ecosystem: .rust, scope: .globalCli, installPath: "/path/cargo")
    expectEq(rustItem.uninstallCommand, "cargo uninstall cargo-tauri", "cargo uninstall command")

    let uvItem = LocalPackageItem(id: "4", name: "aider", installedVersion: "0.50", ecosystem: .python, scope: .globalCli, installPath: "/path/aider", executablePath: "/Users/test/.local/bin/aider")
    expectEq(uvItem.uninstallCommand, "uv tool uninstall aider", "uv tool uninstall command")

    let pipItem = LocalPackageItem(id: "5", name: "flake8", installedVersion: "7.0", ecosystem: .python, scope: .globalCli, installPath: "/path/flake8", executablePath: "/Library/Python/3.13/bin/flake8")
    expectEq(pipItem.uninstallCommand, "pip uninstall -y flake8", "pip uninstall command")
}

func testGlobalCliScanner() {
    // 1. Live scan test
    let items = PackageScanner.scanGlobalCliTools()
    expect(!items.isEmpty, "Global CLI scanner found installed tools")

    let names = Set(items.map(\.name))
    print("Detected \(items.count) global CLI tools: \(items.prefix(8).map(\.name).joined(separator: ", "))")

    // Featured tools must be sorted first
    if let firstItem = items.first, items.contains(where: { $0.isFeatured }) {
        expect(firstItem.isFeatured, "Featured tool should be prioritized at top of list")
    }

    // Check if common tools like grok, rea, node, cargo, etc. are found if present
    if names.contains("node") {
        let nodeItem = items.first { $0.name == "node" }
        expectEq(nodeItem?.ecosystem, .node, "node ecosystem")
        expect(nodeItem?.executablePath?.hasSuffix("/node") == true, "node executable path")
    }

    // 2. Mock directory test for deterministic symlink resolution
    let tempDir = NSTemporaryDirectory() + "pharos-cli-test-\(UUID().uuidString)"
    let mockBin = tempDir + "/.nvm/versions/node/v22.0.0/bin"
    let mockLib = tempDir + "/.nvm/versions/node/v22.0.0/lib/node_modules/my-tool"
    try? FileManager.default.createDirectory(atPath: mockBin, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: mockLib, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tempDir) }

    let pkgJson = """
    {
      "name": "my-tool",
      "version": "2.5.0",
      "description": "Mock CLI Tool",
      "license": "Apache-2.0"
    }
    """
    FileManager.default.createFile(atPath: mockLib + "/package.json", contents: Data(pkgJson.utf8))
    FileManager.default.createFile(atPath: mockLib + "/index.js", contents: Data("#!/usr/bin/env node".utf8))

    // Create symlink
    let symlinkPath = mockBin + "/my-tool"
    try? FileManager.default.createSymbolicLink(atPath: symlinkPath, withDestinationPath: "../lib/node_modules/my-tool/index.js")

    let mockItems = PackageScanner.scanGlobalCliTools(home: tempDir)
    let foundMock = mockItems.first { $0.name == "my-tool" }
    expect(foundMock != nil, "Found mock CLI tool via symlink")
    expectEq(foundMock?.installedVersion, "2.5.0", "Mock tool version parsed from package.json")
    expectEq(foundMock?.summary, "Mock CLI Tool", "Mock tool summary")
    expectEq(foundMock?.license, "Apache-2.0", "Mock tool license")
    expectEq(foundMock?.ecosystem, .node, "Mock tool ecosystem")
}

func testProjectDependencyScanner() {
    let tempDir = NSTemporaryDirectory() + "pharos-proj-test-\(UUID().uuidString)"
    let nodeModules = tempDir + "/node_modules"
    let localPkg = tempDir + "/packages/local-auth"
    try? FileManager.default.createDirectory(atPath: nodeModules, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: localPkg, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tempDir) }

    let rootPkgJson = """
    {
      "name": "mock-app",
      "dependencies": {
        "react": "^19.0.0",
        "missing-pkg": "^1.0.0",
        "@local/auth": "workspace:*"
      },
      "devDependencies": {
        "vite": "^6.0.0"
      }
    }
    """
    FileManager.default.createFile(atPath: tempDir + "/package.json", contents: Data(rootPkgJson.utf8))

    // 1. react (installed, normal)
    let reactDir = nodeModules + "/react"
    try? FileManager.default.createDirectory(atPath: reactDir, withIntermediateDirectories: true)
    let reactPkgJson = """
    {
      "name": "react",
      "version": "19.0.0",
      "description": "React is a JavaScript library for building user interfaces.",
      "license": "MIT"
    }
    """
    FileManager.default.createFile(atPath: reactDir + "/package.json", contents: Data(reactPkgJson.utf8))

    // 2. vite (installed, version mismatched)
    let viteDir = nodeModules + "/vite"
    try? FileManager.default.createDirectory(atPath: viteDir, withIntermediateDirectories: true)
    let vitePkgJson = """
    {
      "name": "vite",
      "version": "5.4.1",
      "description": "Next Generation Frontend Tooling",
      "license": "MIT"
    }
    """
    FileManager.default.createFile(atPath: viteDir + "/package.json", contents: Data(vitePkgJson.utf8))

    // 3. @local/auth (symlinked workspace)
    let scopedDir = nodeModules + "/@local"
    try? FileManager.default.createDirectory(atPath: scopedDir, withIntermediateDirectories: true)
    let authPkgJson = """
    {
      "name": "@local/auth",
      "version": "0.1.0",
      "description": "Internal Auth Library",
      "license": "UNLICENSED"
    }
    """
    FileManager.default.createFile(atPath: localPkg + "/package.json", contents: Data(authPkgJson.utf8))
    try? FileManager.default.createSymbolicLink(atPath: scopedDir + "/auth", withDestinationPath: "../../packages/local-auth")

    // 4. missing-pkg is NOT created in node_modules

    guard let summary = PackageScanner.scanProjectDependencies(projectPath: tempDir) else {
        expect(false, "Failed to scan mock project dependencies")
        return
    }

    expectEq(summary.name, "mock-app", "project name")
    expectEq(summary.directDependenciesCount, 4, "total 4 declared dependencies")
    expectEq(summary.missingDependenciesCount, 1, "missing 1 dependency (missing-pkg)")

    let reactItem = summary.packages.first { $0.name == "react" }
    expect(reactItem != nil, "found react")
    expectEq(reactItem?.installedVersion, "19.0.0", "react installed version")
    expectEq(reactItem?.healthStatus, .normal, "react is normal")
    expectEq(reactItem?.isDevDependency, false, "react is prod dep")

    let viteItem = summary.packages.first { $0.name == "vite" }
    expect(viteItem != nil, "found vite")
    expectEq(viteItem?.installedVersion, "5.4.1", "vite installed version")
    expectEq(viteItem?.healthStatus, .mismatched, "vite is mismatched (declared ^6.0.0 vs installed 5.4.1)")
    expectEq(viteItem?.isDevDependency, true, "vite is dev dep")

    let missingItem = summary.packages.first { $0.name == "missing-pkg" }
    expect(missingItem != nil, "found missing-pkg")
    expectEq(missingItem?.healthStatus, .missing, "missing-pkg is missing")

    let authItem = summary.packages.first { $0.name == "@local/auth" }
    expect(authItem != nil, "found @local/auth")
    expectEq(authItem?.healthStatus, .symlinkedWorkspace, "@local/auth is symlinked workspace")
    expectEq(summary.cacheDirectoryName, "node_modules", "node cache directory name")

    // MARK: - Python Project Scanner Test
    let tempPy = NSTemporaryDirectory() + "pharos-py-test-\(UUID().uuidString)"
    let pySite = tempPy + "/.venv/lib/python3.13/site-packages"
    let fastapiDist = pySite + "/fastapi-0.115.0.dist-info"
    try? FileManager.default.createDirectory(atPath: fastapiDist, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tempPy) }

    let reqTxt = """
    fastapi>=0.115.0
    requests==2.31.0
    missing-lib
    """
    FileManager.default.createFile(atPath: tempPy + "/requirements.txt", contents: Data(reqTxt.utf8))

    let metaContent = """
    Metadata-Version: 2.4
    Name: fastapi
    Version: 0.115.0
    Summary: FastAPI framework, high performance, easy to learn
    License: MIT
    """
    FileManager.default.createFile(atPath: fastapiDist + "/METADATA", contents: Data(metaContent.utf8))

    guard let pySummary = PackageScanner.scanProjectDependencies(projectPath: tempPy) else {
        expect(false, "Failed to scan mock Python project")
        return
    }
    expectEq(pySummary.ecosystem, .python, "python ecosystem detected")
    expectEq(pySummary.cacheDirectoryName, ".venv", "python cache directory name is .venv")
    expectEq(pySummary.directDependenciesCount, 3, "python 3 declared dependencies")
    expectEq(pySummary.missingDependenciesCount, 2, "python 2 missing dependencies")
    let fastapiItem = pySummary.packages.first { $0.name == "fastapi" }
    expect(fastapiItem != nil, "found fastapi")
    expectEq(fastapiItem?.installedVersion, "0.115.0", "fastapi installed version")
    expectEq(fastapiItem?.healthStatus, .normal, "fastapi is normal")
    expectEq(fastapiItem?.summary, "FastAPI framework, high performance, easy to learn", "fastapi metadata summary")

    // MARK: - Swift Project Scanner Test
    let tempSwift = NSTemporaryDirectory() + "pharos-swift-test-\(UUID().uuidString)"
    let swiftCheckouts = tempSwift + "/.build/checkouts/swift-argument-parser"
    try? FileManager.default.createDirectory(atPath: swiftCheckouts, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tempSwift) }

    let resolvedJson = """
    {
      "pins": [
        {
          "identity": "swift-argument-parser",
          "location": "https://github.com/apple/swift-argument-parser",
          "state": {
            "version": "1.5.0"
          }
        }
      ],
      "version": 2
    }
    """
    FileManager.default.createFile(atPath: tempSwift + "/Package.resolved", contents: Data(resolvedJson.utf8))

    guard let swiftSummary = PackageScanner.scanProjectDependencies(projectPath: tempSwift) else {
        expect(false, "Failed to scan mock Swift project")
        return
    }
    expectEq(swiftSummary.ecosystem, .swift, "swift ecosystem detected")
    expectEq(swiftSummary.cacheDirectoryName, ".build", "swift cache directory name is .build")
    let argParserItem = swiftSummary.packages.first { $0.name == "swift-argument-parser" }
    expect(argParserItem != nil, "found swift-argument-parser")
    expectEq(argParserItem?.installedVersion, "1.5.0", "swift package version")
    expectEq(argParserItem?.healthStatus, .normal, "swift checkout is normal")

    // MARK: - Rust Project Scanner Test
    let tempRust = NSTemporaryDirectory() + "pharos-rust-test-\(UUID().uuidString)"
    let targetDir = tempRust + "/target"
    try? FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tempRust) }

    let cargoLock = """
    version = 4

    [[package]]
    name = "mock-rust-app"
    version = "0.1.0"

    [[package]]
    name = "serde"
    version = "1.0.210"
    source = "registry+https://github.com/rust-lang/crates.io-index"
    """
    FileManager.default.createFile(atPath: tempRust + "/Cargo.lock", contents: Data(cargoLock.utf8))
    FileManager.default.createFile(atPath: tempRust + "/Cargo.toml", contents: Data("[package]\nname = \"mock-rust-app\"".utf8))

    guard let rustSummary = PackageScanner.scanProjectDependencies(projectPath: tempRust) else {
        expect(false, "Failed to scan mock Rust project")
        return
    }
    expectEq(rustSummary.ecosystem, .rust, "rust ecosystem detected")
    expectEq(rustSummary.cacheDirectoryName, "target", "rust cache directory name is target")
    let serdeItem = rustSummary.packages.first { $0.name == "serde" }
    expect(serdeItem != nil, "found serde")
    expectEq(serdeItem?.installedVersion, "1.0.210", "serde version")
    expectEq(serdeItem?.healthStatus, .normal, "serde is normal because target exists")
}

func testCacheRepoScanner() {
    let repos = PackageScanner.scanCacheRepositories()
    expect(!repos.isEmpty, "Detected cache repositories on live machine")
    print("Detected \(repos.count) package caches: \(repos.map { "\($0.id) (\($0.name))" }.joined(separator: ", "))")

    for r in repos {
        expect(!r.id.isEmpty, "repo id not empty")
        expect(!r.rootPath.isEmpty, "repo root path not empty")
    }

    // Test directory size calculation
    let tempDir = NSTemporaryDirectory() + "pharos-cache-test-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: tempDir) }

    FileManager.default.createFile(atPath: tempDir + "/a.bin", contents: Data(repeating: 0x41, count: 500))
    FileManager.default.createFile(atPath: tempDir + "/b.bin", contents: Data(repeating: 0x42, count: 700))

    let (size, count) = PackageScanner.directorySize(at: tempDir)
    expectEq(count, 2, "2 files counted")
    expectEq(size, 1200, "1200 bytes total")
}
