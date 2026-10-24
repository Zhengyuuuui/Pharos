# Changelog / 更新记录

All notable changes to Pharos are documented in this file.
Pharos 的全部版本演进与发布记录均归档于此。

Times are UTC+8. 时间为北京时间（UTC+8）。

---

## 目录 / Quick Links
- [v3.0 (2026-10-24)](#v30--2026-10-24-0840) — Global Design System Overhaul, Domain-Categorized Pure Sidebar & Adaptive Anti-Squeezing Popover Customizer / 全局设计系统规范落地、领域分类纯净侧边栏与自适应防挤压小组件布局
- [v2.9 (2026-10-23)](#v29--2026-10-23-1546) — Persistent Lid-Closed Battery Guard, SMC Write Deduplication, Incremental Scanners & Modular Architecture / 电池合盖持续守护、SMC 写入去重、增量扫描缓存与模块化重构
- [v2.8 (2026-10-19)](#v28--2026-10-19-1320) — Automotive Cockpit Speedometer & 60FPS Mechanical Inertia Engine / 拟真机车仪表盘风扇座舱与 60FPS 物理惯性引擎
- [v2.7 (2026-10-19)](#v27--2026-10-19-0935) — Homebrew & Package Discovery, AI Chat Manual App Addition / 真实 Homebrew 管理、多工作区发现与 AI 对话手动添加
- [v2.6 (2026-10-17)](#v26--2026-10-17-1506) — AI Chat Detail Separation & Safe Delete / AI 对话详情独立与安全删除
- [v2.5 (2026-10-17)](#v25--2026-10-17-1252) — Hardware Battery Charge Limit & SMC Gate / 电池硬件限充与 SMC 硬闸门
- [v2.4 (2026-10-16)](#v24--2026-10-16-2115) — Packages & Dependencies Manager / 依赖与软件包管理
- [v2.3 (2026-10-14)](#v23--2026-10-14-2050) — Dynamic Menu Bar Ring & AI Chat Catalog / 动态菜单栏环形图标与 AI 对话库
- [v2.2 (2026-10-13)](#v22--2026-10-13-1423) — Customizable Popover Widgets / 小组件化自定义下拉框
- [v2.1 (2026-10-13)](#v21--2026-10-13-1327) — SMC Fans & Temperature / SMC 风扇与温度监控
- [v2.0 (2026-10-13)](#v20--2026-10-13-1233) — Multi-Chromium Browser Instances / 多 Chromium 浏览器实例管理
- [Earlier Versions (2026-10-10 ~ 2026-10-13)](#2026-10-13--disk-usage--browser-favorites--磁盘用量与浏览器收藏)

---

### v3.0 — 2026-10-24 08:40

> Author / 作者：zys · Model / 模型：Gemini 4 Argon

**English**
- **Global Design System & Semantic Tokenization (`DESIGN.md`)**:
  - Implemented strict 3-step lightness hierarchy (`background` → `surface` → `fill`) in `PharosColor`, replacing random hardcoded hex colors and arbitrary borders with structured, accessible contrasts across both Light and Dark modes
  - Unified system metrics into `PharosSpacing` (4/8/12/16/20/28 pt), `PharosRadius` (6/10/14/18 pt), and `PharosFont` with `.monospacedDigit()` for jitter-free real-time metrics
  - Built modular core components: `PharosPage`, `PharosPageHeader`, `PharosSection`, `PharosCard`, `PharosActionButton`, `PharosTag`, `PharosBanner`, and `PharosSearchField`
  - Overhauled all sub-views (System Memory, Disk Usage, Battery & Thermals, Disk Cleanup, Chrome/Browser Instances, AI Agent Chats, Packages & CLI Tools, Favorites & Running Projects, Settings) under the new design system
- **Pure Custom Sidebar with High-Contrast Typography & Domain Categorization**:
  - Re-architected sidebar from native `List`/`NSTableView` to a pure custom `ScrollView` with specialized interactive rows (`PharosSidebarRow`, `BatteryAndThermalSidebarRow`, `FavoriteSidebarRow`, `ProjectSidebarRow`)
  - **Eliminated native AppKit blue highlight clashing**: selected rows use a gentle neutral card background (`PharosColor.fill`) with a 0.5pt subtle separator stroke; selected text strictly maintains high-contrast `PharosColor.textPrimary` (solid black in light mode, pure white in dark mode) while icons display warm amber accent (`PharosColor.accent`)
  - Organized navigation into 6 clear domain categories (System & Hardware, Runtime & Services, System Maintenance, Favorite Workspaces, Running Projects, Appearance), anchored by a top Dashboard Hero item and bottom control island (refresh, settings, project status pill)
- **Adaptive Anti-Squeezing Popover Customizer Layout & Tactile Drag-and-Drop**:
  - Upgraded `CustomizePopoverView` with `ViewThatFits(in: .horizontal)` responsive engine: automatically displays side-by-side snapshot and editor columns on wide screens, and smoothly transitions to stacked layout on narrower windows with zero column or sidebar squeezing
  - Optimized tab and library column minWidth from 200pt to 150pt and uncapped the previous artificial 960pt limit via `PharosPage(maxWidth: 1200)`
  - Elevated default main window dimensions to `1040 × 700` (minWidth `920 × 600`)
  - **Zero-Latency In-Memory Drag Engine (`DragCoordinator`)**: added synchronous in-memory tracking eliminating the 100ms NSItemProvider async lag; introduced dynamic amber insertion guide lines on tiles, full-area drop zones across tab columns and library, and 35% in-place grab dimming with `.spring()` physics
- **Card-Structured Settings Redesign (AlDente Inspired)**:
  - Re-architected `MainSettingsView` with modular card hierarchy: 2x2 capsule Quick Action grid (Refresh, Export, Import, Reset with confirmation), License & About card, categorized setting cards with SF Symbols, help tooltips, and aligned 3-column footer
- **Codebase Integrity**: 100% native Swift/SwiftUI, zero third-party dependencies, all **765 unit assertions passed**.

**简体中文**
- **全局设计系统规范落地与语义化 Token 体系（`DESIGN.md`）**：
  - 基于统一的三层明度层级（`background` → `surface` → `fill`）重构 `PharosColor`，深浅两套外观均杜绝硬编码杂色与无意义发丝框，确保层级分明且符合人眼视觉工效
  - 规范化间距（`PharosSpacing`）、圆角（`PharosRadius`）与字体系统（`PharosFont`，数字指标全量接入 `.monospacedDigit()` 避免高频跳动）
  - 构建开箱即用的模块化组件库：`PharosPage`、`PharosPageHeader`、`PharosSection`、`PharosCard`、`PharosActionButton`、`PharosTag`、`PharosBanner`、`PharosSearchField`
  - 统筹美化重构全部二级业务视图：系统内存、磁盘卷、电池与温度、磁盘清理、浏览器实例、AI 助手会话、依赖与软件包、常用项目与运行中进程、设置页
- **纯净定制侧边栏、高对比度文字与领域化子窗口分类**：
  - 彻底重构原有原生 `List`/`NSTableView` 侧边栏，转换为高性能纯净 `ScrollView` + 独立行组件体系（`PharosSidebarRow` 等）
  - **根治系统原生蓝条高亮反差冲突**：选中态采用柔和低对比度中性底（`PharosColor.fill`）与 0.5pt 发丝微边框；选中文字**严格保持最高清晰度主文本色（`PharosColor.textPrimary`）**（浅色模式纯黑、深色模式纯白），仅图标点缀精致琥珀色（`PharosColor.accent`），在任何光照外观下文字均字字分明
  - 领域化清晰归组：划分为仪表盘英雄项、系统与硬件、环境与运行时、系统维护、常用项目、运行中进程、外观与设置 6 大领域，配合底部控制岛（一键刷新、设置直达、运行状态药丸胶囊）
- **响应式防挤压小组件自定义布局与高贴手拖拽重构**：
  - `CustomizePopoverView` 全面引入 `ViewThatFits(in: .horizontal)` 智能响应式架构：宽屏下 Popover 实时预览与编辑列左右舒展并列，窄屏或小显示器下自动平滑降级为上下纵向排列，彻底解决侧边栏被压扁、主内容区被横向挤压的问题
  - 弹性列宽调优：两列 Tab 与组件库最小宽度从 200pt 缩减至更合理的 150pt，并通过 `PharosPage(maxWidth: 1200)` 释放宽度约束
  - 窗口基准尺寸升级：主窗口默认大小调整为更宽敞舒适的 `1040 × 700`（最小尺寸 `920 × 600`）
  - **跟手性与拖拽体验彻底根治（`DragCoordinator`）**：引入内存同步拖拽协调器，消灭原异步跨线程 100ms 停顿；新增动态琥珀色插入指示线、页签全域无盲区吸附、组件库全域直接回收，以及 35% 原位抓取置灰与物理弹簧平滑位移动效
- **卡片式分层设置面板重构（对标目标 App）**：
  - 重新设计主窗口设置 `MainSettingsView`：2×2 胶囊快捷动作网格（立即刷新、导出配置、导入配置、破坏性红字重置与弹窗防误触）、许可与关于卡片、SF Symbols 分组卡片与三栏对齐页脚
- **工程质量与纯净度**：纯 Apple 原生 Swift / SwiftUI，零第三方依赖，全量单测套件 **765 项断言全绿通过**。

---

### v2.9 — 2026-10-23 15:46

> Author / 作者：zys · Model / 模型：Gemini 4 Argon

**English**
- **Persistent Lid-Closed & Background Battery Guard**: added an optional toggle ("Persistent Lid-Closed & Background Guard") in Battery & Charging; when enabled, `pharos-battd` persists `mode`, `targetPercent`, `syncMagSafeLed`, and `persistentGuard` to `/Library/PrivilegedHelperTools/local.pharos.battd.state` (mode `0600`) and continues enforcing the charge limit across lid-close sleep, DarkWake maintenance wakes, app termination, and system reboots without requiring UI heartbeats
- **Zero-Redundancy SMC Write Deduplication & Log Rotation**: `pharos-battd` tracks `lastAppliedAction`, `lastAppliedMagSafe`, and `lastHardwareWriteTime`, suppressing redundant SMC writes within a 60s window and logging only on actual state transitions; relaxed daemon tick interval to 3s, added fast-return in `.system` mode before opening IOKit/IOPowerSources, and added startup log rotation (`LogRotation.rotateLogIfNeeded`, 512 KB cap / 256 KB tail retention)
- **Visibility-Driven Background Polling**: `BatteryStore`, `FanStore`, and `ProjectStore` dynamically adjust timer intervals via `updateVisibility(hasViewers:)` — full responsiveness while popover or main window is open, downclocked to 30s silent background heartbeats when all windows are closed
- **Incremental AI Chat Database Fingerprint Cache**: introduced `AgentDatabaseFingerprint` tracking main SQLite DB and companion `-wal` file sizes and nanosecond-precision `mtime`; unchanged databases (including multi-GB stores like 6.5 GB `opencode.db`) reuse cached entries in $O(1)$ without reopening SQLite pages, while the Refresh button forces a full rescan
- **Two-Stage Progressive Project Dependency Scanning & Directory Size Cache**: `PackageScanner.scanProjectDependencies(projectPath:includeCacheSize:)` and `PackageStore.scanAll()` now render project dependency manifests and CLI tools immediately in Stage 1 (`includeCacheSize: false`), then progressively compute and cache `node_modules` / `.venv` / `.build` / `target` bundle sizes in Stage 2 (`computeProjectCacheSize(for:)`) keyed by directory and lockfile `mtime`
- **Modularized Core & UI Codebase**: cleanly split large files into focused modules (`PackageScanner` + `+GlobalCLI` / `+ProjectDeps` / `+CacheRepos`, `AgentChats` + `AgentScanner` + `+CustomApp`, `PackageView` + `PackageSubViews`, `AgentChatView` + `AgentChatSubViews`), expanding unit test coverage to **765 assertions**

**简体中文**
- **电池合盖与后台持续守护（Persistent Guard）**：「电池与充电」页面新增「合盖与后台持续守护」开关；开启后 `pharos-battd` 将 `mode`、`targetPercent`、`syncMagSafeLed` 与 `persistentGuard` 持久化至 `/Library/PrivilegedHelperTools/local.pharos.battd.state`（权限 `0600`），在 Mac 合盖休眠、夜间 DarkWake 唤醒、Pharos 主程序退出甚至系统重启后，依然由 root 守护进程独立维持 80% 硬件限充，不再因 15 秒无 UI 心跳而回退系统充电
- **SMC 硬件写入去重与日志自动轮转**：`pharos-battd` 记录上一次生效的硬件动作与时间戳，状态未变时 60 秒内跳过重复 SMC 寄存器写入且仅在状态切换时输出带时间戳日志；守护进程主循环调整为 3 秒，`.system` 模式跳过 IOKit 采样，并在启动时自动执行 `512 KB` 日志截断轮转（保留末尾 `256 KB` 完整行）
- **窗口可见性驱动的后台轮询降频**：`BatteryStore`、`FanStore` 与 `ProjectStore` 接入 `updateVisibility(hasViewers:)`，主窗口或菜单栏弹窗可见时保持高频实时刷新，窗口全部关闭后自动降频至 30 秒静默心跳
- **AI 会话数据库纳秒级增量指纹缓存**：新增 `AgentDatabaseFingerprint`（同时校验主库与 `-wal` 文件字节数及纳秒级 `mtime`），未发生写入的超大数据库（如 6.5 GB 的 `opencode.db`）直接 $O(1)$ 复用内存条目，彻底消除二次扫描 I/O 峰值；点击「刷新」支持强制全量重扫
- **项目依赖两阶段渐进式扫描与目录体积缓存**：`PackageScanner` 与 `PackageStore` 落地两阶段加载——第一阶段秒级解析并渲染所有项目声明清单与 CLI 工具，第二阶段在后台按需回填 `node_modules` / `.venv` / `.build` / `target` 目录体积，并通过目录与锁文件 `mtime` 指纹缓存避免重复递归遍历
- **核心与视图层无损模块化拆分**：将 `PackageScanner`、`AgentChats`/`AgentScanner`、`PackageView`、`AgentChatView` 按职责拆分为高内聚子模块，全量单测套件扩充至 **765 项断言** 100% 通过

---

### v2.8 — 2026-10-19 13:20

> Author / 作者：zys · Model / 模型：Gemini 4 Argon

**English**
- **Automotive cockpit fan speedometer cluster**: introduced high-precision cockpit tachometer and speedometer dials for cooling fans; features 270° dynamic sweep arc, redline danger zone, upright polar numerals, and target speed notch marker, while 100% preserving classic horizontal bar view with smooth picker transition
- **60 FPS mechanical inertia acceleration engine**: authentic fan spool-up and deceleration physics driven by cubic Smoothstep S-curve ($3t^2 - 2t^3$) over 0.45s–1.85s; digital HUD displays frame-by-frame continuous rolling RPM digits with zero discrete jumps
- **Dynamic Gaussian motion blur & 3D acceleration setting**: velocity-driven Gaussian motion blur on needle trails, ribbons, and HUD digits; added user toggle with an in-app notice banner allowing seamless fallback to lightweight 2D standard spring animation with zero background timers for energy savings
- **Needle geometry & polar trigonometry alignment**: re-architected needle assembly with exact boundary-to-pivot offset ensuring 100% concentric alignment at `(0, 0)`; dials and tick marks use pure polar trigonometry ($(x = r\sin\theta, y = -r\cos\theta)$); shifted central digital HUD cluster downward to completely eliminate overlap with the center hub cap
- **Multi-tiered motion architecture & fluid 2D transitions**:
  - *Tier 1 (3D + Dynamic Motion Blur)*: exclusively on Fans & Thermals tachometer cockpit with GPU-accelerated 60 FPS mechanical simulation and velocity blur
  - *Tier 2 (Zero-GPU-overhead 2D Fluid Transitions)*: native gear-shift rolling digits (`.contentTransition(.numericText())`) across System Memory, Disk Cleanup, and AI Chat metrics; fluid spring interpolation on memory composition segments and trend charts; collapsible card spring transitions in Disk Cleanup; and macOS Settings-style asymmetric slide/fade page navigation in AI Chats
  - *Tier 3 (Pure 2D Static)*: Favorite Workspaces, Running Projects, Browser Instances, Packages, and Disk Volumes remain strictly static 2D with zero animation delay or offscreen pass overhead
  - *Unified Motion Setting & System Accessibility Guard*: integrated `@AppStorage("pharos.gauge3DAcceleration")` with macOS system accessibility `accessibilityReduceMotion` to automatically enforce 2D battery-saving mode when Reduce Motion is enabled in macOS System Settings
- **SwiftUI Gaussian motion blur reuse guide**: documented pure Swift zero-dependency dynamic velocity blur patterns, crossfading, ghost trails, and Metal rendering best practices in `docs/SWIFTUI_GAUSSIAN_MOTION_BLUR_GUIDE.md`

**简体中文**
- **拟真机车仪表盘风扇座舱（Speedometer Cluster）**：重磅推出高精度双表盘/单表盘汽车座舱速度表风格风扇仪表盘，拥有 270° 动态转速弧环、红线区预警弧、手动目标转速刻度箭头；与经典水平条状卡片 100% 并存且支持平滑转场切换
- **60 FPS 物理机械惯性阻尼引擎**：基于三次 Smoothstep S 曲线（$3t^2 - 2t^3$）真实模拟风扇起转与减速物理阻尼，HUD 转速数字与指针逐帧连续滚动跳变，告别阶梯式断层
- **动态高斯运动模糊与 3D 硬件加速设置**：速度突变时自动触发速度驱动的高斯运动模糊与拖尾残影；座舱顶部新增 3D 动效提示横幅与「减弱动态效果 / 开启 3D 加速」开关，关闭后零后台计时器开销，平滑降级至超低能耗经典弹簧模式
- **同心转动轴心与极坐标正立排布**：重构同轴心指针装配组件与极坐标刻度定位（$x = r\sin\theta, y = -r\cos\theta$），彻底消除锚点漂移；将中央 HUD 读数集群下移，完美消除数字与中心轴盖的遮挡冲突
- **分级动效架构与轻量 2D 流体动效落地**：
  - *第一梯队（3D 加速 + 动态高斯模糊）*：专属于「风扇与温度」机械拟真仪表盘座舱，调用 GPU 核心进行 60FPS 物理平滑阻尼与运动模糊渲染
  - *第二梯队（零额外 GPU 开销 2D 流体动效）*：在「系统内存」、「磁盘清理」与「AI 对话」中引入原生机械滚轮数字跳变（`.contentTransition(.numericText())`）、物理内存分布图动态弹性伸缩（Spring）、清理完成即时数字归零与折叠展开平滑收缩动画，以及 AI 对话「概览 ↔ 详情」的 macOS 级非对称滑入/淡出转场
  - *第三梯队（纯静态 2D 零延迟）*：常用项目、运行中项目、浏览器实例、软件包管理与磁盘用量保持极致静态 2D，零动画延迟、零离屏渲染开销
  - *全局动效控制与系统辅助功能联动*：设置中的「3D 动效加速」开关与系统级「减弱动态效果（Reduce Motion）」无缝联动，检测到系统辅助功能开启时自动降级至 2D 节能模式，符合 Apple 人机交互设计规范
- **SwiftUI 动态高斯运动模糊复用手册**：在 `docs/SWIFTUI_GAUSSIAN_MOTION_BLUR_GUIDE.md` 沉淀了纯 Swift 零依赖的速度驱动模糊、模式切换模糊、向心旋转残影拖尾等 4 大复用模板与 Metal 性能军规

---

### v2.7 — 2026-10-19 09:35

> Author / 作者：zys · Model / 模型：Gemini 4 Argon

**English**
- **Homebrew formula & cask management**: deeply scans `/opt/homebrew` and `/usr/local` `Cellar` (reading `INSTALL_RECEIPT.json` metadata, versions, descriptions, and pinned status) and `Caskroom`; provides quick terminal actions for `brew doctor`, `brew services list`, and `brew outdated`
- **Homebrew cache cleanup**: detect and clean `~/Library/Caches/Homebrew` (cached formula downloads and bottled binaries) in both Disk Cleaner and Package Manager
- **Multi-root developer workspace discovery**: dynamically searches for active projects and dependencies across 10 standard developer workspaces (`~/Projects`, `~/Developer`, `~/Workspace`, `~/Code`, `~/src`, `~/Desktop`, `~/Documents`, `~/Downloads`, `~/dev`, and `~`)
- **AI chats: manual application addition**: click `+ Add App` in the AI Chats overview or editor bar to select any `.app` bundle from `/Applications` or custom directories; automatically parses bundle plists, extracts native Retina macOS icons via `NSWorkspace`, and persists across app restarts
- **Targeted custom scanner & generic SQLite conversation reader**: dedicated scanning probes `~/Library/Application Support`, `~/Library/Containers`, and `~/.<app>` candidate paths; universal schema reader inspects standard conversation tables (`chats`, `conversations`, `sessions`, `threads`, `messages`, `ItemTable`)
- **Custom application lifecycle**: dedicated custom app detail page with "Rescan App" and "Remove App" controls, seamless integration into search, filtering, and catalog summaries
- **Secondary deletion confirmation**: prominent dual-step confirmation modal with red action button for database removal

**简体中文**
- **真实 Homebrew 与 Cask 深度管理**：原生扫描 Apple Silicon (`/opt/homebrew`) 与 Intel (`/usr/local`) 下的 `Cellar`（解析 `INSTALL_RECEIPT.json` 获取精确版本、描述与锁定状态）与 `Caskroom`；快捷一键执行 `brew doctor`、`brew services list`、`brew outdated` 诊断
- **Homebrew 缓存清理**：在磁盘清理与依赖管理中支持识别并一键清理 `~/Library/Caches/Homebrew` 下的下载缓存与预编译 Bottle
- **多工作区项目深度发现**：自动递归扫描本机 10 大标准开发者目录（`~/Projects`、`~/Developer`、`~/Workspace`、`~/Code`、`~/src`、`~/Desktop`、`~/Documents`、`~/Downloads`、`~/dev` 以及主目录），真实发现本地项目及依赖状态
- **AI 对话管理：手动添加应用**：总览操作栏与编辑器选择区新增「+ 手动添加」按钮，支持从 `/Applications` 或任意路径选取应用，自动解析 Bundle 元数据、通过 `NSWorkspace` 提取原生高清 Retina 图标，配置持久化保存
- **定向定制扫描与通用 SQLite 会话探测**：为用户手动添加的应用定向扫描 `~/Library/Application Support`、`~/Library/Containers` 及 `~/.<应用名>` 下的候选数据库，通过通用表结构探查（`chats`、`conversations`、`sessions`、`threads`、`messages`、`ItemTable` 等）解析对话列表
- **自定义应用专属管理页**：支持独立查看自定义应用的会话与数据库、重新扫描与「移除应用」，无缝接入搜索与统计
- **删除操作醒目二次确认**：数据库删除提供醒目的红色按钮与双重安全确认，防止误操作

---

### v2.6 — 2026-10-17 15:06

> Author / 作者：zys · Model / 模型：OpenCode (claude-opus-5.5)

**English**
- **AI chats: overview and detail are separate pages** — opening an editor replaces the whole page (no more other editors' cards below it); back via "‹ All Editors", ⌘[ or Esc
- **Editor detail**: summary card plus **Databases / Conversations** tabs; each database card expands to its own sessions; known paths not created yet are folded at the bottom; conversations from every database merged newest-first, each labelled with its database, searchable
- **Single conversation**: click to expand metadata only (title, mode, messages, created / updated, database and path, snippet, session ID); a note appears when a database hit the 100-session reader cap
- **Collapsible storage chart**: collapse keeps just the composition strip; state is remembered
- **Editor entry style in Settings**: cards (grid) or icon strip; editors without data are folded
- **Safer writes** (`AgentDeletePolicy`, pure + unit-tested, re-checked inside `AgentDatabaseManager.deleteEntry`): global databases never deleted; targets must be inside the editor's known storage paths (copies elsewhere untouched); orphaned workspaces remove only a direct child of a known workspace root; live databases refused while the editor runs; locked rows show why. Orphan cleanup goes entry by entry and reports skipped / failed counts
- **Backup** now writes only to the file chosen in a save panel (plus `-wal`)
- Per-editor summaries cached once per scan (`AgentChatCatalog`); all page strings localised; AGENTS.md documents the AI chats read/write rules

**简体中文**
- **AI 对话管理：总览与详情分离** —— 进入某个编辑器后整页替换，下方不再残留全部编辑器与其他 app 卡片；通过「‹ 全部编辑器」、⌘[ 或 Esc 返回
- **编辑器详情页**：概要卡片 +「数据库 / 对话」分段标签；每个数据库卡片展开显示该库自己的会话；尚未生成的已知路径折叠在底部；对话标签合并全部库的会话，按时间倒序、标注所属库、可搜索
- **单条对话**：点击展开元数据（标题、模式、消息数、创建/更新时间、所属库与路径、摘要、会话 ID）；某库读满 100 条时给出提示
- **存储图表可收起**：收起后仅保留比例色条，状态持久化
- **设置中可选编辑器入口样式**：卡片网格或横向图标条；无数据的编辑器折叠显示
- **写操作收紧**（`AgentDeletePolicy` 纯函数单测，并在 `AgentDatabaseManager.deleteEntry` 内二次判定）：全局库不删；目标必须在该编辑器已知存储路径内（其他位置的副本不动）；失效工作区只删已知根目录的直接子目录；编辑器运行时拒绝删除在用库；不可删的条目显示锁形图标与原因。批量清理残留逐条判定，跳过/失败计数显示在横幅
- **备份**改为只写入保存面板中选择的文件（连同 `-wal`）
- 按编辑器的统计每次扫描只算一次（`AgentChatCatalog`）；页面文案全部双语；AGENTS.md 补充 AI 对话管理读写约定

---

### v2.5 — 2026-10-17 12:52

> Author / 作者：zys · Model / 模型：OpenCode (claude-opus-5.5)

**English**
- **System Managed button**: next to "Charge to Full Now" and "Resume Charge Limit"; sends `system` to `pharos-battd`, which releases every SMC key and its sleep assertion, handing charging back to macOS
- **Charge limit presets** reduced to 80 % (recommended) / 85 / 90 / 95 / 100 %; the preset the helper is actually enforcing is highlighted (`.borderedProminent`)
- **Takeover badge** above the status card: green `● Pharos hardware charge limit active · Limit 80%` vs. gray `○ Managed natively by macOS`, driven only by the helper's reply
- **Measured evidence**: status card shows `Battery cell current: 0 mA · Adapter powering the Mac directly`, classified from AppleSmartBattery `Amperage` + IOPS (`BatteryPowerFlow`), never from the percentage
- **MagSafe LED matches macOS 15**: amber while holding at the limit (or firmware-driven when sync is off); the LED-off value was removed from the code
- **Hard SMC write gate** (`BatteryPolicy.isSafeWrite`): every write in `pharos-battd` is checked — `CHIE` / `CH0J` may only be 0 (no adapter cut-off, no screen flicker), `ACLC` can never be `0x01`, unknown keys rejected; release is idempotent
- **No more transient "Failed to send command"** after "Update Helper": socket client retries 3 × 150 ms when the daemon is restarting, and the install callback waits 300 ms before probing and restores the previous mode
- Charge limit choice is remembered and re-applied when Pharos starts (enable "Launch at login" to keep the limit across reboots)

**简体中文**
- **「交由系统管理」按钮**：与「立即充满电」「恢复充电上限」并列；向 `pharos-battd` 发送 `system`，释放全部 SMC 寄存器与防睡眠断言，完全交还 macOS 原生管理
- **充电上限挡位**精简为 80%（推荐）/ 85 / 90 / 95 / 100%；守护进程实际生效的挡位高亮显示（`.borderedProminent`）
- **接管状态徽标**：状态卡片上方显示绿色「● Pharos 硬件限充生效中 · 上限 80%」或灰色「○ macOS 原生托管中」，只以守护进程回复为准
- **硬件生效确凿数据**：状态卡片显示「电池电芯电流: 0 mA · 外接电源直通主板供电」，依据 AppleSmartBattery `Amperage` 与 IOPS 判定（`BatteryPowerFlow`），不以电量数字代替真实状态
- **MagSafe 指示灯对齐 macOS 15**：限充保持时黄色/橙色常亮（关闭同步时由系统固件控制）；代码中已移除「关灯」取值
- **SMC 写入硬闸门**（`BatteryPolicy.isSafeWrite`）：`pharos-battd` 每次写入都经校验——`CHIE` / `CH0J` 只能写 0（绝不切断适配器、不闪屏），`ACLC` 永不写 `0x01`，未知寄存器一律拒绝；释放操作幂等
- **消除「更新特权组件」后的「发送指令失败」瞬态报错**：守护进程重启期间通信自动重试 3 次（间隔 150ms），安装回调延迟 300ms 后再探测并恢复更新前的模式
- 记住限充设置，Pharos 启动后自动恢复（开启「登录时启动」即可在重启后持续限充）

---

### v2.4 — 2026-10-16 21:15

**English**
- **Packages & Dependencies manager**: unified tabbed page in main window covering Global CLI tools, Project Dependencies, and Language Cache Repositories
- **Global CLI software & featured shelf**: auto-discovers binaries across Node (`npm -g`, Bun, pnpm, yarn), Homebrew, Cargo, Python (`uv`, `pip`), and Go; top shelf with category tags for core tools and AI agents (`claude`, `grok`, `rea`, `aider`, `codebuddy`, `wrangler`, `docker`, `uv`, `bun`, `pnpm`, `cargo-tauri`, `gh`, `rg`); quick `--help` test in Terminal, reveal in Finder, and **one-click uninstall with secondary confirmation in Terminal**
- **Multi-ecosystem project dependencies & cache insight**: scans and identifies project cache footprints across Node (`node_modules`), Python (`.venv`/`venv`, `site-packages` metadata), SwiftPM (`.build`, `Package.resolved`), Rust (`target`, `Cargo.lock`), and Java (`pom.xml`, `target`/`build`); displays cache directory name and disk size; provides smart language-specific install commands for missing packages
- **Language cache repositories**: aggregates sizes and locations for npm cache, pnpm store, Python uv wheels, Cargo registry, Bun cache, Maven m2, SwiftPM cache, and OpenJDK runtimes

**简体中文**
- **依赖与软件包管理**：主窗口新增「依赖与软件包」独立页面，统一管理全局 CLI 软件、项目依赖洞察与语言缓存仓库
- **全局命令行软件与核心工具展架**：自动扫描 Node（`npm -g`、Bun、pnpm、yarn）、Homebrew、Cargo、Python（`uv`、`pip`）及 Go 安装的全部 CLI；顶部展架高亮核心独立软件与 AI 助手（`claude`、`grok`、`rea`、`aider`、`codebuddy`、`wrangler`、`docker`、`uv`、`bun`、`pnpm`、`cargo-tauri`、`gh`、`rg` 等）；卡片支持在终端测试运行、在 Finder 中定位，以及**二次确认后在终端中执行一键卸载**
- **多技术栈项目依赖洞察与缓存识别**：全面识别 **Node.js**（`node_modules`）、**Python**（`.venv` / `venv`、`site-packages` 元数据）、**SwiftPM**（`.build`、`Package.resolved`）、**Rust**（`target`、`Cargo.lock`）与 **Java**（`pom.xml`、`target`/`build`）等项目的依赖包与缓存占用；项目选择菜单直观显示缓存目录及体积；缺失依赖时智能推荐对应的安装指令
- **语言缓存仓库概览**：统计分析 npm 缓存、pnpm 全局硬链接仓库、Python uv Wheel 预编译缓存、Cargo 依赖缓存、Bun 运行时缓存、Maven 本地库、SwiftPM 缓存及已安装的 OpenJDK 运行时

---

### v2.3 — 2026-10-14 20:50

**English**
- **Dynamic menu bar gauge icon**: native CoreGraphics ring icon reflecting live fill fraction (white progress arc vs. gray track) and pressure status dot (green / yellow / red)
- **Project count option & capacity limits**: choose between project count (`projects`) and port count (`ports`) in menu bar; customize "Max projects" and "Max ports" in Settings to scale the dynamic gauge ring
- **AI agent chat databases**: inspect, backup, and clean local session databases and orphaned project records across 23+ AI programming editors (Cursor, Trae, Windsurf, VS Code, Antigravity, OpenCode, Claude Code, MiniMax Code, etc.)

**简体中文**
- **动态菜单栏仪表图标**：CoreGraphics 原生绘制的环形用量图标，展示白色进度弧与灰色底圈的动态比例，中心配备三色健康/压力状态指示点
- **新增项目数显示与容量上限设置**：菜单栏数字支持独立选择「项目数」或「端口数」；设置中提供「最多项目数」与「最多端口数」自定义上限，实时缩放菜单栏图标填充比例
- **AI 编程助手会话管理**：全面扫描与管理 23+ 款本地 AI 编辑器（Cursor、Trae、Windsurf、VS Code、Antigravity、OpenCode、Claude Code、MiniMax 等）的聊天会话与工作区数据库，支持残余孤立数据库检测、安全备份与清理

---

### v2.2 — 2026-10-13 14:23

**English**
- **Customize the popover like widgets** (Main window → Customize): live snapshot of the popover, its two tabs and a component library; drag blocks to reorder, move between tabs, hide or add. Eight blocks incl. a new **Favorite projects** block; empty tabs hide; Reset to Default
- **Running projects shown**: set how many projects the popover lists before the list scrolls (3 up to the number running, default 5)
- Popover layout is included in backups

**简体中文**
- **像小组件一样自定义下拉框**（主窗口 →「自定义」）：下拉框实时快照、两个页签和组件库；拖动组件调整顺序、在页签间移动、隐藏或添加。共 8 个组件，新增**常用项目**组件；空页签自动隐藏；可恢复默认
- **运行中的项目显示个数**：设置下拉框最多列出几个项目，超过后列表内滚动（最少 3 个，最多为当前运行数，默认 5 个）
- 备份中包含下拉框布局

---

### v2.1 — 2026-10-13 13:27

**English**
- **Fans & Temperature** page and popover section: each fan's speed, rated range and controller; CPU / GPU / memory / SSD / battery / power / in-case temperatures; macOS thermal state; shortcut to Energy Mode settings
- **Fan control (optional, experimental)**: hold fans at a fixed speed or max via the `pharos-fand` root helper, installed with macOS's administrator password dialog — no Apple Developer account needed
- Helper-enforced safety: ≥ 95 °C forces max (released < 88 °C), no heartbeat for 15 s or quitting Pharos hands fans back to macOS, speeds clamped to each fan's range
- Note: monitoring is verified on M3 Pro; manual fan control is not yet verified on M3 Pro

**简体中文**
- **风扇与温度**页面和下拉框分区：每个风扇的转速、额定范围和控制方；CPU / GPU / 内存 / SSD / 电池 / 供电 / 机身内部温度；macOS 散热状态；一键打开能耗模式设置
- **风扇控制（可选，实验性）**：通过 root 助手 `pharos-fand` 把风扇固定在某个转速或满速，用 macOS 自带的管理员密码框安装，不需要 Apple 开发者账号
- 安全规则由助手执行：≥ 95°C 强制满速（< 88°C 解除）；15 秒无心跳或退出 Pharos 时交还系统；转速限制在额定范围内
- 说明：监控已在 M3 Pro 上验证；手动风扇控制尚未在 M3 Pro 上验证

---

### v2.0 — 2026-10-13 12:33

**English**
- **Browser instances** (was “Chrome instances”): Chrome, Chrome Beta / Canary, Chromium, Edge and Brave; filter bar and per-browser groups for multi-browser setups; instance identity is browser + profile folder
- **Settings → Browsers**: installed / running / saved per browser, default profile folders, hide unused browsers, default browser for new instances
- **Terminals**: open favorites in Terminal, iTerm2, Ghostty or Warp (falls back to Terminal)
- **Local notifications** (off by default): memory pressure, disk ≥ 95 %, a favorite stopping on its own
- **Menu bar number**: port count, memory % or startup disk %
- **Global shortcut** to open the popover (⌥⌘P / ⌃⌥P / ⌥⌘Space)
- **Backup**: export / import favorites and browser presets as JSON
- Faster: disk reads no longer delay port / memory scans; browser profile names cached off the main thread

**简体中文**
- **浏览器实例**（原「Chrome 实例」）：支持 Chrome、Chrome Beta / Canary、Chromium、Edge、Brave；多浏览器环境下有筛选栏和按浏览器分组；实例身份为「浏览器 + 配置文件夹」
- **设置 → 浏览器**：各浏览器的安装 / 运行 / 已保存情况、默认配置文件夹，可隐藏不用的浏览器、选择新建实例的默认浏览器
- **终端**：常用项目可在「终端」、iTerm2、Ghostty 或 Warp 中启动（打不开时回退到「终端」）
- **本地通知**（默认关闭）：内存压力升高、磁盘 ≥ 95%、常用项目自己停止
- **菜单栏数字**：端口数、内存 % 或启动磁盘 %
- **全局快捷键**打开下拉框（⌥⌘P / ⌃⌥P / ⌥⌘Space）
- **备份**：常用项目和浏览器预设导出 / 导入为 JSON
- 更流畅：读磁盘不再拖慢端口 / 内存扫描；浏览器账号名在后台缓存

---

### 2026-10-13 — Disk usage & browser favorites / 磁盘用量与浏览器收藏
- Disk usage for the startup disk, external drives, network shares and disk images, in the popover and the main window; Finder-style numbers, live on plug-in
- Saved browser instances stay listed after quitting, with a copyable launch command
- 磁盘用量：启动磁盘、外接硬盘、网络共享、磁盘映像，菜单栏和主窗口都可查看，口径与 Finder 一致，接入即更新
- 收藏的浏览器实例关闭后仍显示，并可复制启动命令

---

### 2026-10-12 — Pharos
- Renamed from UsageBar to **Pharos**, new radar-sweep icon drawn in Swift; settings migrate automatically
- Chrome instance manager, broader start-command detection, popover button fixes
- 由 UsageBar 更名为 **Pharos**，新的雷达扫描图标（Swift 绘制）；设置自动迁移
- Chrome 实例管理、更多启动命令识别、修复下拉框按钮

---

### 2026-10-11 — Favorites & disk cleanup / 常用项目与磁盘清理
- Favorite projects with detected start commands, open in Terminal
- Disk cleanup page with a pinned temp-files group and retention window
- 常用项目：自动识别启动命令，一键在终端中启动
- 磁盘清理页：置顶临时文件组，可设保留期

---

### 2026-10-10 — First version / 首个版本
- Dev ports & memory monitor for the macOS menu bar
- macOS 菜单栏开发端口与内存监控
