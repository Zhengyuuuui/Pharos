# Pharos 本地依赖包与命令行工具管理模块开发规范 (PACKAGE_MANAGER_SPEC)

> **文档性质**：本文档基于 2026 年 10 月对当前 Mac 实机环境的深度探测结果编写，详细定义了 Pharos「本地依赖包与命令行工具管理」模块的业务需求、数据结构、扫描解析算法、UI 交互规范与验收标准，供后续 AI Agent / 开发者作为二次开发的完整实施指南。

---

## 1. 核心约束与技术规范（硬性遵守 `AGENTS.md`）

1. **纯 Apple 原生 Swift 语言**：
   - 严禁引入任何第三方依赖或 SPM 包（不得修改 `Package.swift` 引入第三方库）。
   - 全部功能使用 Foundation、SwiftUI、AppKit、UniformTypeIdentifiers 等 Apple 原生 SDK。
2. **内存管理规范**：
   - 优先使用 `struct` / `enum` 值类型建模（天然无引用计数泄漏风险）。
   - 类对象（如 `ObservableObject`）中的闭包、定时器或异步任务回调必须显式添加 `[weak self]`。
3. **架构分层清晰**：
   - 纯业务与扫描解析逻辑放在 `Sources/PharosCore/PackageScanner.swift`（无 UI 依赖、必须可被 `pharos-tests` 单元测试覆盖）。
   - 状态管理放在 `Sources/Pharos/PackageStore.swift`。
   - 视图组件放在 `Sources/Pharos/UI/PackageView.swift`。
   - 国际化文案统一收归 `Sources/Pharos/UI/L10n.swift`（同时提供 `en` 与 `zh-Hans`，禁止硬编码文字）。
4. **安全只读与性能原则**：
   - 默认**纯只读探测**，不得随意删除用户包或发起任何网络请求。
   - 采用高性能按需扫描与缓存，避免扫描大型目录卡顿 UI（项目 `node_modules` 仅扫描顶层一层，严禁无限制深层递归遍历全部子包）。

---

## 2. 实机探测环境与数据依据

经过对当前开发者 Mac 的实测探测，提取出以下准确特征与数据：

### 2.1 全局隐形 CLI 软件探测（实测数据）
通过 `npm install -g`、`pnpm add -g`、`cargo install`、`pip install` 安装的全局工具，二进制软链接集中分布在：
- `~/.nvm/versions/node/v22.23.0/bin/` 及 `lib/node_modules/`
- `~/.local/bin/`
- `/opt/homebrew/bin/`
- `~/Library/Python/3.13/bin/`
- `~/.cargo/bin/`
- `~/go/bin/`

| 命令行指令 | 对应源包 / 体系 | 实测版本 | 功能描述与特征 | 落地物理路径 |
| :--- | :--- | :--- | :--- | :--- |
| **`rea`** / **`rea-agents`** | `rea-agents` (npm global) | `v6.4.0` | 逆向工程与 Agent 分析套件 (MCP Server) | `~/.nvm/.../lib/node_modules/rea-agents` |
| **`grok`** (grokcli) | `@xai-official/grok` (npm global) | `v1.0.50` | xAI 官方终端 Grok 智能助手 CLI | `~/.nvm/.../lib/node_modules/@xai-official/grok` |
| **`claude`** | `@anthropic-ai/claude-code` | `v2.1.220` | Anthropic Claude Code 终端 Agent | `~/.nvm/.../lib/node_modules/@anthropic-ai/claude-code` |
| **`codebuddy`** / **`cbc`** | `@tencent-ai/codebuddy-code` | `v2.137.0` | 腾讯 AI CodeBuddy 终端智能助手 | `~/.nvm/.../lib/node_modules/@tencent-ai/codebuddy-code` |
| **`agent-browser`** | `agent-browser` (npm global) | `v0.27.0` | AI Agent 专用浏览器自动化驱动 | `~/.nvm/.../lib/node_modules/agent-browser` |
| **`wrangler`** / **`cf-wrangler`** | `wrangler` (npm global) | `v4.132.0` | Cloudflare Workers & 边缘管理 CLI | `~/.nvm/.../lib/node_modules/wrangler` |
| **`cargo-tauri`** | `tauri-cli` (Cargo Registry) | `v2.11.4` | 跨平台应用构建 CLI | `~/.cargo/bin/cargo-tauri` |
| **`uv`** / **`uvx`** | Astral `uv` | `v0.4.x` | 极速 Python 包与虚拟环境管理器 | `~/.local/bin/uv` |
| **`pdfplumber`** / **`pytesseract`** | Python Global Site | 最新 | PDF 解析与 OCR 识别 CLI 工具 | `~/Library/Python/3.13/bin/` |
| **`dlv`** | Go Delve | `v1.22.x` | Go 语言全局调试器 | `~/go/bin/dlv` |
| **`gh`** / **`rg`** / **`just`** | Homebrew Cellar | 最新 | GitHub CLI、ripgrep、just 执行器 | `/opt/homebrew/bin/` |

