// swift-tools-version: 6.0
import PackageDescription

let lang: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "Pharos",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PharosCore", swiftSettings: lang),
        .executableTarget(name: "Pharos", dependencies: ["PharosCore"], swiftSettings: lang),
        // Optional root helper for fan control; installed only from Settings.
        .executableTarget(name: "pharos-fand", dependencies: ["PharosCore"], swiftSettings: lang),
        .executableTarget(name: "pharos-tests", dependencies: ["PharosCore"], swiftSettings: lang),
    ]
)
