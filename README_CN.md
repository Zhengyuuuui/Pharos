<p align="center">
  <img src="docs/icon.png" width="160" alt="Pharos icon">
</p>

<h1 align="center">Pharos</h1>

<p align="center">
  <b>本地开发环境的灯塔 —— 原生 macOS 菜单栏工具。</b><br>
  看清哪些项目在跑、占了哪些端口、用了多少内存；一键结束进程、清理缓存、启动常用项目、管理浏览器实例（Chrome、Edge、Brave…）。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/dependencies-none-brightgreen" alt="Dependencies">
  <img src="https://img.shields.io/badge/network-none-lightgrey" alt="No network">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/version-3.0-blue" alt="Version 3.0">
  <img src="https://img.shields.io/badge/updated-2026--10--24-informational" alt="Last updated 2026-10-24">
</p>

<p align="center"><sub>最后更新 / Last updated：2026-10-24 10:46 (UTC+8) · v3.0 · 作者 / Author：zys · 模型 / Model：Gemini 4 Argon</sub></p>

<p align="center"><a href="README.md">English</a> · <b>简体中文</b> · <a href="CHANGELOG.md">更新记录 / Changelog</a></p>

---

## 为什么叫 Pharos？

Pharos（法罗斯）是古代亚历山大港的灯塔，世界七大奇迹之一，守望着繁忙的港口。**端口（port）的本义就是港口**，而你的 Mac 上停满了“船”：`npm run dev`、`python -m http.server`、API 网关、数据库、调试模式的 Chrome……Pharos 安静地待在菜单栏，用光束扫过它们：谁停在哪个泊位、有多重，用完了就送它离港。

图标正是这个意象：一道雷达般的光束扫过点阵网格，点亮它找到的端口。

---

## 一览

| 模块 | 说明 |
|---|---|
| **端口与内存监控** | 列出所有监听 TCP 端口的开发项目，按目录归组，内存含子进程；整机内存、内存压力与近 1 小时趋势 |
| **磁盘用量** | 启动磁盘、外接硬盘、网络共享和磁盘映像的已用 / 可用，口径与 Finder 一致；接入硬盘后立即显示 |
| **电池充电上限** | 复刻 macOS 15 原生「未在充电（小插头）」：电量保持在 80 / 85 / 90 / 95 / 100%，外接电源直通主板供电（电芯电流 0 mA），绝不切断适配器；新增可选「合盖与后台持续守护」，由系统级 `pharos-battd` 状态持久化接管，合盖休眠、退出 App 或重启后持续生效；一键交还 macOS 管理 |
| **风扇与温度** | 风扇转速以及 CPU / GPU / 内存 / SSD / 电池温度；全新汽车座舱仪表盘表盘（60 FPS 物理惯性阻尼与动态高斯运动模糊）与经典条状卡片随心切换；可选风扇控制（固定转速或满速），内置安全规则 |
| **结束进程** | 先 `SIGTERM`，拒不退出才 `SIGKILL`；不碰系统进程和其他用户的进程 |
| **磁盘清理** | 临时目录与开发缓存，按单个文件、按保留期判断；显示的体积就是实际能释放的体积 |
| **常用项目** | 收藏项目文件夹，自动识别启动命令，一键在终端中启动 |
| **浏览器实例** | 支持 Chrome、Chrome Beta / Canary、Chromium、Edge、Brave，按配置文件夹列出每个实例，显示调试端口、代理、内存；收藏后关闭也能看到端口和启动命令；启动与退出 |
| **AI 助手会话管理** | 扫描、分析、备份与清理 23+ 种本地 AI 编程助手与编辑器（Cursor、Trae、Windsurf、VS Code、Antigravity、OpenCode、Claude Code、MiniMax 等）的会话数据库；内置纳秒级 `DB + WAL` 指纹增量缓存，未变动大库免重复解析；识别孤立工作区，支持手动添加扫描 `/Applications` 下的任意应用 |
| **依赖与软件包** | 真实 Homebrew Cellar 与 Caskroom 软件包深度管理、环境自检与缓存清理；全局命令行软件统一管理（Node、Homebrew、Rust、Python、Go 等）；支持两阶段渐进式首屏秒开与 `mtime` + 锁文件指纹缓存的全生态项目依赖识别（`.venv`、`node_modules`、`.build`、`target` 等）；语言缓存仓库概览 |
| **全局设计系统与侧边栏** | 全局统一明度层级架构（`background` → `surface` → `fill`，支持浅/深色高对比度校准与 `Font.TextStyle` 动态字号）、圆角悬浮侧边栏浮岛与原生交通灯毛玻璃滚动模糊（支持在设置中 0%–100% 连续调节通透度并配有左上角三按钮实时预览图），彻底杜绝原生蓝条高亮反差冲突；内置响应式防挤压小组件布局引擎（`ViewThatFits`） |

