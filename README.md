<p align="center">
  <img src="docs/icon.png" width="160" alt="Pharos icon">
</p>

<h1 align="center">Pharos</h1>

<p align="center">
  <b>A lighthouse for your local dev environment — a native macOS menu bar app.</b><br>
  See which projects are running, which ports they hold and how much memory they use; stop them, clean caches, launch favorites and manage Chrome instances in one click.
</p>

<p align="center">
  <b>本地开发环境的灯塔 —— 原生 macOS 菜单栏工具。</b><br>
  看清哪些项目在跑、占了哪些端口、用了多少内存；一键结束进程、清理缓存、启动常用项目、管理 Chrome 实例。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/dependencies-none-brightgreen" alt="Dependencies">
  <img src="https://img.shields.io/badge/network-none-lightgrey" alt="No network">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

<p align="center"><a href="#english">English</a> · <a href="#简体中文">简体中文</a></p>

---

## English

### Why "Pharos"?

The Pharos of Alexandria was the great lighthouse of the ancient world, watching over a busy harbor. A **port** is literally a harbor — and your Mac is full of them: `npm run dev`, `python -m http.server`, API gateways, databases, debug-mode Chrome… Pharos sits quietly in the menu bar and sweeps its light over all of them: what's docked where, how much it weighs, and lets you send it off when it's done.

The icon is that idea drawn literally: a radar-like beam sweeping a dot grid, lighting up the ports it finds.

### At a glance

| | |
|---|---|
| **Ports & memory** | Every dev project listening on a TCP port, grouped by folder, with memory incl. child processes; machine-wide memory, pressure and a 1-hour trend |
| **Stop processes** | `SIGTERM` first, `SIGKILL` only if it refuses; never system or other users' processes |
| **Disk cleanup** | Temp folders and dev caches, file by file, with a retention window; the size shown is exactly what gets freed |
| **Favorite projects** | Save project folders, start commands detected automatically, open in Terminal with one click |
| **Chrome instances** | Every Chrome profile folder with its debug port, proxy and memory; save presets, start and quit |

### Features

**Menu bar popover**
- **Overview** tab: system memory, pressure, top apps
- **Projects** tab: running projects with ports and memory, plus your Chrome instances (start / quit / open debug list, “Manage…” jumps to the Chrome page)
- Quick buttons to open the main window or jump straight to Disk Cleanup

**Projects**
- Every process of yours that **listens on a TCP port**, grouped into projects by working directory
- Ports as clickable chips → opens `http://localhost:<port>`; 🌐 marks ports exposed to the LAN (bound to `0.0.0.0`)
- Memory per project, **including all child processes** (bundlers, workers…)
- **Show in Finder** for the project directory
- **Stop project**: confirm → `SIGTERM` → offers **Force Kill** (`SIGKILL`) only if it's still alive after 1.5 s
- Per-project detail: directory, ports (local only / all interfaces), process table with full command lines

**System memory**
- Used / Available (cached files counted as reclaimable), swap, memory pressure — same formulas as Activity Monitor
- Composition bar: App / Wired / Compressed | Cached / Free
- Memory trend over the last hour
- Top apps by memory (helper processes rolled up into their app, e.g. all Chrome helpers → “Google Chrome”)

**Ports overview**
- Projects / ports / exposed ports / total dev memory at a glance
- Port map chart (log scale, ◆ = exposed), memory-by-project bars, stacked dev-memory trend

**Favorite projects (workspaces)**
- **Add Workspace…**: pick project folders; the start command is detected from the folder's own files — `package.json` scripts (npm / pnpm / yarn / bun from the lockfile or `packageManager`), `deno.json`, `manage.py`, `bin/dev`, `Makefile` targets, docker compose, `Cargo.toml`, `go.mod`, `Package.swift`, `pyproject.toml` `[project.scripts]`, and entry files for script-only projects (`run.py`, `serve.py`, `gateway.py`, `server.mjs`…)
- The best match is filled in automatically; `start.sh` / `run.sh` are listed but never auto-filled, and scripts containing `git reset --hard`, `rm -rf` or `sudo` are flagged and can't be applied with one click
- **☆ on any running project** saves it with the command it is *actually running with* (e.g. a running `next dev` maps back to `pnpm run dev`). Inline code (`node -e`, `python -c`), multi-line or huge command lines are never saved — they often contain tokens
- Favorites show running (ports, memory, stop) or stopped (last seen ports); edit the command, pick another detected one, copy `cd … && command`
- **Open in Terminal** runs the command in a new Terminal.app window with your login shell (PATH, nvm, pyenv as usual); the process belongs to that window — Ctrl-C there stops it. Pharos never runs commands in the background