### 2.2 项目级 `node_modules` 与多语言项目依赖
实测探测到用户在 `~/Documents` 中有 **179 个** 现代项目工程，包含以下典型特征：
- **`saas/FastGPT`**：Monorepo，`node_modules` 体积 **2.3 GB**，使用 pnpm。
- **`newapi/new-api/web`**：前端项目，`node_modules` 体积 **3.0 GB**。
- **`quickdraw/quickdraw`**：Monorepo，`node_modules` 体积 **1.2 GB**，npm / workspaces。
- **`doubao2api`, `zai2api`**：包含 Python `.venv` 虚拟环境。
- **`life-kline-ios-commercial-latest`**：包含 Swift Package Manager (`Package.resolved`)。

### 2.3 语言本地缓存仓库
- **pnpm 全局硬链接存储**：`~/Library/pnpm`（**4.45 GB**）
- **npm 官方 tarball 下载缓存**：`~/.npm`（**2.0 GB**）
- **Python uv Wheel 预编译缓存**：`~/.cache/uv`（**762.8 MB**）
- **Rust Cargo 源码与 crate 缓存**：`~/.cargo/registry`（**453 MB**）
- **Java Maven 本地仓库**：`~/.m2/repository`（**65 MB**，143 个 jar 包）
- **Bun 缓存**：`~/.bun`（**62.9 MB**）
- **SwiftPM 缓存**：`~/Library/Caches/org.swift.swiftpm`
- **JDK 运行时**：同时安装有 `/opt/homebrew/opt/openjdk@17` 与 `openjdk@23`。

---

## 3. 数据模型设计 (`Sources/PharosCore/PackageModels.swift`)

```swift
import Foundation

/// 软件与依赖包的技术生态
public enum PackageEcosystem: String, Codable, CaseIterable, Identifiable {
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
        case .python: return "snake.fill"
        case .java: return "cup.and.saucer.fill"
        case .rust: return "gearshape.fill"
        case .go: return "arrow.right.circle.fill"
        case .swift: return "swift"
        case .homebrew: return "mug.fill"
        }
    }
}

/// 包的归属范围
public enum PackageScopeKind: String, Codable {
    case globalCli          // 全局可执行命令行工具 (npm -g, cargo, brew bin)
    case projectDependency  // 项目本地依赖 (node_modules, .venv, pom.xml)
    case cacheRepository    // 本地缓存仓库 (pnpm store, npm cache, ~/.m2)
}

/// 依赖安装健康状态
public enum DependencyHealthStatus: String, Codable {
    case normal             // 正常且版本匹配
    case missing            // 声明了但未安装 (缺少 node_modules 或包)
    case symlinkedWorkspace // 本地 monorepo 工作区互联软链接
    case mismatched         // 实际版本偏离声明区间
}

/// 单个依赖包或全局工具条目
public struct LocalPackageItem: Identifiable, Codable, Equatable {
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
}

/// 语言包缓存仓库概览
public struct PackageCacheRepoSummary: Identifiable, Codable {
    public let id: String                       // 仓库标识 (如 "pnpm-store", "maven-m2")
    public let name: String                     // 仓库名称 (如 "pnpm 全局硬链接仓库")
    public let ecosystem: PackageEcosystem      // 生态
    public let rootPath: String                 // 绝对路径
    public let fileSizeBytes: UInt64            // 总体积
    public let itemCount: Int                   // 缓存项数量
    public let description: String              // 说明
}

/// 单个开发项目的依赖聚合概览
public struct ProjectDependencySummary: Identifiable, Codable {
    public let id: String                       // 项目路径
    public let name: String                     // 项目名称
    public let rootPath: String                 // 项目根目录
    public let ecosystem: PackageEcosystem      // 主技术栈 (Node, Python, Java 等)
    public let dependenciesSizeBytes: UInt64    // node_modules 或 .venv 体积
    public let directDependenciesCount: Int     // 声明依赖总数
    public let missingDependenciesCount: Int    // 缺失未安装数量
    public let packages: [LocalPackageItem]     // 具体依赖列表
}
```

