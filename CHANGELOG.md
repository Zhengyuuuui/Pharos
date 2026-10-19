# Changelog / 更新记录

All notable changes to Pharos are documented in this file.
Pharos 的全部版本演进与发布记录均归档于此。

Times are UTC+8. 时间为北京时间（UTC+8）。

---

## 目录 / Quick Links
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

### v2.8 — 2026-10-19 13:20

> Author / 作者：zys · Model / 模型：Gemini 4 Argon

**English**
- **Automotive cockpit fan speedometer cluster**: introduced high-precision cockpit tachometer and speedometer dials for cooling fans; features 270° dynamic sweep arc, redline danger zone, upright polar numerals, and target speed notch marker, while 100% preserving classic horizontal bar view with smooth picker transition
- **60 FPS mechanical inertia acceleration engine**: authentic fan spool-up and deceleration physics driven by cubic Smoothstep S-curve ($3t^2 - 2t^3$) over 0.45s–1.85s; digital HUD displays frame-by-frame continuous rolling RPM digits with zero discrete jumps
- **Dynamic Gaussian motion blur & 3D acceleration setting**: velocity-driven Gaussian motion blur on needle trails, ribbons, and HUD digits; added user toggle with an in-app notice banner allowing seamless fallback to lightweight 2D standard spring animation with zero background timers for energy savings
- **Needle geometry & polar trigonometry alignment**: re-architected needle assembly with exact boundary-to-pivot offset ensuring 100% concentric alignment at `(0, 0)`; dials and tick marks use pure polar trigonometry ($(x = r\sin\theta, y = -r\cos\theta)$); shifted central digital HUD cluster downward to completely eliminate overlap with the center hub cap
- **SwiftUI Gaussian motion blur reuse guide**: documented pure Swift zero-dependency dynamic velocity blur patterns, crossfading, ghost trails, and Metal rendering best practices in `docs/SWIFTUI_GAUSSIAN_MOTION_BLUR_GUIDE.md`

**简体中文**
- **拟真机车仪表盘风扇座舱（Speedometer Cluster）**：重磅推出高精度双表盘/单表盘汽车座舱速度表风格风扇仪表盘，拥有 270° 动态转速弧环、红线区预警弧、手动目标转速刻度箭头；与经典水平条状卡片 100% 并存且支持平滑转场切换
- **60 FPS 物理机械惯性阻尼引擎**：基于三次 Smoothstep S 曲线（$3t^2 - 2t^3$）真实模拟风扇起转与减速物理阻尼，HUD 转速数字与指针逐帧连续滚动跳变，告别阶梯式断层
- **动态高斯运动模糊与 3D 硬件加速设置**：速度突变时自动触发速度驱动的高斯运动模糊与拖尾残影；座舱顶部新增 3D 动效提示横幅与「减弱动态效果 / 开启 3D 加速」开关，关闭后零后台计时器开销，平滑降级至超低能耗经典弹簧模式
- **同心转动轴心与极坐标正立排布**：重构同轴心指针装配组件与极坐标刻度定位（$x = r\sin\theta, y = -r\cos\theta$），彻底消除锚点漂移；将中央 HUD 读数集群下移，完美消除数字与中心轴盖的遮挡冲突
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