**Chrome instances**
- Every running Chrome browser, identified by its profile folder (`--user-data-dir`): debug port, proxy, start URL, signed-in profiles, memory incl. all helper processes, folder size on demand. Debug-profile browsers no longer clutter the project list
- ☆ saves a running instance as a preset with its exact flags; **New Instance** picks the next free port and a `~/chromeNNNN` folder; every field is editable
- **Start** runs `open -na "Google Chrome" --args …` after checking the folder isn't already open and the port is free
- **Quit** sends `SIGTERM` (normal Chrome shutdown, tabs restore next time); force quit is offered only if it's still open after 3 s
- 🐞 opens `http://127.0.0.1:<port>` (DevTools target list) in your default browser. Pharos itself never connects to debug ports

**Disk cleanup**
- **Pinned “Temp files” group**: `/tmp`, `/var/tmp`, and your `/var/folders/…/T` and `…/C` — where AI agents, CLIs and build tools constantly write scratch files. One **Clean Temp Files** button with an adjustable retention (keep files newer than none / 1 h / 6 h / 1 day / 3 days; default 1 day), meant for cleaning every day or two
- Other caches in collapsible groups, each with its own **Clean Group** button: App caches (`~/Library/Caches`), Xcode & Apple toolchain (DerivedData, Archives, DeviceSupport, Simulator, SwiftPM, CocoaPods), package managers (npm, pnpm, uv, pip, Gradle, Maven, Cargo, rustup, Go, Homebrew)
- Per-location **Clean** buttons and **Clean Everything**; every destructive button needs a second click
- Decided file by file: only your own regular files older than the retention window are deleted; sockets, FIFOs, symlinks and other users' files are left alone; emptied subfolders are removed, the target folder itself is kept
- The size shown uses the exact same rule as the clean, so it's what you'll actually get back; a result banner reports freed space or why nothing could be freed
- Nested dev caches under `~/Library/Caches` get their own rows and are excluded from the parent's size — no double counting

**General**
- English / 简体中文, switchable live
- Refresh every 2 / 5 / 10 / 30 s while a window is visible; low-frequency (30 s) background sampling keeps 1 hour of history
- Optional “show background apps” (Spotify, AirPlay, Docker Desktop…)
- Launch at login
- Lives in the menu bar; a Dock icon appears only while the main window is open

### Install

Requires **macOS 14+** and the Swift toolchain (Command Line Tools are enough, no Xcode needed).

```sh
git clone https://github.com/Zhengyuuuui/pharos.git
cd pharos
make test      # run the test suite (includes a real listening-socket scan)
make install   # build release, bundle Pharos.app, copy to /Applications, launch
```

Upgrading from the old **UsageBar** build: your settings (language, favorites, Chrome presets, cleanup retention…) are copied over on first launch. Delete `/Applications/UsageBar.app` afterwards, and re-enable “Launch at login” in Settings.

### Privacy & safety

Pharos makes **no network requests**, uploads nothing, and only reads **your own** processes, via the same kernel APIs `lsof` and Activity Monitor use:

| Data | Source |
|---|---|
| Processes, cwd, executable path | `libproc` (`proc_listallpids`, `proc_pidinfo`, `proc_pidpath`) |
| Listening TCP ports | `proc_pidfdinfo(PROC_PIDFDSOCKETINFO)` |
| Command line | `sysctl(KERN_PROCARGS2)` |
| Per-process memory | `proc_pid_rusage` → `ri_phys_footprint` |
| System memory | `host_statistics64(HOST_VM_INFO64)`, `vm.swapusage`, `kern.memorystatus_vm_pressure_level` |

Every write action is user-initiated and confirmed:
- **Stop** (`SIGTERM`, then `SIGKILL` only if still alive) — never PID ≤ 1, other users' processes, or Pharos itself
- **Disk cleanup** — only inside the fixed list of temp/cache folders, only your own regular files past the retention window
- **Open in Terminal** — writes a small `.command` script (mode 0700) to `~/Library/Application Support/Pharos/launch/` and hands it to Terminal.app; paths and commands are shell-quoted
- **Start / Quit Chrome** — `open -na "Google Chrome" --args …` with the preset's flags passed one by one (no shell); quit = `SIGTERM` to the browser process, `SIGKILL` only on explicit force quit