---

## 4. 扫描与元数据解析算法设计 (`Sources/PharosCore/PackageScanner.swift`)

### 4.1 全局 CLI 软件扫描 (`scanGlobalCliTools`)
1. **遍历三大核心目录**：
   - Node 全局目录：`~/.nvm/versions/node/*/bin/`，配合 `lib/node_modules/`。
   - 用户 Local 目录：`~/.local/bin/`。
   - Homebrew 目录：`/opt/homebrew/bin/`。
   - Cargo Bin 目录：`~/.cargo/bin/`。
   - Go Bin 目录：`~/go/bin/`。
2. **符号链接穿透**：
   - 若文件是符号链接（`URLResourceValues.isSymbolicLinkKey == true`），使用 `URL.resolvingSymlinksInPath()` 找到源文件。
   - 向上递归查找该源文件所属包的 `package.json`（对于 Node 工具）或 `.crates2.json`（对于 Cargo 工具）。
3. **JSON 快速解析**：
   - 读取并解码 `package.json` 中的 `name`, `version`, `description`, `license`, `bin`。
   - 组装为 `LocalPackageItem(scope: .globalCli)`。

### 4.2 项目级 `node_modules` 扫描 (`scanProjectDependencies`)
1. **项目定位**：
   - 优先复用 `ProjectStore.shared.projects` 中正在运行或已常驻的项目。
   - 补充快速探测 `~/Documents` 下一级或二级中含有 `package.json` 的目录。
2. **声明版本提取**：
   - 读取项目根目录的 `package.json`，提取 `dependencies` 与 `devDependencies` 字典。
3. **实际落地版本比对**：
   - 检查 `[projectRoot]/node_modules/[pkgName]/package.json`。
   - 若存在：
     - 如果为符号链接（软链接到 monorepo 内部包）：标记为 `.symlinkedWorkspace`。
     - 解析出真实 `version` 与 `license`，状态为 `.normal`。
   - 若不存在：
     - 状态标记为 `.missing`（红字警告：未执行 npm install）。
4. **性能保护**：
   - 严禁递归扫描 `node_modules` 内部每个深层嵌套文件夹；直接针对根 `package.json` 声明的列表进行定向探测，全项目解析在 50ms 内完成。

### 4.3 语言本地缓存仓库扫描 (`scanCacheRepositories`)
1. **pnpm Store**：探测 `~/Library/pnpm`，使用 `FileManager.default.attributesOfItem` 统计存储大小。
2. **npm Cache**：探测 `~/.npm`。
3. **uv Cache**：探测 `~/.cache/uv`。
4. **Maven Repository**：探测 `~/.m2/repository`，统计 `.jar` 数量及总大小。
5. **Cargo Registry**：探测 `~/.cargo/registry`。
6. **JDK 运行时**：枚举 `/opt/homebrew/opt/openjdk*`，读取 `release` 文件解析 `JAVA_VERSION`。

---

## 5. UI 架构与交互设计 (`Sources/Pharos/UI/PackageView.swift`)

