# Pharos 浏览器与 Clash/Mihomo 网络代理协同控制规格书
# (Browsers & Clash Network Proxy Integration Specification)

> **文档版本**：v1.0.0  
> **适用系统**：macOS 14.0+ (Sonoma / Sequoia / Tahoe)  
> **核心原则**：纯 Apple 原生 Swift 栈（零第三方依赖）、严格遵循 ARC 内存安全与 `AGENTS.md` 规范、支持商业化闭环设计。  
> **本文档目标**：为后续 AI Agent / 开发者提供完整、可直接落地执行的架构设计、主流 Mihomo 客户端兼容矩阵、底层通信协议、UI/交互规范及逐步施工清单。

---

## 一、需求背景与产品愿景

### 1.1 开发者真实日常痛点
在全栈开发、AI Agent 开发与日常工程调试中，开发者普遍面临以下两难困境：
1. **海外 API / AI 服务 / 文档检索（必须走代理）**：
   - 调试 OpenAI、Anthropic、Cloudflare、HuggingFace、GitHub 接口，或查阅外网文档时，必须依赖 Clash 的 **规则模式 (Rule)** 或 **全局模式 (Global)**。
2. **本地服务 / 微服务 / WebHook 调试（必须彻底无代理）**：
   - 调试本地运行的 `localhost:3000`、`127.0.0.1:8080`、内网 Docker 容器、Vite/Next.js 开发服务器，或者国内银行/政企接口时，如果系统或浏览器挂着代理，**极易出现 SSL 证书握手失败、CORS 跨域异常、本地请求被错误分流至海外 VPS 导致 403 / 502，或者延迟畸高**。
3. **痛点交织与频繁割裂**：
   - 开发者目前被迫在第三方客户端菜单栏（如 Clash Verge、Mihomo Party 等）频繁点击切换模式；
   - 无法轻松做到「**浏览器 A（调试本地）走直连无代理，浏览器 B（查海外资料/AI）走 Clash 规则**」的隔离环境。

### 1.2 解决方案与产品定位
在 Pharos 现有的 **「浏览器实例」** 板块进行**升级重构与深度整合**：
- **入口展现**：将左侧导航栏的 **「浏览器实例 (Chrome)」** 重命名升级为 **「浏览器与代理网络 (Browsers & Network Proxy)」**。
- **一体化能力**：
  1. **顶部 Clash / Mihomo 实时网络控制台**：自动探查本地运行的主流 Mihomo 客户端，毫秒级切换 **「规则模式 (Rule)」/「直连模式 (Direct)」/「全局模式 (Global)」**，实时查看代理端口与流量。
  2. **浏览器实例级代理策略矩阵**：支持一键将特定 Chromium 浏览器（Chrome、Edge、Brave 等）以 **「纯净直连 (`direct://`)」** 或 **「跟随 Clash (`127.0.0.1:7890`)」** 启动，实现不同工作窗口的网络彻底隔离。
  3. **终端代理环境一键复制**：提供一键复制 `export http_proxy` 与 `unset` 终端配置。

---

## 二、主流 Mihomo (Clash Meta) 客户端兼容矩阵

经深度调研与 Wiki 规范核对，macOS 上所有基于 **Mihomo (MetaCubeX)** 内核的主流客户端均实现标准的 **Clash External Controller REST API**，但在通信管道（Unix Domain Socket vs HTTP TCP 端口）、配置文件路径及默认端口上存在差异。Pharos 必须实现**全量自动探测与适配**：