### Project structure

```
Sources/
├── PharosCore/          # Pure Swift logic, no UI — fully unit-tested
│   ├── ProcessScanner   #   libproc + sysctl scanning, kill
│   ├── ProjectGrouper   #   processes → projects
│   ├── AppGrouper       #   processes → apps
│   ├── SystemMemory     #   machine-wide memory stats
│   ├── MemoryHistory    #   rolling 1-hour samples for charts
│   ├── DiskCleaner      #   temp/cache scan + clean (one shared per-file rule)
│   ├── Workspaces       #   favorites model, start-command detection, launch script
│   └── ChromeInstances  #   Chrome flags parsing, presets, launch args
├── Pharos/              # SwiftUI app
│   ├── ProjectStore     #   polling, state, actions
│   ├── CleanupStore     #   disk cleanup state
│   ├── WorkspaceStore   #   favorites: persist, pin, open in Terminal
│   ├── ChromeStore      #   Chrome presets, start / quit
│   ├── LegacyDefaults   #   one-time settings migration from UsageBar
│   └── UI/              #   popover, main window, charts, cleanup, favorites, Chrome, settings, L10n
└── pharos-tests/        # Test suite (`make test`)
Scripts/make-icon.swift  # draws the app icon in CoreGraphics; `make icon` rebuilds Resources/Pharos.icns
```

Pure Swift + Apple SDKs only — **zero third-party dependencies**, Swift Package Manager + `Makefile`, no Xcode project. See [`AGENTS.md`](AGENTS.md) for contribution rules (memory management, i18n, safety).

### Development

```sh
swift build
make test                           # all assertions must pass
.build/debug/Pharos --check         # print system memory, top apps, projects/ports
.build/debug/Pharos --check --all   # include background apps
make icon                           # regenerate the app icon from Scripts/make-icon.swift
```

---

## 简体中文

### 为什么叫 Pharos？

Pharos（法罗斯）是古代亚历山大港的灯塔，世界七大奇迹之一，守望着繁忙的港口。**端口（port）的本义就是港口**，而你的 Mac 上停满了“船”：`npm run dev`、`python -m http.server`、API 网关、数据库、调试模式的 Chrome……Pharos 安静地待在菜单栏，用光束扫过它们：谁停在哪个泊位、有多重，用完了就送它离港。

图标正是这个意象：一道雷达般的光束扫过点阵网格，点亮它找到的端口。

### 一览

| | |
|---|---|
| **端口与内存监控** | 列出所有监听 TCP 端口的开发项目，按目录归组，内存含子进程；整机内存、内存压力与近 1 小时趋势 |
| **结束进程** | 先 `SIGTERM`，拒不退出才 `SIGKILL`；不碰系统进程和其他用户的进程 |
| **磁盘清理** | 临时目录与开发缓存，按单个文件、按保留期判断；显示的体积就是实际能释放的体积 |
| **常用项目** | 收藏项目文件夹，自动识别启动命令，一键在终端中启动 |
| **Chrome 实例** | 按配置文件夹列出每个 Chrome，显示调试端口、代理、内存；保存预设、启动与退出 |

### 功能

**菜单栏弹窗**
- **概览**页：本机内存、内存压力、应用内存排行
- **项目**页：运行中的项目（端口、内存）以及 Chrome 实例（启动 / 退出 / 打开调试列表，「管理…」直达 Chrome 页面）
- 快捷按钮：打开主窗口、直达磁盘清理

**项目**
- 列出你自己**正在监听 TCP 端口**的进程，按工作目录归组为项目
- 端口胶囊可点击 → 打开 `http://localhost:端口`；🌐 表示绑定 `0.0.0.0`、局域网可访问
- 项目内存**包含所有子进程**（打包器、worker 等）
- **在 Finder 中显示**项目目录
- **结束项目**：二次确认 → `SIGTERM` → 1.5 秒后仍存活才提供「强制结束」（`SIGKILL`）
- 项目详情：目录、端口（仅本机 / 所有网卡）、进程表（含完整命令行）