### 5.1 侧边栏入口集成 (`MainWindowView.swift`)
在 `MainWindowView.swift` 侧边栏 `Overview` 分组中新增条目：
```swift
HStack {
    Label(l10n.packagesTitle, systemImage: "shippingbox.fill")
    Spacer()
    if store.globalCliCount > 0 {
        Text("\(store.globalCliCount)")
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.secondary)
    }
}
.tag(SidebarItem.packages)
```

### 5.2 主视图布局结构
主视图采用三段式分段切换（Segmented Picker）：
1. **⚡️ 全局 CLI 软件 (`Global CLI`)**：
   - 顶部指标卡：识别到的 CLI 工具总数、运行环境来源分布。
   - 搜索与技术栈筛选（全部 / Node / Homebrew / Python / Cargo / Go）。
   - 列表展示：指令名（加粗高亮）、版本 Badge、所属主包、一行描述、所在位置。
   - 选中详情卡：
     - 完整执行指令示例。
     - 「在 Finder 中定位」按钮。
     - 「在终端中测试」按钮（使用已有的终端启动辅助能力）。
2. **📁 项目依赖洞察 (`Project Dependencies`)**：
   - 顶部选择器：项目切换下拉菜单（展示当前项目名、技术栈、`node_modules` 总体积）。
   - 依赖健康卡片：生产依赖数、开发依赖数、缺失未装依赖数（如有标红）。
   - 列表项：包名、声明版本 vs 实际安装版本、开源协议标签、单包占用体积。
3. **🗄️ 语言缓存仓库 (`Cache Repositories`)**：
   - 集中卡片网格呈现：pnpm 存储 (4.5G)、npm 缓存 (2.0G)、uv 缓存 (760M)、Maven 本地库 (65M)、JDK 17/23 运行时。
   - 展示路径与占用空间条状图，提供快速定位按钮。

---

## 6. 国际化文案字典扩展 (`Sources/Pharos/UI/L10n.swift`)

必须同步在 `L10n.swift` 中增加中英文对照，禁止任何硬编码：

```swift
// MARK: - Package & Dependency Manager
public var packagesTitle: String { isZh ? "依赖与软件包" : "Packages & Dependencies" }
public var packagesSubtitle: String { isZh ? "全局命令行软件、项目依赖与语言缓存统一管理" : "Manage global CLI tools, project dependencies, and package caches" }
public var tabGlobalCli: String { isZh ? "全局 CLI 软件" : "Global CLI Tools" }
public var tabProjectDeps: String { isZh ? "项目依赖洞察" : "Project Dependencies" }
public var tabCacheRepos: String { isZh ? "语言缓存仓库" : "Cache Repositories" }
public var declaredVersion: String { isZh ? "声明版本" : "Declared" }
public var installedVersion: String { isZh ? "实际安装" : "Installed" }
public var statusMissing: String { isZh ? "未安装" : "Missing" }
public var statusNormal: String { isZh ? "已就绪" : "Ready" }
public var statusWorkspace: String { isZh ? "本地工作区" : "Workspace Link" }
public var revealInFinder: String { isZh ? "在 Finder 中显示" : "Reveal in Finder" }
public var testInTerminal: String { isZh ? "在终端测试运行" : "Test in Terminal" }
```

---

## 7. 验收测试规范

开发完成后，必须执行以下验收流程并全绿通过：
1. **代码编译通过**：
   ```bash
   swift build
   ```
2. **单元测试通过（新建 `PackageScannerTests.swift`）**：
   ```bash
   make test
   ```
   单测必须覆盖：
   - `testGlobalCliScanner`：验证能扫描出 `grok`、`rea-agents`、`claude` 等，字段不为空。
   - `testProjectDependencyScanner`：构造模拟的 `package.json` 与 `node_modules`，验证声明与安装版本比对、缺失判定。
   - `testCacheRepoScanner`：验证路径探测与格式解析逻辑正确。
3. **终端命令行自检**：
   ```bash
   .build/debug/Pharos --check
   ```
4. **打包与发布**：
   ```bash
   make install
   ```
   验证在 `/Applications/Pharos.app` 中正常打开，侧边栏能够平滑切换到「依赖与软件包」视图，无卡顿、无循环引用泄漏。