| 客户端名称 | 应用主路径 (`/Applications`) | 配置与数据目录 (`Application Support` / `~/.config`) | 默认外部控制通道 (External Controller) | 默认混合代理端口 (Mixed Port) | Secret 凭证获取逻辑 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Mihomo Party / Clash Party** (本机实测) | `Clash Party.app` / `Mihomo Party.app` | `~/Library/Application Support/mihomo-party` | **Unix Domain Socket**：`/tmp/mihomo-party-<uid>-<pid>.sock` (免凭据鉴权) 或 `127.0.0.1:9090` | `7890` (SOCKS `7891`, HTTP `7892`) | Socket 访问无需 secret；若走 HTTP，解析 `config.yaml` 或 `mihomo.yaml` 中的 `secret` |
| **Clash Verge Rev** (最主流开源桌面端) | `Clash Verge.app` / `Clash Verge Rev.app` | `~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev` | **HTTP REST**：`127.0.0.1:9097` (或 `9090`)，或 `/tmp/verge-*.sock` | `7897` (默认) 或 `7890` | 从 `verge.yaml` 读取 `verge_external_controller_port` 与 `verge_clash_secret` |
| **Clash Nyanpasu** (Tauri 跨平台端) | `Clash Nyanpasu.app` | `~/Library/Application Support/mo.yanpasu.clash-nyanpasu` | **HTTP REST**：`127.0.0.1:9090` | `7890` | 解析 `config.yaml` 中的 `secret` 字段 |
| **ClashX.Meta / ClashX Pro** | `ClashX.Meta.app` / `ClashX Pro.app` | `~/.config/clash.meta` 或 `~/.config/clash` | **HTTP REST**：`127.0.0.1:9090` | `7890` | 解析 `~/.config/clash.meta/config.yaml` 中的 `secret` 字段 |
| **Flclash** | `Flclash.app` | `~/Library/Application Support/com.flclash.flclash` | **HTTP REST**：`127.0.0.1:9090` | `7890` | 解析内部 `config.yaml` |
| **Mihomo CLI / ShellCrash / Homebrew** | `/opt/homebrew/bin/mihomo` / `/usr/local/bin/mihomo` | `~/.config/mihomo` | **HTTP REST**：`127.0.0.1:9090` | `7890` | 解析 `~/.config/mihomo/config.yaml` |

---

## 三、底层通信协议与 API 规范

通信引擎应支持 **双通道通信架构**（优先探测并使用 Unix Domain Socket，若无则使用标准 `URLSession` 请求 127.0.0.1 本地端口）。

### 3.1 鉴权规范
当通过 HTTP 端口通信时，必须在请求头附加：
```http
Authorization: Bearer <secret>
```
*注：若 `secret` 为空字符串或使用本地 Unix Domain Socket 通信，则无需携带 `Authorization` 头。*

### 3.2 核心 REST API 接口清单

#### 1. 获取核心状态与模式 (`GET /configs`)
- **请求**：`GET /configs`
- **响应**：
  ```json
  {
    "port": 7892,
    "socks-port": 7891,
    "mixed-port": 7890,
    "mode": "rule",        // 当前模式: "rule" | "global" | "direct" | "script"
    "log-level": "info",
    "tun": {
      "enable": true,
      "device": "utun1500"
    }
  }
  ```

#### 2. 毫秒级热切换模式 (`PATCH /configs`)
- **请求**：`PATCH /configs`
- **请求体 (JSON)**：
  ```json
  {
    "mode": "direct"     // 可切换为: "rule" | "direct" | "global"
  }
  ```
- **响应**：`204 No Content` 即表示切换成功，内核立即生效，无需重启进程。

#### 3. 获取代理节点组与延迟 (`GET /proxies`)
- **请求**：`GET /proxies`
- **响应**：包含 `GLOBAL`、`Proxy`、各分流策略组及当前选中的出站节点名称（`now`）与历史延迟数组。

#### 4. 切换策略组选定节点 (`PUT /proxies/{group_name}`)
- **请求**：`PUT /proxies/Proxy`
- **请求体 (JSON)**：
  ```json
  {
    "name": "香港 01 [BGP]"
  }
  ```

#### 5. 实时连接与速率 (`GET /traffic` 与 `GET /connections`)
- **流量速率**：`GET /traffic` 返回当前每秒上行与下行字节数 (`up`, `down`)。
- **重置所有活跃连接**：`DELETE /connections`，当开发者从代理切回直连时，调用此接口可瞬时切断旧的长连接，确保新请求立即走直连通道。

---

## 四、浏览器与网络代理隔离架构 (Browser Proxy Isolation)

macOS 的 Chromium 系浏览器（Google Chrome、Microsoft Edge、Brave、Chromium 等）原生提供高度强大的命令行参数机制，允许**单个浏览器窗口/配置目录具备完全独立的网络代理栈**，不受系统全局代理与其它窗口影响：