**本机内存**
- 已用 / 可用（缓存文件计为可回收）、交换、内存压力，口径与活动监视器一致
- 内存组成条：App / 联动 / 已压缩 | 缓存 / 空闲
- 近 1 小时内存趋势
- 按应用汇总的内存排行（Chrome 的所有 Helper 合并为「Google Chrome」）

**端口总览**
- 项目数 / 端口数 / 对外暴露端口数 / 开发项目总内存
- 端口分布图（对数轴，◆ = 对外暴露）、各项目内存柱状图、开发项目内存堆叠趋势

**常用项目（工作区）**
- **添加工作区…**：选择项目文件夹，从文件夹自身的文件识别启动命令——`package.json` 脚本（按锁文件或 `packageManager` 选 npm / pnpm / yarn / bun）、`deno.json`、`manage.py`、`bin/dev`、`Makefile` 目标、docker compose、`Cargo.toml`、`go.mod`、`Package.swift`、`pyproject.toml` 的 `[project.scripts]`，以及纯脚本项目的入口文件（`run.py`、`serve.py`、`gateway.py`、`server.mjs`…）
- 最佳匹配自动填入；`start.sh` / `run.sh` 只列出、不自动填入；含 `git reset --hard`、`rm -rf`、`sudo` 的脚本会被标记，不能一键设为启动命令
- 在任意运行中项目上点 **☆**，会连同它**实际运行的命令**一起保存（例如正在运行的 `next dev` 会还原成 `pnpm run dev`）。内联代码（`node -e`、`python -c`）、多行或超长命令行不会被保存——它们常含 token
- 常用项目显示运行中（端口、内存、结束）或未运行（上次的端口）；可编辑命令、换用其他识别到的命令、复制 `cd … && 命令`
- **在终端中启动**：在新的 Terminal.app 窗口里用你的登录 shell 运行（PATH、nvm、pyenv 照常生效）；进程归该窗口所有，在那里按 Ctrl-C 即停止。Pharos 不会在后台运行任何命令

**Chrome 实例**
- 列出所有运行中的 Chrome 浏览器，按配置文件夹（`--user-data-dir`）区分：调试端口、代理、启动网址、已登录账号、内存（含全部 Helper 进程）、按需计算文件夹大小。调试用的 Chrome 不再混在项目列表里
- ☆ 把运行中的实例连同全部参数保存为预设；**新建实例**自动选下一个空闲端口和 `~/chromeNNNN` 文件夹；所有字段可编辑
- **启动**：检查文件夹未被占用、端口空闲后执行 `open -na "Google Chrome" --args …`
- **退出**：发送 `SIGTERM`（Chrome 正常关闭，下次可恢复标签页），3 秒后仍未退出才提供强制结束
- 🐞 用默认浏览器打开 `http://127.0.0.1:端口`（DevTools 调试列表）。Pharos 本身不连接调试端口

**磁盘清理**
- **置顶的「临时文件」组**：`/tmp`、`/var/tmp`、你的 `/var/folders/…/T` 和 `…/C`——AI 助手、命令行工具和构建工具不断往这里写临时文件。一个**一键清理临时文件**按钮，加可调的保留期（保留最近：不保留 / 1 小时 / 6 小时 / 1 天 / 3 天；默认 1 天），适合每 1–2 天清理一次
- 其他缓存按组折叠显示，每组有**清理本组**按钮：应用缓存（`~/Library/Caches`）、Xcode 与 Apple 工具链（DerivedData、Archives、DeviceSupport、模拟器、SwiftPM、CocoaPods）、包管理器缓存（npm、pnpm、uv、pip、Gradle、Maven、Cargo、rustup、Go、Homebrew）
- 每个位置有单独的**清理**按钮，还有**全部清理**；所有删除按钮都要点两次确认
- 按单个文件判断：只删属于你、超过保留期的普通文件；socket、FIFO、符号链接和其他用户的文件不动；删空的子目录会回收，目标目录本身保留
- 显示的体积与清理用同一条规则，看到多少就能释放多少；结果横幅会显示释放了多少，或说明为什么没能释放
- `~/Library/Caches` 下嵌套的开发缓存单列一行，并从父目录体积中排除——不会重复计数

**通用**
- 中文 / English 即时切换
- 窗口可见时每 2 / 5 / 10 / 30 秒刷新；后台 30 秒低频采样，保留 1 小时历史
- 可选「显示后台应用」（Spotify、AirPlay、Docker Desktop…）
- 登录时启动
- 常驻菜单栏；只有主窗口打开时才显示程序坞图标

