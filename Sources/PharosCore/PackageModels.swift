import Foundation

/// 软件与依赖包的技术生态
public enum PackageEcosystem: String, Codable, CaseIterable, Identifiable, Sendable {
    case node = "node"
    case python = "python"
    case java = "java"
    case rust = "rust"
    case go = "go"
    case swift = "swift"
    case homebrew = "homebrew"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .node: return "Node.js / npm"
        case .python: return "Python"
        case .java: return "Java / Maven"
        case .rust: return "Rust / Cargo"
        case .go: return "Go Modules"
        case .swift: return "SwiftPM"
        case .homebrew: return "Homebrew"
        }
    }

    public var iconName: String {
        switch self {
        case .node: return "hexagon.fill"
        case .python: return "terminal.fill"
        case .java: return "cup.and.saucer.fill"
        case .rust: return "gearshape.fill"
        case .go: return "arrow.right.circle.fill"
        case .swift: return "swift"
        case .homebrew: return "mug.fill"
        }
    }
}

/// 包的归属范围
public enum PackageScopeKind: String, Codable, Sendable {
    case globalCli          // 全局可执行命令行工具 (npm -g, cargo, brew bin)
    case projectDependency  // 项目本地依赖 (node_modules, .venv, pom.xml)
    case cacheRepository    // 本地缓存仓库 (pnpm store, npm cache, ~/.m2)
}

/// 依赖安装健康状态
public enum DependencyHealthStatus: String, Codable, Sendable {
    case normal             // 正常且版本匹配
    case missing            // 声明了但未安装 (缺少 node_modules 或包)
    case symlinkedWorkspace // 本地 monorepo 工作区互联软链接
    case mismatched         // 实际版本偏离声明区间
}

/// 单个依赖包或全局工具条目
public struct LocalPackageItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String                       // 唯一标识 (例如 "cli:grok" 或 "proj:quickdraw:react")
    public let name: String                     // 包名或指令名 (例如 "grok", "react", "fastapi")
    public let installedVersion: String?        // 实际落地安装版本 (例如 "1.0.50", "19.2.8")
    public let declaredVersion: String?         // 项目中声明的版本 (例如 "^19.1.0", "==0.136.3")
    public let ecosystem: PackageEcosystem      // 所属技术栈
    public let scope: PackageScopeKind          // 作用域 (全局 / 项目 / 缓存)
    public let healthStatus: DependencyHealthStatus // 健康状态
    public let summary: String?                 // 功能描述 / 摘要
    public let license: String?                 // 开源许可 (MIT, Apache-2.0 等)
    public let installPath: String              // 本地物理绝对路径
    public let executablePath: String?          // 针对 CLI 工具的可执行二进制路径 (如 ~/.nvm/.../bin/grok)
    public let fileSizeBytes: UInt64            // 占用磁盘体积
    public let lastModified: Date               // 最后变动时间
    public let projectName: String?             // 如果是项目依赖，记录所在项目名
    public let isDevDependency: Bool            // 是否为开发环境依赖 (devDependencies)
    public let isFeatured: Bool                 // 是否为用户重点关注的核心独立软件/AI工具
    public let categoryTag: String?             // 分类标签 (例如 "AI 助手", "开发构建", "包管理", "终端效率")

    public init(id: String,
                name: String,
                installedVersion: String?,
                declaredVersion: String? = nil,
                ecosystem: PackageEcosystem,
                scope: PackageScopeKind,
                healthStatus: DependencyHealthStatus = .normal,
                summary: String? = nil,
                license: String? = nil,
                installPath: String,
                executablePath: String? = nil,
                fileSizeBytes: UInt64 = 0,
                lastModified: Date = Date(),
                projectName: String? = nil,
                isDevDependency: Bool = false,
                isFeatured: Bool = false,
                categoryTag: String? = nil) {
        self.id = id
        self.name = name
        self.installedVersion = installedVersion
        self.declaredVersion = declaredVersion
        self.ecosystem = ecosystem
        self.scope = scope
        self.healthStatus = healthStatus
        self.summary = summary
        self.license = license
        self.installPath = installPath
        self.executablePath = executablePath
        self.fileSizeBytes = fileSizeBytes
        self.lastModified = lastModified
        self.projectName = projectName
        self.isDevDependency = isDevDependency
        self.isFeatured = isFeatured
        self.categoryTag = categoryTag
    }

    /// 根据包生态与物理落地形式生成的推荐终端卸载指令
    public var uninstallCommand: String {
        switch ecosystem {
        case .node:
            if installPath.contains("pnpm") {
                return "pnpm remove -g \(name)"
            } else if installPath.contains(".bun") {
                return "bun remove -g \(name)"
            } else if installPath.contains("yarn") {
                return "yarn global remove \(name)"
            } else {
                return "npm uninstall -g \(name)"
            }
        case .homebrew:
            if categoryTag?.contains("Cask") == true || installPath.contains("/Caskroom/") {
                return "brew uninstall --cask \(name)"
            }
            return "brew uninstall \(name)"
        case .rust:
            return "cargo uninstall \(name)"
        case .python:
            if executablePath?.contains(".local/bin") == true {
                return "uv tool uninstall \(name)"
            } else {
                return "pip uninstall -y \(name)"
            }
        case .go:
            return "rm -f \(executablePath ?? "~/go/bin/\(name)")"
        case .swift, .java:
            return "rm -f \(executablePath ?? installPath)"
        }
    }
}

