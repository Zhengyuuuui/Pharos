import Darwin
import Foundation

extension PackageScanner {
    // MARK: - 2. 语言本地缓存仓库扫描 (scanCacheRepositories)

    public static func scanCacheRepositories(home: String = NSHomeDirectory()) -> [PackageCacheRepoSummary] {
        var repos: [PackageCacheRepoSummary] = []

        // 2.1 pnpm 全局硬链接存储库 (~/Library/pnpm)
        let pnpmPath = (home as NSString).appendingPathComponent("Library/pnpm")
        if FileManager.default.fileExists(atPath: pnpmPath) {
            let (size, count) = directorySize(at: pnpmPath)
            repos.append(PackageCacheRepoSummary(
                id: "pnpm-store",
                name: "pnpm 全局硬链接依赖仓库",
                ecosystem: .node,
                rootPath: pnpmPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "pnpm 全局内容可寻址存储区 (跨项目共享依赖，节省数 GB 空间)"
            ))
        }

        // 2.2 npm 官方 tarball 下载缓存 (~/.npm)
        let npmCachePath = (home as NSString).appendingPathComponent(".npm")
        if FileManager.default.fileExists(atPath: npmCachePath) {
            let (size, count) = directorySize(at: npmCachePath)
            repos.append(PackageCacheRepoSummary(
                id: "npm-cache",
                name: "npm 官方模块下载缓存",
                ecosystem: .node,
                rootPath: npmCachePath,
                fileSizeBytes: size,
                itemCount: count,
                description: "npm 安装包 tarball 下载、_cacache 内容寻址与元数据缓存"
            ))
        }

        // 2.3 Python uv Wheel 预编译缓存 (~/.cache/uv)
        let uvCachePath = (home as NSString).appendingPathComponent(".cache/uv")
        if FileManager.default.fileExists(atPath: uvCachePath) {
            let (size, count) = directorySize(at: uvCachePath)
            repos.append(PackageCacheRepoSummary(
                id: "uv-cache",
                name: "Python uv 预编译 Wheel 缓存",
                ecosystem: .python,
                rootPath: uvCachePath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Astral uv 快速编译构建的 Python wheels 与 HTTP 元数据缓存"
            ))
        }

        // 2.4 Java Maven 本地仓库 (~/.m2/repository)
        let mavenPath = (home as NSString).appendingPathComponent(".m2/repository")
        if FileManager.default.fileExists(atPath: mavenPath) {
            let (size, count) = directorySize(at: mavenPath)
            repos.append(PackageCacheRepoSummary(
                id: "maven-m2",
                name: "Java Maven 本地构件库",
                ecosystem: .java,
                rootPath: mavenPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Maven / Gradle 下载的依赖 Jar 包、POM 规范文件与插件库"
            ))
        }

        // 2.5 Rust Cargo 注册源与源码缓存 (~/.cargo/registry)
        let cargoRegistryPath = (home as NSString).appendingPathComponent(".cargo/registry")
        if FileManager.default.fileExists(atPath: cargoRegistryPath) {
            let (size, count) = directorySize(at: cargoRegistryPath)
            repos.append(PackageCacheRepoSummary(
                id: "cargo-registry",
                name: "Rust Cargo 注册源与 Crate 缓存",
                ecosystem: .rust,
                rootPath: cargoRegistryPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "crates.io 索引克隆、crate 解压源码及本地打包构建元数据"
            ))
        }

        // 2.6 Bun 模块缓存 (~/.bun)
        let bunPath = (home as NSString).appendingPathComponent(".bun")
        if FileManager.default.fileExists(atPath: bunPath) {
            let (size, count) = directorySize(at: bunPath)
            repos.append(PackageCacheRepoSummary(
                id: "bun-cache",
                name: "Bun 运行时与安装包缓存",
                ecosystem: .node,
                rootPath: bunPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Bun 快速安装包二进制缓存与锁文件索引"
            ))
        }

        // 2.7 SwiftPM 构件缓存 (~/Library/Caches/org.swift.swiftpm)
        let swiftpmPath = (home as NSString).appendingPathComponent("Library/Caches/org.swift.swiftpm")
        if FileManager.default.fileExists(atPath: swiftpmPath) {
            let (size, count) = directorySize(at: swiftpmPath)
            repos.append(PackageCacheRepoSummary(
                id: "swiftpm-cache",
                name: "SwiftPM 源码与清单缓存",
                ecosystem: .swift,
                rootPath: swiftpmPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Swift Package Manager Git 仓库克隆镜像与 Package.swift 清单缓存"
            ))
        }

        // 2.8 OpenJDK 运行时探测 (/opt/homebrew/opt/openjdk*)
        let optHomebrew = "/opt/homebrew/opt"
        if let dirs = try? FileManager.default.contentsOfDirectory(atPath: optHomebrew) {
            for d in dirs where d.hasPrefix("openjdk") {
                let fullPath = (optHomebrew as NSString).appendingPathComponent(d)
                var version = d
                // 读取 release 文件获取精准 JAVA_VERSION
                let releaseFile = "\(fullPath)/libexec/openjdk.jdk/Contents/Home/release"
                if let content = try? String(contentsOfFile: releaseFile, encoding: .utf8) {
                    for line in content.components(separatedBy: "\n") {
                        if line.hasPrefix("JAVA_VERSION=") {
                            version = line.replacingOccurrences(of: "JAVA_VERSION=", with: "")
                                .replacingOccurrences(of: "\"", with: "")
                                .trimmingCharacters(in: .whitespaces)
                            break
                        }
                    }
                }
                let (size, count) = directorySize(at: fullPath)
                repos.append(PackageCacheRepoSummary(
                    id: "jdk-\(d)",
                    name: "OpenJDK 运行时 (\(version))",
                    ecosystem: .java,
                    rootPath: fullPath,
                    fileSizeBytes: size,
                    itemCount: count,
                    description: "本地已安装的 Java 开发套件环境与标准库模块"
                ))
            }
        }

        // 2.9 Homebrew 下载与 Bottle 缓存 (~/Library/Caches/Homebrew)
        let brewCachePath = (home as NSString).appendingPathComponent("Library/Caches/Homebrew")
        if FileManager.default.fileExists(atPath: brewCachePath) {
            let (size, count) = directorySize(at: brewCachePath)
            repos.append(PackageCacheRepoSummary(
                id: "homebrew-cache",
                name: "Homebrew 下载与 Bottle 缓存",
                ecosystem: .homebrew,
                rootPath: brewCachePath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Homebrew 安装包 (Bottles / Casks / 源码 tarball) 与 API 元数据缓存"
            ))
        }

        // 2.10 pip 预编译 Wheel 与源码缓存 (~/Library/Caches/pip, ~/.cache/pip)
        let pipPaths = [
            (home as NSString).appendingPathComponent("Library/Caches/pip"),
            (home as NSString).appendingPathComponent(".cache/pip")
        ]
        for p in pipPaths where FileManager.default.fileExists(atPath: p) {
            let (size, count) = directorySize(at: p)
            if size > 0 || count > 0 {
                repos.append(PackageCacheRepoSummary(
                    id: "pip-cache",
                    name: "Python pip 预编译 Wheel 缓存",
                    ecosystem: .python,
                    rootPath: p,
                    fileSizeBytes: size,
                    itemCount: count,
                    description: "pip 下载的 Python 预构建轮子 (Wheels) 与 tar.gz 源码包缓存"
                ))
                break
            }
        }

        // 2.11 Gradle 依赖构件与守护进程缓存 (~/.gradle/caches)
        let gradlePath = (home as NSString).appendingPathComponent(".gradle/caches")
        if FileManager.default.fileExists(atPath: gradlePath) {
            let (size, count) = directorySize(at: gradlePath)
            repos.append(PackageCacheRepoSummary(
                id: "gradle-cache",
                name: "Gradle 依赖与构建缓存",
                ecosystem: .java,
                rootPath: gradlePath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Gradle 构建下载的 Jar 构件、解压文件与编译守护进程缓存"
            ))
        }

        // 2.12 Go 编译与模块缓存 (~/Library/Caches/go-build, ~/go/pkg/mod)
        let goBuildPath = (home as NSString).appendingPathComponent("Library/Caches/go-build")
        if FileManager.default.fileExists(atPath: goBuildPath) {
            let (size, count) = directorySize(at: goBuildPath)
            repos.append(PackageCacheRepoSummary(
                id: "go-build-cache",
                name: "Go 编译构建缓存",
                ecosystem: .go,
                rootPath: goBuildPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Go 编译器生成的预编译包对象与操作哈希缓存"
            ))
        }
        let goModCandidates = [
            (home as NSString).appendingPathComponent("go/pkg/mod"),
            (home as NSString).appendingPathComponent("Library/Caches/go-mod")
        ]
        for gmp in goModCandidates where FileManager.default.fileExists(atPath: gmp) {
            let (size, count) = directorySize(at: gmp)
            if size > 0 || count > 0 {
                repos.append(PackageCacheRepoSummary(
                    id: "go-mod-cache",
                    name: "Go Modules 源码与校验缓存",
                    ecosystem: .go,
                    rootPath: gmp,
                    fileSizeBytes: size,
                    itemCount: count,
                    description: "go get / go build 下载的第三方模块源码镜像与校验缓存"
                ))
                break
            }
        }

        // 2.13 CocoaPods 仓库与源码缓存 (~/Library/Caches/CocoaPods)
        let cocoapodsPath = (home as NSString).appendingPathComponent("Library/Caches/CocoaPods")
        if FileManager.default.fileExists(atPath: cocoapodsPath) {
            let (size, count) = directorySize(at: cocoapodsPath)
            repos.append(PackageCacheRepoSummary(
                id: "cocoapods-cache",
                name: "CocoaPods 仓库与源码缓存",
                ecosystem: .swift,
                rootPath: cocoapodsPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "CocoaPods Specs Git 索引镜像与第三方 Pod 源码压缩包缓存"
            ))
        }

        return repos.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
    }

}