```
┌────────────────────────────────────────────────────────────────────────┐
│                        macOS 系统网络栈                                  │
│                                                                        │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │   Clash / Mihomo Core (TUN utun1500 或 127.0.0.1:7890)        │     │
│   │   [当前模式: 规则 Rule / 全局 Global]                           │     │
│   └──────────────────────────────┬───────────────────────────────┘     │
│                                  │                                     │
│         ▲                        │ 7890                                │
│         │ direct:// (强制绕过)    │                                     │
│         │                        ▼                                     │
│  ┌──────────────┐        ┌──────────────┐        ┌──────────────┐      │
│  │  Browser A   │        │  Browser B   │        │  Browser C   │      │
│  │ [本地开发]   │        │ [AI 与研报]   │        │ [默认配置]   │      │
│  │  纯净直连    │        │  强制走代理  │        │  跟随系统    │      │
│  │ localhost    │        │ Claude/GPT   │        │ 普通日常浏览 │      │
│  └──────────────┘        └──────────────┘        └──────────────┘      │
└────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Chromium 关键启动参数规范

1. **强制纯净直连模式 (Direct / No Proxy)**：
   ```bash
   open -na "/Applications/Google Chrome.app" --args \
     --user-data-dir="/Users/<user>/Library/Application Support/Pharos/ChromeDev" \
     --proxy-server="direct://" \
     --no-proxy-server
   ```
   - **效果**：该浏览器实例发出的所有 HTTP/HTTPS/WebSocket 请求 100% 直连目标 IP，绝不经过 `127.0.0.1:7890`，彻底根治本地 `127.0.0.1` 调试被代理劫持的问题。

2. **强制代理模式 (Force Proxy)**：
   ```bash
   open -na "/Applications/Google Chrome.app" --args \
     --user-data-dir="/Users/<user>/Library/Application Support/Pharos/ChromeAI" \
     --proxy-server="http://127.0.0.1:7890" \
     --proxy-bypass-list="<local>;localhost;127.0.0.1;*.local"
   ```
   - **效果**：所有外网请求强制流入 Clash，享受规则分流或节点加速，同时将本地地址列入绕行白名单。

3. **跟随系统模式 (Follow System)**：
   - 不附加 `--proxy-server` 参数，完全遵循当前 macOS 系统网络设置。

---

## 五、系统架构设计与模块分层

根据 `AGENTS.md` 规范，所有业务逻辑放 `Sources/PharosCore/`（纯 Swift，可单测），状态管理放 `Sources/Pharos/`，视图组件放 `Sources/Pharos/UI/`。

```
Sources/
├── PharosCore/
│   ├── ClashController.swift        # [新增] Mihomo/Clash 进程探测、Socket/REST 客户端、配置与模式解析
│   ├── ClashModels.swift             # [新增] ClashConfig, ProxyGroup, ProxyMode, ProxyTraffic 值类型模型
│   └── ChromeInstances.swift         # [扩展] 扩充 ProxyStrategy 枚举 (.direct, .clash, .custom, .system)
│
├── Pharos/
│   ├── ClashStore.swift              # [新增] @MainActor 代理网络状态单例，定时刷新/切模/测速
│   └── ChromeStore.swift             # [扩展] 实例与代理策略的联动持久化
│
├── Pharos/UI/
│   ├── BrowserNetworkView.swift      # [重构升级] 原 ChromeView.swift 升级为全新综合控制台
│   ├── ClashDashboardSection.swift   # [新增] Clash 状态卡片、模式分段器、端口指示灯、流量仪表
│   ├── BrowserProxyMatrixSection.swift # [新增] 浏览器代理策略配置卡片与一键直连/代理启动按钮
│   ├── L10n.swift                    # [新增] 补充网络与代理双语文案
│   └── MainWindowView.swift          # [更新] 侧边栏名称由「浏览器实例」更新为「浏览器与代理网络」
│
└── pharos-tests/
    ├── ClashControllerTests.swift    # [新增] 客户端探测、API 解析、模式切换构造全量单测
    └── main.swift                    # [更新] 注册新增测试
```

---

## 六、UI 与交互规格设计

### 6.1 侧边栏更新
- **标识符**：`SidebarItem.browsersAndNetwork`（原 `SidebarItem.chrome`）
- **图标**：`globe.asia.australia.fill` 或 `network`
- **中文名称**：`浏览器与代理网络`
- **英文名称**：`Browsers & Proxy`

### 6.2 页面布局结构（`BrowserNetworkView`）
整体页面采用 Pharos 标准的 `PharosPage` 结构，自上而下分为三大卡片区：

```
┌────────────────────────────────────────────────────────────────────────┐
│  PharosPageHeader: 浏览器与代理网络 (Browsers & Network Proxy)          │
│  副标题: 控制本机 Mihomo/Clash 运行模式，为不同浏览器配置独立的网络代理环境     │
└────────────────────────────────────────────────────────────────────────┘

┌─ 1. Clash / Mihomo 实时网络控制中心 (ClashDashboardSection) ────────────┐
│  ┌──────────────┐  客户端: Clash Party (Mihomo Core)  [● 运行中]        │
│  │   网络雷达   │  混合端口: 7890 | SOCKS: 7891 | TUN 模式: 开启        │
│  │    图标      │  实时流量: ↑ 12.4 KB/s  ↓ 248.6 KB/s                   │
│  └──────────────┘                                                      │
│  --------------------------------------------------------------------  │
│  当前路由模式:                                                         │
│  ┌───────────────────────┬───────────────────────┬──────────────────┐  │
│  │   规则模式 (Rule)     │   直连模式 (Direct)   │  全局模式(Global)│  │
│  │   [ 智能海外分流 ]    │   [ 本地纯净无代理 ]  │  [ 强制走代理 ]  │  │
│  └───────────────────────┴───────────────────────┴──────────────────┘  │
│  快捷操作: [一键切断所有活跃连接]  [复制终端 export http_proxy 命令]       │
└────────────────────────────────────────────────────────────────────────┘