---

## 功能

### 菜单栏弹窗
- **概览**页：本机内存、内存压力、所有磁盘的用量（含外接硬盘）、应用内存排行
- **项目**页：运行中的项目（端口、内存）以及浏览器实例（启动 / 退出 / 打开调试列表，「管理…」直达「浏览器实例」页面）
- 快捷按钮：打开主窗口、直达磁盘清理
- **像小组件一样自定义**（主窗口 →「自定义」）：左边是下拉框的实时快照，旁边是两个页签和组件库——拖动组件调整顺序、在页签之间移动、拖出隐藏或拖入添加（内存、磁盘、风扇与温度、开发项目、应用排行、运行中的项目、浏览器实例、常用项目）。内置 `ViewThatFits` 智能响应式防挤压布局，并列与纵向无缝适配；空页签会自动隐藏；「恢复默认」可还原原始布局
- 组件库下方的**运行中的项目显示个数**：设置下拉框里最多列出几个项目，可点快捷选项（3 / 5 / 8 / 10 / 15 / 全部运行中）或直接输入数字——最少 3 个，最多为当前正在运行的项目数（默认 5 个）。多出来的项目在列表内滚动

### 项目
- 列出你自己**正在监听 TCP 端口**的进程，按工作目录归组为项目
- 端口胶囊可点击 → 打开 `http://localhost:端口`；🌐 表示绑定 `0.0.0.0`、局域网可访问
- 项目内存**包含所有子进程**（打包器、worker 等）
- **在 Finder 中显示**项目目录
- **结束项目**：二次确认 → `SIGTERM` → 1.5 秒后仍存活才提供「强制结束」（`SIGKILL`）
- 项目详情：目录、端口（仅本机 / 所有网卡）、进程表（含完整命令行）

### 本机内存
- 已用 / 可用（缓存文件计为可回收）、交换、内存压力，口径与活动监视器一致
- 内存组成条：App / 联动 / 已压缩 | 缓存 / 空闲
- 近 1 小时内存趋势
- 按应用汇总的内存排行（Chrome 的所有 Helper 合并为「Google Chrome」）

### 磁盘用量
- 列出 Finder 中可见的所有卷：启动磁盘、其他内置磁盘、**外接硬盘**、网络共享和已挂载的磁盘映像，并标注类型
- 已用 / 可用 / 容量，口径与 Finder 一致（「可用」包含可清除空间；十进制单位，4 TB 硬盘显示为 4.0 TB）
- 显示格式（APFS、ExFAT…）、接口（USB、雷雳…）和挂载位置；用量超过 85% 变橙色，超过 95% 变红色
- 接入或推出硬盘后列表立即更新；点击某个卷即在 Finder 中打开
- 隐藏的系统卷（VM、Preboot、模拟器运行时）不列出。只读——Pharos 不会写入、卸载或推出任何磁盘