### 安装

需要 **macOS 14+** 与 Swift 工具链（Command Line Tools 即可，无需 Xcode）。

```sh
git clone https://github.com/Zhengyuuuui/pharos.git
cd pharos
make test      # 运行测试（含真实监听端口扫描）
make install   # 编译 release、打包 Pharos.app、安装到 /Applications 并启动
```

从旧版 **UsageBar** 升级：首次启动时会自动迁移设置（语言、常用项目、Chrome 预设、清理保留期等）。之后可删除 `/Applications/UsageBar.app`，并在设置里重新打开「登录时启动」。

### 隐私与安全

Pharos **不发起任何网络请求**、不上传任何数据，只读取**当前用户自己**的进程，使用与 `lsof`、活动监视器相同的内核接口：

| 数据 | 来源 |
|---|---|
| 进程、工作目录、可执行文件路径 | `libproc`（`proc_listallpids`、`proc_pidinfo`、`proc_pidpath`） |
| 监听中的 TCP 端口 | `proc_pidfdinfo(PROC_PIDFDSOCKETINFO)` |
| 命令行 | `sysctl(KERN_PROCARGS2)` |
| 单进程内存 | `proc_pid_rusage` → `ri_phys_footprint` |
| 本机内存 | `host_statistics64(HOST_VM_INFO64)`、`vm.swapusage`、`kern.memorystatus_vm_pressure_level` |

所有写操作都由用户主动触发并二次确认：
- **结束进程**（先 `SIGTERM`，仍存活才 `SIGKILL`）——不会作用于 PID ≤ 1、其他用户的进程或 Pharos 自身
- **磁盘清理**——只在固定的临时/缓存目录内，只删属于你、超过保留期的普通文件
- **在终端中启动**——把一个小 `.command` 脚本（权限 0700）写到 `~/Library/Application Support/Pharos/launch/` 后交给 Terminal.app 打开；路径和命令都经过 shell 转义
- **启动 / 退出 Chrome**——用预设参数执行 `open -na "Google Chrome" --args …`，参数逐个传入（不经过 shell）；退出即向浏览器主进程发 `SIGTERM`，只有点「强制结束」才用 `SIGKILL`

### 项目结构

```
Sources/
├── PharosCore/          # 纯 Swift 逻辑，不含 UI，全部可单测
│   ├── ProcessScanner   #   libproc + sysctl 扫描、结束进程
│   ├── ProjectGrouper   #   进程 → 项目
│   ├── AppGrouper       #   进程 → 应用
│   ├── SystemMemory     #   整机内存统计
│   ├── MemoryHistory    #   1 小时滚动采样（图表用）
│   ├── DiskCleaner      #   临时/缓存目录扫描与清理（扫描与清理共用同一条逐文件规则）
│   ├── Workspaces       #   常用项目模型、启动命令识别、启动脚本
│   └── ChromeInstances  #   Chrome 参数解析、预设、启动参数
├── Pharos/              # SwiftUI 应用
│   ├── ProjectStore     #   轮询、状态、操作
│   ├── CleanupStore     #   磁盘清理状态
│   ├── WorkspaceStore   #   常用项目：持久化、收藏、在终端中启动
│   ├── ChromeStore      #   Chrome 预设、启动 / 退出
│   ├── LegacyDefaults   #   从 UsageBar 一次性迁移设置
│   └── UI/              #   弹窗、主窗口、图表、清理、常用项目、Chrome、设置、L10n
└── pharos-tests/        # 测试（`make test`）
Scripts/make-icon.swift  # 用 CoreGraphics 绘制 App 图标；`make icon` 重新生成 Resources/Pharos.icns
```

纯 Swift + Apple 原生 SDK，**零第三方依赖**；只用 Swift Package Manager + `Makefile`，没有 Xcode 工程。贡献规则（内存管理、国际化、安全约定）见 [`AGENTS.md`](AGENTS.md)。

### 开发

```sh
swift build
make test                           # 全部断言必须通过
.build/debug/Pharos --check         # 打印本机内存、应用排行、项目/端口
.build/debug/Pharos --check --all   # 包含后台应用
make icon                           # 用 Scripts/make-icon.swift 重新生成 App 图标
```

---

## License

[MIT](LICENSE) © 2026 Zhengyuuuui. Portions © 2026 Jose Escorcia (original scaffolding).