┌─ 2. 浏览器网络策略快速矩阵 (BrowserProxyMatrixSection) ────────────────┐
│  为不同的开发与调研场景一键启动带独立网络栈的浏览器实例：                 │
│                                                                        │
│  ┌─────────────────────────┐        ┌─────────────────────────┐        │
│  │ ⚡ 本地调试浏览器 (Chrome)│        │ 🌐 海外研报/AI 浏览器    │        │
│  │ 模式: 强制直连 (direct://)│        │ 模式: Clash 代理 (7890) │        │
│  │ 绝不走代理, 本地端口秒开│        │ 享受规则分流, 访问 API  │        │
│  │ [ 一键直连启动 ]        │        │ [ 一键代理启动 ]        │        │
│  └─────────────────────────┘        └─────────────────────────┘        │
└────────────────────────────────────────────────────────────────────────┘

┌─ 3. 运行中与预设浏览器实例 (现有 Chromium 列表增强) ────────────────────┐
│  (保留现有 ChromeView 实例卡片，每张卡片右侧新增代理状态胶囊 Badge:     │
│   [直连 Direct] 或 [代理 :7890]，并支持在编辑抽屉中直接切换代理策略)     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 七、数据结构与核心接口设计 (Swift 代码参考)

### 7.1 核心数据结构 (`Sources/PharosCore/ClashModels.swift`)

```swift
import Foundation

/// 代理路由模式
public enum ClashRoutingMode: String, CaseIterable, Sendable, Codable {
    case rule = "rule"
    case direct = "direct"
    case global = "global"
    case script = "script"

    public var localizedKey: String {
        switch self {
        case .rule: return "clashModeRule"
        case .direct: return "clashModeDirect"
        case .global: return "clashModeGlobal"
        case .script: return "clashModeScript"
        }
    }
}

/// 本地检测到的 Clash 客户端类型
public enum ClashClientKind: String, Sendable, CaseIterable {
    case mihomoParty = "Mihomo Party"
    case clashVerge = "Clash Verge Rev"
    case clashNyanpasu = "Clash Nyanpasu"
    case clashX = "ClashX.Meta"
    case flclash = "Flclash"
    case genericMihomo = "Mihomo Core"

    public var iconName: String {
        switch self {
        case .mihomoParty: return "party.popper.fill"
        case .clashVerge: return "shield.lefthalf.filled"
        case .clashNyanpasu: return "cat.fill"
        case .clashX: return "paperplane.fill"
        case .flclash: return "bolt.shield.fill"
        case .genericMihomo: return "network"
        }
    }
}

/// 浏览器代理策略
public enum BrowserProxyStrategy: Hashable, Sendable, Codable {
    case followSystem                    // 跟随系统/Clash
    case direct                          // 强制直连 (direct://)
    case clashMixedPort(Int)             // 强制走指定 Clash 端口 (如 7890)
    case custom(String)                  // 自定义代理服务器 URL
}

/// 综合状态快照
public struct ClashStatusSnapshot: Sendable, Equatable {
    public let isRunning: Bool
    public let clientKind: ClashClientKind?
    public let mode: ClashRoutingMode
    public let mixedPort: Int
    public let socksPort: Int
    public let httpPort: Int
    public let isTunEnabled: Bool
    public let uploadBytesPerSec: UInt64
    public let downloadBytesPerSec: UInt64
    public let activeConnectionCount: Int
    public let controllerEndpoint: String

    public init(
        isRunning: Bool = false,
        clientKind: ClashClientKind? = nil,
        mode: ClashRoutingMode = .rule,
        mixedPort: Int = 7890,
        socksPort: Int = 7891,
        httpPort: Int = 0,
        isTunEnabled: Bool = false,
        uploadBytesPerSec: UInt64 = 0,
        downloadBytesPerSec: UInt64 = 0,
        activeConnectionCount: Int = 0,
        controllerEndpoint: String = ""
    ) {
        self.isRunning = isRunning
        self.clientKind = clientKind
        self.mode = mode
        self.mixedPort = mixedPort
        self.socksPort = socksPort
        self.httpPort = httpPort
        self.isTunEnabled = isTunEnabled
        self.uploadBytesPerSec = uploadBytesPerSec
        self.downloadBytesPerSec = downloadBytesPerSec
        self.activeConnectionCount = activeConnectionCount
        self.controllerEndpoint = controllerEndpoint
    }
}
```

### 7.2 核心探针与控制器接口 (`Sources/PharosCore/ClashController.swift`)

```swift
public enum ClashController {
    /// 自动探测正在运行的客户端类型与 Controller 连接通道 (Socket 或 HTTP)
    public static func detectActiveEndpoint() -> (endpoint: String, isSocket: Bool, secret: String?, kind: ClashClientKind)?

    /// 获取核心配置
    public static func fetchConfig(endpoint: String, isSocket: Bool, secret: String?) async throws -> (mode: ClashRoutingMode, mixedPort: Int, isTun: Bool)

    /// 毫秒级热切换模式 (Rule / Direct / Global)
    public static func switchMode(_ mode: ClashRoutingMode, endpoint: String, isSocket: Bool, secret: String?) async throws -> Bool

    /// 切断所有已有连接（确保切模后连接迅速迁移）
    public static func closeAllConnections(endpoint: String, isSocket: Bool, secret: String?) async throws -> Bool
}
```

---

## 八、逐步实施清单 (供后续 Agent 直接执行)

后续负责落地的 Agent 应按如下有序步骤推进实现，每步均需自检确保编译通过：

### 阶段 1：核心逻辑与单测 (`PharosCore` + `pharos-tests`)
1. [ ] **创建 `Sources/PharosCore/ClashModels.swift`**：
   - 包含 `ClashRoutingMode`、`ClashClientKind`、`BrowserProxyStrategy` 与 `ClashStatusSnapshot`。
2. [ ] **创建 `Sources/PharosCore/ClashController.swift`**：
   - 实现客户端进程探测（检查 `/Applications` 及 `ps` 输出）。
   - 实现 Unix Domain Socket 与 HTTP REST 请求（纯原生 `URLSession` / `NWConnection`，零第三方库）。
   - 实现 `fetchConfig`、`switchMode`、`closeAllConnections`。
3. [ ] **扩展 `Sources/PharosCore/ChromeInstances.swift`**：
   - 增加 `--proxy-server="direct://"` 等参数生成函数。
4. [ ] **编写单测 `Sources/pharos-tests/ClashControllerTests.swift`**：
   - 测试配置 JSON 解码、请求体拼装、不同客户端端口匹配。
   - 在 `Sources/pharos-tests/main.swift` 中注册并运行，确保 `make test` 全绿。

### 阶段 2：状态管理 (`Pharos` App 运行时)
5. [ ] **创建 `Sources/Pharos/ClashStore.swift`**：
   - `@MainActor final class ClashStore: ObservableObject` 单例。
   - 前台 2 秒轮询，后台或未激活时暂停或降频。
   - 提供 `switchMode(_:)`、`refresh()`、`copyTerminalProxySnippet()` 等方法。
6. [ ] **扩展 `Sources/Pharos/ChromeStore.swift`**：
   - 增加按预设策略（直连 vs 代理）启动浏览器的便捷方法。

### 阶段 3：UI 改造与双语国际化
7. [ ] **修改 `Sources/Pharos/UI/L10n.swift`**：
   - 增加中英双语词条（`browsersAndNetwork`、`clashControlHub`、`clashModeRule`、`clashModeDirect`、`clashModeGlobal`、`directNoProxyTitle`、`directNoProxyDesc` 等）。
8. [ ] **重构 `Sources/Pharos/UI/ChromeView.swift`**（或升级为 `BrowserNetworkView.swift`）：
   - 顶部增加 `ClashDashboardSection`（运行状态、切模分段器、端口）。
   - 中间增加 `BrowserProxyMatrixSection`（直连启动 vs 代理启动快速卡片）。
   - 下方保留并增强浏览器实例列表。
9. [ ] **更新 `Sources/Pharos/UI/MainWindowView.swift`**：
   - 更新侧边栏枚举及显示文案为「浏览器与代理网络 (Browsers & Proxy)」。

### 阶段 4：质量自检与提交
10. [ ] 运行 `swift build` 验证零编译警告。
11. [ ] 运行 `make test` 确保全量断言通过。
12. [ ] 运行 `make app` 与 `make install` 验证打包签名正常。
13. [ ] 更新 `README.md` 与 `README_CN.md`。

---

*（本文档已归档至 `docs/CLASH_AND_BROWSER_NETWORK_SPEC.md`，可作为后续二次开发与自动化施工的唯一基准。）*