### 风扇与温度
- 每个风扇的当前转速、额定范围（如 2317–6800 转/分）和当前由谁控制；CPU、GPU、内存、SSD、电池、供电和机身内部温度（每类显示最热的传感器），以及 macOS 的散热状态
- **拟真机车仪表盘座舱**：高精度双表盘/单表盘座舱视图，配备 270° 动态转速弧环、红线区警示、手动目标刻度标记与 60 FPS 物理惯性阻尼引擎；与经典横条卡片无缝切换
- 直接从系统管理控制器（SMC）读取——监控不需要任何权限或助手
- **风扇控制（可选）**：负载高而系统风扇转得太慢时，可把风扇固定在某个转速或满速。需要一个以 root 运行的小助手（`pharos-fand`）——在「风扇与温度」页通过 macOS 自带的管理员密码框安装一次，也用同样方式卸载。不需要 Apple 开发者账号
- 安全规则由助手自己执行，即使 Pharos 关闭也有效：任一 CPU/GPU 传感器 ≥ 95°C 时所有风扇强制满速（降到 88°C 以下解除）；15 秒没有收到 Pharos 心跳即交还系统；退出 Pharos、卸载或关机时交还系统；转速限制在每个风扇的额定范围内；固件拒绝手动模式时保持系统控制
- 使用未公开的 SMC 键（参考 [agoodkind/macos-smc-fan](https://github.com/agoodkind/macos-smc-fan) 与 [ThermalForge](https://github.com/ProducerGuy/ThermalForge) 的研究，均为 MIT）——不是 Apple 支持的功能，macOS 更新后可能失效，风险自负

### 端口总览
- 项目数 / 端口数 / 对外暴露端口数 / 开发项目总内存
- 端口分布图（对数轴，◆ = 对外暴露）、各项目内存柱状图、开发项目内存堆叠趋势

### 常用项目（工作区）
- **添加工作区…**：选择项目文件夹，从文件夹自身的文件识别启动命令——`package.json` 脚本（按锁文件或 `packageManager` 选 npm / pnpm / yarn / bun）、`deno.json`、`manage.py`、`bin/dev`、`Makefile` 目标、docker compose、`Cargo.toml`、`go.mod`、`Package.swift`、`pyproject.toml` 的 `[project.scripts]`，以及纯脚本项目的入口文件（`run.py`、`serve.py`、`gateway.py`、`server.mjs`…）
- 最佳匹配自动填入；`start.sh` / `run.sh` 只列出、不自动填入；含 `git reset --hard`、`rm -rf`、`sudo` 的脚本会被标记，不能一键设为启动命令
- 在任意运行中项目上点 **☆**，会连同它**实际运行的命令**一起保存（例如正在运行的 `next dev` 会还原成 `pnpm run dev`）。内联代码（`node -e`、`python -c`）、多行或超长命令行不会被保存——它们常含 token
- 常用项目显示运行中（端口、内存、结束）或未运行（上次的端口）；可编辑命令、换用其他识别到的命令、复制 `cd … && 命令`
- **在终端中启动**：在你选的终端（默认「终端」，可在设置中改为 iTerm2、Ghostty 或 Warp）新窗口里用你的登录 shell 运行（PATH、nvm、pyenv 照常生效）；进程归该窗口所有，在那里按 Ctrl-C 即停止。Pharos 不会在后台运行任何命令

### 浏览器实例（Chrome、Edge、Brave…）
- 支持 Google Chrome、Chrome Beta、Chrome Canary、Chromium、Microsoft Edge 和 Brave——它们使用相同的 Chromium 参数；每个预设可单独选择浏览器
- 多个浏览器并行的工作环境（例如 Chrome 办公、Edge 测试、Brave 个人）：顶部筛选栏切换浏览器，「全部」时按浏览器分组，显示各自的运行数量和内存
- **设置 → 浏览器**：列出所有支持的浏览器，显示是否安装、运行中和已保存的数量以及默认配置文件夹；可隐藏不用的浏览器，并选择「新建实例」默认使用的浏览器
- 列出所有运行中的浏览器，按配置文件夹（`--user-data-dir`）区分：调试端口、代理、启动网址、已登录账号、内存（含全部 Helper 进程）、按需计算文件夹大小。调试用的 Chrome 不再混在项目列表里
- ☆ 把运行中的实例连同全部参数保存为预设；**新建实例**自动选下一个空闲端口和 `~/chromeNNNN` 文件夹；所有字段可编辑
- 收藏的实例在 Chrome 关闭后仍会列出（「已收藏 · 未运行」），显示端口和完整的**启动命令**——可直接粘贴到终端的 `open -na 'Google Chrome' --args …`，带复制按钮；再点 ★ 即取消收藏
- 如果收藏的实例在别处用不同参数重新启动，卡片会提示，点**更新预设**即可改用当前参数
- **启动**：检查文件夹未被占用、端口空闲后执行 `open -na "Google Chrome" --args …`
- **退出**：发送 `SIGTERM`（Chrome 正常关闭，下次可恢复标签页），3 秒后仍未退出才提供强制结束
- 🐞 用默认浏览器打开 `http://127.0.0.1:端口`（DevTools 调试列表）。Pharos 本身不连接调试端口

### 磁盘清理
- **置顶的「临时文件」组**：`/tmp`、`/var/tmp`、你的 `/var/folders/…/T` 和 `…/C`——AI 助手、命令行工具和构建工具不断往这里写临时文件。一个**一键清理临时文件**按钮，加可调的保留期（保留最近：不保留 / 1 小时 / 6 小时 / 1 天 / 3 天；默认 1 天），适合每 1–2 天清理一次
- 其他缓存按组折叠显示，每组有**清理本组**按钮：应用缓存（`~/Library/Caches`）、Xcode 与 Apple 工具链（DerivedData、Archives、DeviceSupport、模拟器、SwiftPM、CocoaPods）、包管理器缓存（npm、pnpm、uv、pip、Gradle、Maven、Cargo、rustup、Go、Homebrew）
- 每个位置有单独的**清理**按钮，还有**全部清理**；所有删除按钮都要点两次确认
- 按单个文件判断：只删属于你、超过保留期的普通文件；socket、FIFO、符号链接和其他用户的文件不动；删空的子目录会回收，目标目录本身保留
- 显示的体积与清理用同一条规则，看到多少就能释放多少；结果横幅会显示释放了多少，或说明为什么没能释放
- `~/Library/Caches` 下嵌套的开发缓存单列一行，并从父目录体积中排除——不会重复计数

### AI 助手会话与数据库管理
- 自动发现 23+ 款主流 AI 编程助手（Cursor、Trae、Windsurf、VS Code、Antigravity、Qoder、Cherry Studio、CodeBuddy、Kiro、OpenCode、Claude Code、Zed、MiniMax Code、豆包 等）的本地会话 SQLite 数据库
- 显示各数据库大小、会话条数、修改时间与空间占用可视化图表（按编辑器与按类型构成）
- 智能检测已被删除或移除工作区的残留孤立数据库（Orphaned）
- 总览页存储图表可收起，编辑器入口可在设置中选择「卡片网格」或「横向图标条」；点击编辑器进入独立详情页，分「数据库 / 对话」两个标签，对话只显示元数据（标题、模式、消息数、时间、所属库）
- **手动添加第三方应用**：点击 **+ 手动添加** 可选择 `/Applications` 下的任意应用，自动解析 Bundle 元数据、提取 macOS 原生高清 Retina 图标
- **定向定制扫描与智能探查**：针对手动添加的应用定向扫描 `~/Library/Application Support`、`~/Library/Containers` 及 `~/.<应用名>` 下的数据库，智能探查通用会话表结构（`chats`、`conversations`、`sessions`、`threads`、`messages`、`ItemTable` 等）；添加的应用持久化保存，支持随时单独重新扫描或移除
- 备份到你在保存面板中选择的文件（连同 `-wal`）；删除只限各编辑器的已知存储目录，支持醒目的红色二次确认弹窗，全局库不删、编辑器运行时不删

### 依赖与软件包
- **真实 Homebrew 与 Cask 深度管理**：深度解析 Apple Silicon (`/opt/homebrew`) 及 Intel (`/usr/local`) 下的 `Cellar`（解析 `INSTALL_RECEIPT.json` 获取精确版本、描述与锁定状态）与 `Caskroom`；快捷一键执行 `brew doctor`、`brew services list`、`brew outdated`
- **Homebrew 缓存清理**：在磁盘清理与依赖管理中支持识别并一键清理 `~/Library/Caches/Homebrew` 下的下载缓存与预编译 Bottle
- **多工作区项目深度发现**：自动递归扫描本机 10 大标准开发者目录（`~/Projects`、`~/Developer`、`~/Workspace`、`~/Code`、`~/src`、`~/Desktop`、`~/Documents`、`~/Downloads`、`~/dev` 以及主目录），真实发现本地项目及依赖状态
- **全局 CLI 软件统一管理**：自动扫描 Node.js（`npm -g`、Bun、pnpm、yarn）、Homebrew、Cargo / Rust、Python（`uv tool`、`pip`）及 Go（`~/go/bin`）安装的全部命令行工具
- **核心软件与 AI 工具展架**：顶部卡片重点收录已安装的核心开发软件与终端 AI 助手（`claude`、`grok`、`rea`、`aider`、`codebuddy`、`wrangler`、`docker`、`uv`、`bun`、`pnpm`、`cargo-tauri`、`gh`、`rg` 等），带有分类标签、简要功能说明与版本号
- **每张卡片均提供完整快捷操作**：一键在终端执行 `--help` 测试、在 Finder 中定位执行文件、复制路径/指令，以及**安全卸载**（根据包管理生态自动匹配对应卸载命令，在弹出二次确认框后移交终端执行）
- **多技术栈项目依赖洞察**：支持 **Node.js**（`node_modules`）、**Python**（`.venv` / `venv`、解析 `site-packages` 元数据与 `requirements.txt`）、**SwiftPM**（`.build`、`Package.resolved`）、**Rust**（`target`、`Cargo.lock`）及 **Java**（`pom.xml`、`target`/`build`）等技术栈项目的深度扫描
- 项目选择栏与指标卡直接展示缓存目录名称与磁盘体积（如 `[.venv: 124 MB]`、`[node_modules: 1.8 GB]`、`[.build: 320 MB]`、`[target: 850 MB]`），直观标识就绪、缺失、工作区软链接与版本偏离状态，缺失依赖时针对各技术栈自动给出对应的安装指令
- **语言缓存仓库概览**：统计分析 npm 缓存、pnpm 全局硬链接仓库、Python uv Wheel 编译缓存、Cargo 依赖缓存、Bun 运行时缓存、Maven 本地库、SwiftPM 缓存及已安装的 OpenJDK 运行时

### 通用
- 中文 / English 即时切换
- 窗口可见时每 2 / 5 / 10 / 30 秒刷新；后台 30 秒低频采样，保留 1 小时历史
- 可选「显示后台应用」（Spotify、AirPlay、Docker Desktop…）
- 登录时启动
- 常驻菜单栏；只有主窗口打开时才显示程序坞图标
- **动态菜单栏仪表图标**：CoreGraphics 原生绘制的环形用量图标，展示白色进度弧与灰色底圈的动态比例，中心配备三色健康/压力状态指示点（正常/预警/严重）
- **菜单栏数字与容量上限**：可选在菜单栏图标旁显示端口数、项目数、内存占用 % 或启动磁盘占用 %；选择项目数或端口数时，可在设置中自定义「最多项目数」与「最多端口数」容量上限，实时缩放菜单栏图标填充比例
- 可选全局快捷键打开下拉框（⌥⌘P、⌃⌥P 或 ⌥⌘Space；默认关闭，不需要辅助功能权限）
- 可选本地通知（默认全部关闭）：内存压力升高、磁盘用量达到 95%、常用项目自己停止。每种情况只提醒一次，恢复后才会再次提醒
- **备份**：把常用项目、浏览器预设和下拉框布局导出为一个 JSON 文件，在另一台 Mac 上导入（只添加新的条目，已有的跳过）

---

## 安装

需要 **macOS 14+** 与 Swift 工具链（Command Line Tools 即可，无需 Xcode）。

```sh
git clone https://github.com/Zhengyuuuui/pharos.git
cd pharos
make test      # 运行测试（含真实监听端口扫描）
make install   # 编译 release、打包 Pharos.app、安装到 /Applications 并启动
```

从旧版 **UsageBar** 升级：首次启动时会自动迁移设置（语言、常用项目、Chrome 预设、清理保留期等）。之后可删除 `/Applications/UsageBar.app`，并在设置里重新打开「登录时启动」。

---

## 隐私与安全

Pharos **不发起任何网络请求**、不上传任何数据，只读取**当前用户自己**的进程，使用与 `lsof`、活动监视器相同的内核接口：

| 数据 | 来源 |
|---|---|
| 进程、工作目录、可执行文件路径 | `libproc`（`proc_listallpids`、`proc_pidinfo`、`proc_pidpath`） |
| 监听中的 TCP 端口 | `proc_pidfdinfo(PROC_PIDFDSOCKETINFO)` |
| 命令行 | `sysctl(KERN_PROCARGS2)` |
| 单进程内存 | `proc_pid_rusage` → `ri_phys_footprint` |
| 本机内存 | `host_statistics64(HOST_VM_INFO64)`、`vm.swapusage`、`kern.memorystatus_vm_pressure_level` |
| 磁盘卷 | `FileManager.mountedVolumeURLs` + `URLResourceValues`（容量、含可清除空间的可用量），DiskArbitration `DADiskCopyDescription`（接口、是否磁盘映像） |
| 风扇与温度 | IOKit `AppleSMC` 用户客户端（只读键 `FNum`、`F%dAc/Mn/Mx/Tg`、`T*` 传感器）；`ProcessInfo.thermalState` |

所有写操作都由用户主动触发并二次确认：
- **结束进程**（先 `SIGTERM`，仍存活才 `SIGKILL`）——不会作用于 PID ≤ 1、其他用户的进程或 Pharos 自身
- **磁盘清理**——只在固定的临时/缓存目录内，只删属于你、超过保留期的普通文件
- **在终端中启动**——把一个小 `.command` 脚本（权限 0700）写到 `~/Library/Application Support/Pharos/launch/` 后交给你选的终端打开（打不开时回退到「终端」）；路径和命令都经过 shell 转义
- **启动 / 退出浏览器**——用预设参数执行 `open -na "<浏览器>"`，参数逐个传入（不经过 shell）；退出即向浏览器主进程发 `SIGTERM`，只有点「强制结束」才用 `SIGKILL`
- **风扇控制**（仅在你安装助手之后）——root 助手 `pharos-fand` 只在一个仅你本人能打开的 socket 上接受五条固定指令（`status`、`ping`、`system`、`max`、`fixed <转速>`），只写风扇相关的键（`Ftst`、`F%dMd`、`F%dTg`）。安装位置为 `/Library/PrivilegedHelperTools/local.pharos.fand` 和 `/Library/LaunchDaemons/local.pharos.fand.plist`；卸载会删除两者

---

## 项目结构

```
Sources/
├── PharosCore/          # 纯 Swift 逻辑，不含 UI，全部可单测
│   ├── ProcessScanner   #   libproc + sysctl 扫描、结束进程
│   ├── ProjectGrouper   #   进程 → 项目
│   ├── AppGrouper       #   进程 → 应用
│   ├── SystemMemory     #   整机内存统计
│   ├── DiskVolumes      #   已挂载的卷：容量、类型、接口
│   ├── MemoryHistory    #   1 小时滚动采样（图表用）
│   ├── DiskCleaner      #   临时/缓存目录扫描与清理（扫描与清理共用同一条逐文件规则）
│   ├── Workspaces       #   常用项目模型、启动命令识别、启动脚本
│   ├── ChromeInstances  #   Chromium 系浏览器：参数解析、预设、启动参数
│   ├── Alerts           #   何时发通知（只提醒一次，恢复后再触发）
│   ├── Backup           #   导出 / 导入格式与合并规则
│   ├── SMC / Thermals   #   从 SMC 读取风扇和温度
│   ├── FanPolicy        #   风扇安全规则 + 助手通信协议
│   ├── FanGaugeMath     #   风扇汽车仪表盘纯数学坐标与极坐标换算
│   ├── FanHelperInstall #   助手路径、launchd 配置、安装脚本
│   ├── Battery...       #   硬件电池限充、SMC 硬闸门与电源流向判定
│   ├── AgentChats       #   AI 助手会话数据库与孤立工作区识别
│   ├── AgentChatCatalog #   会话统计缓存与分类归集
│   ├── AgentSQLiteReader#   纯 Swift SQLite 头部与页面解析
│   ├── PackageScanner   #   Homebrew、全局 CLI、项目依赖、语言缓存
│   ├── PackageModels    #   依赖与包管理数据结构
│   └── PopoverLayout    #   下拉框各页签显示哪些组件（可自定义）
├── Pharos/              # SwiftUI 应用
│   ├── ProjectStore     #   轮询、状态、操作
│   ├── CleanupStore     #   磁盘清理状态
│   ├── WorkspaceStore   #   常用项目：持久化、收藏、在终端中启动
│   ├── ChromeStore      #   Chrome 预设、启动 / 退出
│   ├── AgentChatStore   #   AI 助手数据库状态、备份、删除
│   ├── PackageStore     #   依赖与包管理状态、Homebrew 诊断
│   ├── BatteryStore     #   电池限充状态、硬件监控
│   ├── Notifier         #   本地通知
│   ├── MenuBarSettings  #   菜单栏数字、全局快捷键
│   ├── BackupActions    #   导出 / 导入面板
│   ├── FanStore         #   风扇助手安装、指令、心跳
│   ├── LegacyDefaults   #   从 UsageBar 一次性迁移设置
│   └── UI/              #   弹窗、主窗口、汽车仪表盘表盘、图表、清理、常用项目、设置、L10n
├── pharos-fand/         # 可选的风扇控制 root 助手（仅在用户要求时安装）
├── pharos-battd/        # 可选的电池限充 root 守护进程（仅在用户要求时安装）
└── pharos-tests/        # 完整单元测试套件（`make test`）
Scripts/make-icon.swift  # 用 CoreGraphics 绘制双外观 App 图标；`make icon` 重新生成 Resources/Pharos.icns
```

纯 Swift + Apple 原生 SDK，**零第三方依赖**；只用 Swift Package Manager + `Makefile`，没有 Xcode 工程。贡献规则（内存管理、国际化、安全约定）见 [`AGENTS.md`](AGENTS.md)。

---

## 本地开发

```sh
swift build
make test                           # 全部断言必须通过（含真实端口扫描）
.build/debug/Pharos --check         # 打印本机内存、应用排行、项目/端口
.build/debug/Pharos --check --all   # 包含后台应用
make icon                           # 重新生成浅色/深色 App 图标
```

---

## 最新版本更新速览

### v3.0 (2026-10-24)
- **圆角悬浮侧边栏浮岛与可控交通灯毛玻璃效果**：主窗口采用圆角矩形悬浮侧边栏浮岛（内置 macOS 原生交通灯与底部状态/设置浮岛）；向下滑动侧边栏时，滑入左上角三个交通灯按钮区域的文字自动呈现真实高斯毛玻璃模糊（基于 `NSClipView.boundsDidChangeNotification` 实时驱动），并在「设置 → 菜单栏与视觉」中提供 `0% ~ 100%` 透明度调节滑块与左上角三按钮微缩实时预览卡片。
- **高对比度语义色彩校准与动态字体令牌**：`PharosColor` 在浅色与深色高对比度模式下独立校准 `background`、`surface`、`fill` 的明度阶梯差值；`PharosFont` 全面切换至基于 `Font.TextStyle` 的动态字号令牌并保留等宽数字特性。
- **全量偏好设置一键重置**：「设置 → 恢复默认设置」覆盖全部持久化偏好项（刷新频率、语言、通知、浏览器显示、终端、包管理视图、AI 会话布局、菜单栏容量与视觉开关），同时安全保留已收藏工作区、浏览器预设及风扇/电池硬件守护配置。

### v2.9 (2026-10-23)
- **电池合盖与后台持续守护（Persistent Guard）**：「电池与充电」页面新增可选「合盖与后台持续守护」开关，开启后 `pharos-battd` 将限充策略持久化至 `/Library/PrivilegedHelperTools/local.pharos.battd.state`（权限 `0600`），即使合盖休眠、DarkWake 唤醒、退出 Pharos 主程序或重启系统，仍持续守住 80% 充电上限。
- **SMC 硬件写入去重与窗口可见性自适应降频**：`pharos-battd` 对相同目标状态执行 60s 去重（消除每秒重复写 SMC 与海量日志）、主循环放宽至 3s、`.system` 模式直接轻量短路，并内置 `512 KB` 日志自动轮转；主窗口与菜单栏弹窗关闭时，`BatteryStore`、`FanStore` 与 `ProjectStore` 自动降频至 30s 静默轮询。
- **AI 会话数据库纳秒级增量指纹缓存**：基于 `AgentDatabaseFingerprint`（主库 + `-wal` 的大小与纳秒级 `mtime`）跳过未变动超大 SQLite 库（如 6.5 GB `opencode.db`）的重复解析，二次扫描近乎零耗时，同时支持手动强制全量重扫。
- **项目依赖两阶段渐进式扫描与目录体积缓存**：第一阶段毫秒级秒开渲染项目清单与声明状态，第二阶段后台渐进式回填 `node_modules` / `.venv` / `.build` / `target` 体积并按目录及锁文件 `mtime` 缓存复用。
- **核心与视图层模块化拆分**：将 `PackageScanner`、`AgentChats`/`AgentScanner`、`PackageView`、`AgentChatView` 无损拆分为职责单一的子模块，全套 765 项单测断言 100% 通过。

### v2.8 (2026-10-19)
- **拟真机车仪表盘风扇座舱**：高精度汽车座舱速度表风格表盘，270° 动态弧环、红线区警示、手动目标刻度标记与 60 FPS 物理机械惯性阻尼引擎；与经典条状卡片随心切换。
- **动态高斯运动模糊与 3D 加速**：速度突变时自动触发速度驱动的高斯运动模糊与向心残影；支持一键开启/关闭 3D 加速以平滑降级至超低能耗经典弹簧模式。
- **极坐标同心布局**：绝对同心旋转轴心，HUD 数字集群下移消除与中心轴盖的遮挡冲突。
- **SwiftUI 高斯模糊复用手册**：沉淀于 `docs/SWIFTUI_GAUSSIAN_MOTION_BLUR_GUIDE.md`。

👉 **查看完整历史更新记录**：[CHANGELOG.md](CHANGELOG.md)

---

## License

[MIT](LICENSE) © 2026 Zhengyuuuui. Portions © 2026 Jose Escorcia (original scaffolding).