/// 语言包缓存仓库概览
public struct PackageCacheRepoSummary: Identifiable, Codable, Equatable, Sendable {
    public let id: String                       // 仓库标识 (如 "pnpm-store", "maven-m2")
    public let name: String                     // 仓库名称 (如 "pnpm 全局硬链接仓库")
    public let ecosystem: PackageEcosystem      // 生态
    public let rootPath: String                 // 绝对路径
    public let fileSizeBytes: UInt64            // 总体积
    public let itemCount: Int                   // 缓存项数量
    public let description: String              // 说明

    public init(id: String,
                name: String,
                ecosystem: PackageEcosystem,
                rootPath: String,
                fileSizeBytes: UInt64,
                itemCount: Int,
                description: String) {
        self.id = id
        self.name = name
        self.ecosystem = ecosystem
        self.rootPath = rootPath
        self.fileSizeBytes = fileSizeBytes
        self.itemCount = itemCount
        self.description = description
    }
}

/// 单个开发项目的依赖聚合概览
public struct ProjectDependencySummary: Identifiable, Codable, Equatable, Sendable {
    public let id: String                       // 项目路径
    public let name: String                     // 项目名称
    public let rootPath: String                 // 项目根目录
    public let ecosystem: PackageEcosystem      // 主技术栈 (Node, Python, Java 等)
    public let dependenciesSizeBytes: UInt64    // node_modules, .venv, .build, target 等缓存与依赖体积
    public let directDependenciesCount: Int     // 声明依赖总数
    public let missingDependenciesCount: Int    // 缺失未安装数量
    public let packages: [LocalPackageItem]     // 具体依赖列表
    public let cacheDirectoryName: String?      // 缓存/依赖目录名 (如 "node_modules", ".venv", ".build", "target")

    public init(id: String,
                name: String,
                rootPath: String,
                ecosystem: PackageEcosystem,
                dependenciesSizeBytes: UInt64,
                directDependenciesCount: Int,
                missingDependenciesCount: Int,
                packages: [LocalPackageItem],
                cacheDirectoryName: String? = nil) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.ecosystem = ecosystem
        self.dependenciesSizeBytes = dependenciesSizeBytes
        self.directDependenciesCount = directDependenciesCount
        self.missingDependenciesCount = missingDependenciesCount
        self.packages = packages
        self.cacheDirectoryName = cacheDirectoryName
    }
}

extension ProjectDependencySummary {
    /// 核心主依赖包/文件夹名称（如 node_modules, .venv, .build, target）
    public var primaryBundleName: String {
        if let cache = cacheDirectoryName, !cache.isEmpty {
            return cache
        }
        switch ecosystem {
        case .node: return "node_modules"
        case .python: return ".venv"
        case .swift: return ".build"
        case .rust: return "target"
        case .java: return "target"
        default: return "dependencies"
        }
    }

    /// 核心主依赖包物理绝对路径
    public var primaryBundlePath: String {
        (rootPath as NSString).appendingPathComponent(primaryBundleName)
    }

    /// 核心主依赖包是否已在本地硬盘上生成/安装
    public var isBundleInstalled: Bool {
        FileManager.default.fileExists(atPath: primaryBundlePath)
    }
}

/// 项目依赖展示方式：大包模式 vs 详细清单展开模式
public enum PackageDepsDisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// 核心主依赖包模式：默认仅展示项目核心大包（如 node_modules / .venv），具体依赖列表折叠
    case bundleOnly
    /// 完整清单展开模式：默认直接展开所有具体依赖项列表
    case detailedList

    public var id: String { rawValue }
}

