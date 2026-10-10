// swift-tools-version: 6.0
import PackageDescription

let lang: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "UsageBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "UsageBarCore", swiftSettings: lang),
        .executableTarget(name: "UsageBar", dependencies: ["UsageBarCore"], swiftSettings: lang),
        .executableTarget(name: "usagebar-tests", dependencies: ["UsageBarCore"], swiftSettings: lang),
    ]
)
