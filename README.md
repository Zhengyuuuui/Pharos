<p align="center">
  <img src="docs/icon.png" width="160" alt="Pharos icon">
</p>

<h1 align="center">Pharos</h1>

<p align="center">
  <b>A lighthouse for your local dev environment — a native macOS menu bar app.</b><br>
  See which projects are running, which ports they hold and how much memory they use; stop them, clean caches, launch favorites and manage browser instances (Chrome, Edge, Brave…) in one click.
</p>

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
  <img src="https://img.shields.io/badge/version-2.4-blue" alt="Version 2.4">
  <img src="https://img.shields.io/badge/updated-2026--10--16-informational" alt="Last updated 2026-10-16">
</p>

<p align="center"><sub>Last updated / 最后更新：2026-10-16 21:15 (UTC+8) · v2.4</sub></p>

<p align="center"><a href="#english">English</a> · <a href="#简体中文">简体中文</a> · <a href="#changelog--更新记录">Changelog / 更新记录</a></p>

---

## English

### Why "Pharos"?

The Pharos of Alexandria was the great lighthouse of the ancient world, watching over a busy harbor. A **port** is literally a harbor — and your Mac is full of them: `npm run dev`, `python -m http.server`, API gateways, databases, debug-mode Chrome… Pharos sits quietly in the menu bar and sweeps its light over all of them: what's docked where, how much it weighs, and lets you send it off when it's done.

The icon is that idea drawn literally: a radar-like beam sweeping a dot grid, lighting up the ports it finds.

### At a glance

| | |
|---|---|
| **Ports & memory** | Every dev project listening on a TCP port, grouped by folder, with memory incl. child processes; machine-wide memory, pressure and a 1-hour trend |
| **Disk usage** | Startup disk, external drives, network shares and disk images — used / available like Finder, updated the moment a drive is plugged in |
| **Fans & temperature** | Fan speeds and CPU / GPU / memory / SSD / battery temperatures; optional fan control (fixed speed or max) with built-in safety rules |
| **Stop processes** | `SIGTERM` first, `SIGKILL` only if it refuses; never system or other users' processes |
| **Disk cleanup** | Temp folders and dev caches, file by file, with a retention window; the size shown is exactly what gets freed |
| **Favorite projects** | Save project folders, start commands detected automatically, open in Terminal with one click |
| **Browser instances** | Chrome, Chrome Beta / Canary, Chromium, Edge and Brave — every profile folder with its debug port, proxy and memory; save favorites that stay listed with their launch command after quitting; start and quit |
| **AI agent chat databases** | Inspect, clean and backup local chat / session databases from 23+ AI IDEs and editors (Cursor, Trae, Windsurf, VS Code, Antigravity, OpenCode, Claude Code, MiniMax…); detect orphaned workspaces |
| **Packages & CLI tools** | Global CLI tools (Node, Homebrew, Rust, Python, Go) with terminal run, reveal and uninstall; multi-ecosystem project dependencies and cache inspection (.venv, node_modules, .build, target); language cache repos overview |

### Features

**Menu bar popover**
- **Overview** tab: system memory, pressure, disk usage of every volume (incl. external drives), top apps
- **Projects** tab: running projects with ports and memory, plus your browser instances (start / quit / open debug list, “Manage…” jumps to the Browsers page)
- Quick buttons to open the main window or jump straight to Disk Cleanup
- **Customizable like widgets** (Main window → Customize): a live snapshot of the popover next to its two tabs and a component library — drag blocks to reorder them, move them between tabs, drag them out to hide or in to add (memory, disk, fans & temperature, dev projects, top apps, running projects, browser instances, favorite projects). Empty tabs disappear; Reset to Default restores the original layout
- Below the library, **Running projects shown** sets how many projects the popover lists before scrolling: quick picks (3 / 5 / 8 / 10 / 15 / all running) or type a number — minimum 3, maximum the number of projects running right now (default 5). Extra projects scroll inside the list

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

**Disk usage**
- Every volume Finder shows: startup disk, other internal disks, **external drives**, network shares and mounted disk images, each labeled by type
- Used / available / capacity with the same numbers as Finder (“available” includes purgeable space; decimal units, so a 4 TB drive reads 4.0 TB)
- Format (APFS, ExFAT…), connection (USB, Thunderbolt…) and mount point; bars turn orange at 85 % and red at 95 %
- Plugging in or ejecting a drive updates the list immediately; click a volume to open it in Finder
- Hidden system volumes (VM, Preboot, simulator runtimes) are skipped. Read only — Pharos never writes to, unmounts or ejects drives

**Fans & temperature**
- Each fan's current speed, rated range (e.g. 2317–6800 rpm) and who controls it; CPU, GPU, memory, SSD, battery, power and in-case temperatures (hottest sensor of each kind), plus macOS's thermal state
- Read straight from the System Management Controller — no permission or helper needed for monitoring
- **Fan control (optional)**: when macOS keeps the fans too slow under load, hold them at a fixed speed or at max. Requires a small helper (`pharos-fand`) that runs as root — installed once from the Fans & Temperature page with macOS's own administrator password dialog, removable the same way. No Apple Developer account needed
- Safety rules enforced by the helper itself, even if Pharos is closed: any CPU/GPU sensor ≥ 95 °C forces all fans to max (released below 88 °C); no heartbeat from Pharos for 15 s → fans go back to macOS; quitting Pharos, uninstalling or shutting down hands fans back; speeds are clamped to each fan's rated range; if the firmware refuses manual mode, fans stay with macOS
- Uses undocumented SMC keys (research by [agoodkind/macos-smc-fan](https://github.com/agoodkind/macos-smc-fan) and [ThermalForge](https://github.com/ProducerGuy/ThermalForge), both MIT) — not supported by Apple, may stop working after a macOS update. Use at your own risk

**Ports overview**
- Projects / ports / exposed ports / total dev memory at a glance
- Port map chart (log scale, ◆ = exposed), memory-by-project bars, stacked dev-memory trend

**Favorite projects (workspaces)**
- **Add Workspace…**: pick project folders; the start command is detected from the folder's own files — `package.json` scripts (npm / pnpm / yarn / bun from the lockfile or `packageManager`), `deno.json`, `manage.py`, `bin/dev`, `Makefile` targets, docker compose, `Cargo.toml`, `go.mod`, `Package.swift`, `pyproject.toml` `[project.scripts]`, and entry files for script-only projects (`run.py`, `serve.py`, `gateway.py`, `server.mjs`…)
- The best match is filled in automatically; `start.sh` / `run.sh` are listed but never auto-filled, and scripts containing `git reset --hard`, `rm -rf` or `sudo` are flagged and can't be applied with one click
- **☆ on any running project** saves it with the command it is *actually running with* (e.g. a running `next dev` maps back to `pnpm run dev`). Inline code (`node -e`, `python -c`), multi-line or huge command lines are never saved — they often contain tokens
- Favorites show running (ports, memory, stop) or stopped (last seen ports); edit the command, pick another detected one, copy `cd … && command`
- **Open in Terminal** runs the command in a new window of your terminal (Terminal by default; iTerm2, Ghostty or Warp in Settings) with your login shell (PATH, nvm, pyenv as usual); the process belongs to that window — Ctrl-C there stops it. Pharos never runs commands in the background

**Browser instances (Chrome, Edge, Brave…)**
- Supports Google Chrome, Chrome Beta, Chrome Canary, Chromium, Microsoft Edge and Brave — they share Chromium's flags; pick the browser per preset
- Several browsers side by side (e.g. Chrome for work, Edge for testing, Brave for personal): a filter bar switches between them, and “All” groups instances per browser with running count and memory
- **Settings → Browsers**: every supported browser with installed / running / saved counts and its default profile folder; hide browsers you don't use and choose which one “New Instance” uses
- Every running browser, identified by its profile folder (`--user-data-dir`): debug port, proxy, start URL, signed-in profiles, memory incl. all helper processes, folder size on demand. Debug-profile browsers no longer clutter the project list
- ☆ saves a running instance as a preset with its exact flags; **New Instance** picks the next free port and a `~/chromeNNNN` folder; every field is editable
- Saved instances stay listed after you quit Chrome (“saved · not running”) with their port and the exact **launch command** — a ready-to-paste `open -na 'Google Chrome' --args …` with a copy button; ★ again removes it
- If a saved instance is relaunched elsewhere with different flags, the card says so and **Update Preset** adopts the running flags
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

**AI agent chat databases**
- Scans local SQLite and state databases across 23+ AI IDEs and assistants (Cursor, Trae, Windsurf, VS Code, Antigravity, Qoder, Cherry Studio, CodeBuddy, Kiro, OpenCode, Claude Code, Zed, MiniMax Code, Doubao, etc.)
- Database size, conversation counts, last modified date, and storage breakdown chart (by editor and database type)
- Detects orphaned databases left behind from deleted projects or uninstalled editors
- Safe database backup (`.db.bak`) and one-click cleanup with confirmation

**Packages & dependencies**
- **Global CLI software**: automatically identifies all global binaries installed across Node.js (`npm -g`, Bun, pnpm, yarn), Homebrew, Cargo / Rust, Python (`uv tool`, `pip`), and Go (`~/go/bin`)
- **Featured tools shelf**: prominent cards for core standalone software and AI agents (`claude`, `grok`, `rea`, `aider`, `codebuddy`, `wrangler`, `docker`, `uv`, `bun`, `pnpm`, `cargo-tauri`, `gh`, `rg`), with category badges, descriptions and version tags
- **Quick actions on every tool**: run `--help` test in Terminal, reveal in Finder, copy command or path, and **uninstall** (generates ecosystem-specific uninstall command and executes in Terminal after secondary confirmation)
- **Project dependency insight**: scans projects across **Node.js** (`node_modules`), **Python** (`.venv`/`venv`, `site-packages` metadata, `requirements.txt`, `pyproject.toml`), **SwiftPM** (`.build`, `Package.resolved`), **Rust** (`target`, `Cargo.lock`), and **Java** (`pom.xml`, `target`/`build`)
- Shows exact cache directory name and disk footprint in the project picker (e.g. `[.venv: 124 MB]`, `[node_modules: 1.8 GB]`, `[.build: 320 MB]`, `[target: 850 MB]`), with status indicators (ready, missing, workspace link, mismatched) and smart install command suggestions
- **Language cache repositories**: aggregates disk usage and file counts for npm cache, pnpm store, Python uv wheels, Cargo registry, Bun cache, Maven `.m2`, SwiftPM caches, and OpenJDK runtimes

**General**
- English / 简体中文, switchable live
- Refresh every 2 / 5 / 10 / 30 s while a window is visible; low-frequency (30 s) background sampling keeps 1 hour of history
- Optional “show background apps” (Spotify, AirPlay, Docker Desktop…)
- Launch at login
- Lives in the menu bar; a Dock icon appears only while the main window is open
- **Dynamic menu bar gauge icon**: real-time CoreGraphics ring icon reflecting live fill fraction (white progress arc vs. gray track) and pressure status dot (green / yellow / red)
- **Menu bar number & capacity limits**: choose to display port count, project count, memory used % or startup disk used %; customize "Max projects" and "Max ports" capacity limits in Settings to dynamically scale the gauge ring
- Optional global shortcut to open the popover (⌥⌘P, ⌃⌥P or ⌥⌘Space; off by default, no Accessibility permission needed)
- Optional local notifications (all off by default): memory pressure becomes high, a disk reaches 95 %, a favorite project stops on its own. Each fires once and re-arms only after it clears
- **Backup**: export favorites, browser presets and the popover layout to one JSON file, import on another Mac (adds new entries, skips existing ones)

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
| Disk volumes | `FileManager.mountedVolumeURLs` + `URLResourceValues` (capacity, available incl. purgeable), DiskArbitration `DADiskCopyDescription` (connection, disk image) |
| Fans & temperatures | IOKit `AppleSMC` user client (read-only keys `FNum`, `F%dAc/Mn/Mx/Tg`, `T*` sensors); `ProcessInfo.thermalState` |

Every write action is user-initiated and confirmed:
- **Stop** (`SIGTERM`, then `SIGKILL` only if still alive) — never PID ≤ 1, other users' processes, or Pharos itself
- **Disk cleanup** — only inside the fixed list of temp/cache folders, only your own regular files past the retention window
- **Open in Terminal** — writes a small `.command` script (mode 0700) to `~/Library/Application Support/Pharos/launch/` and hands it to the terminal you chose (falls back to Terminal.app if it can't open it); paths and commands are shell-quoted
- **Start / Quit a browser** — `open -na "<browser>" --args …` with the preset's flags passed one by one (no shell); quit = `SIGTERM` to the browser process, `SIGKILL` only on explicit force quit
- **Fan control** (only after you install the helper) — the root helper `pharos-fand` accepts five fixed commands (`status`, `ping`, `system`, `max`, `fixed <rpm>`) on a socket only your user can open, and writes only the fan keys (`Ftst`, `F%dMd`, `F%dTg`). Installed to `/Library/PrivilegedHelperTools/local.pharos.fand` + `/Library/LaunchDaemons/local.pharos.fand.plist`; Uninstall removes both

### Project structure

```
Sources/
├── PharosCore/          # Pure Swift logic, no UI — fully unit-tested
│   ├── ProcessScanner   #   libproc + sysctl scanning, kill
│   ├── ProjectGrouper   #   processes → projects
│   ├── AppGrouper       #   processes → apps
│   ├── SystemMemory     #   machine-wide memory stats
│   ├── DiskVolumes      #   mounted volumes: capacity, type, connection
│   ├── MemoryHistory    #   rolling 1-hour samples for charts
│   ├── DiskCleaner      #   temp/cache scan + clean (one shared per-file rule)
│   ├── Workspaces       #   favorites model, start-command detection, launch script
│   ├── ChromeInstances  #   Chromium browsers: flags parsing, presets, launch args
│   ├── Alerts           #   when to notify (fires once, re-arms after clearing)
│   ├── Backup           #   export / import format and merge rules
│   ├── SMC / Thermals   #   read fans and temperatures from the SMC
│   ├── FanPolicy        #   fan safety rules + helper protocol
│   ├── FanHelperInstall #   helper paths, launchd plist, install script
│   ├── AgentChats       #   AI agent chat databases & orphan detection
│   ├── AgentSQLiteReader#   pure Swift SQLite header & page reader
│   └── PopoverLayout    #   which blocks each popover tab shows (customizable)
├── Pharos/              # SwiftUI app
│   ├── ProjectStore     #   polling, state, actions
│   ├── CleanupStore     #   disk cleanup state
│   ├── WorkspaceStore   #   favorites: persist, pin, open in Terminal
│   ├── ChromeStore      #   Chrome presets, start / quit
│   ├── AgentChatStore   #   agent chat databases state, backup, delete
│   ├── Notifier         #   local notifications
│   ├── MenuBarSettings  #   menu bar text, global shortcut
│   ├── BackupActions    #   export / import panels
│   ├── FanStore         #   fan helper install, commands, heartbeat
│   ├── LegacyDefaults   #   one-time settings migration from UsageBar
│   └── UI/              #   popover, main window, charts, cleanup, favorites, Chrome, settings, L10n
├── pharos-fand/         # optional root helper for fan control (installed only on request)
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
| **磁盘用量** | 启动磁盘、外接硬盘、网络共享和磁盘映像的已用 / 可用，口径与 Finder 一致；接入硬盘后立即显示 |
| **风扇与温度** | 风扇转速以及 CPU / GPU / 内存 / SSD / 电池温度；可选风扇控制（固定转速或满速），内置安全规则 |
| **结束进程** | 先 `SIGTERM`，拒不退出才 `SIGKILL`；不碰系统进程和其他用户的进程 |
| **磁盘清理** | 临时目录与开发缓存，按单个文件、按保留期判断；显示的体积就是实际能释放的体积 |
| **常用项目** | 收藏项目文件夹，自动识别启动命令，一键在终端中启动 |
| **浏览器实例** | 支持 Chrome、Chrome Beta / Canary、Chromium、Edge、Brave，按配置文件夹列出每个实例，显示调试端口、代理、内存；收藏后关闭也能看到端口和启动命令；启动与退出 |
| **AI 助手会话管理** | 扫描、分析、备份与清理 23+ 种本地 AI 编程助手与编辑器（Cursor、Trae、Windsurf、VS Code、Antigravity、OpenCode、Claude Code、MiniMax 等）的会话数据库，识别孤立/残留工作区 |
| **依赖与软件包** | 全局命令行软件与核心工具统一管理（Node、Homebrew、Rust、Python、Go 等），一键终端测试、定位与二次确认卸载；全生态项目依赖与缓存目录识别（.venv、node_modules、.build、target 等）；语言缓存仓库概览 |

### 功能

**菜单栏弹窗**
- **概览**页：本机内存、内存压力、所有磁盘的用量（含外接硬盘）、应用内存排行
- **项目**页：运行中的项目（端口、内存）以及浏览器实例（启动 / 退出 / 打开调试列表，「管理…」直达「浏览器实例」页面）
- 快捷按钮：打开主窗口、直达磁盘清理
- **像小组件一样自定义**（主窗口 →「自定义」）：左边是下拉框的实时快照，旁边是两个页签和组件库——拖动组件调整顺序、在页签之间移动、拖出隐藏或拖入添加（内存、磁盘、风扇与温度、开发项目、应用排行、运行中的项目、浏览器实例、常用项目）。空页签会自动隐藏；「恢复默认」可还原原始布局
- 组件库下方的**运行中的项目显示个数**：设置下拉框里最多列出几个项目，可点快捷选项（3 / 5 / 8 / 10 / 15 / 全部运行中）或直接输入数字——最少 3 个，最多为当前正在运行的项目数（默认 5 个）。多出来的项目在列表内滚动

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

**磁盘用量**
- 列出 Finder 中可见的所有卷：启动磁盘、其他内置磁盘、**外接硬盘**、网络共享和已挂载的磁盘映像，并标注类型
- 已用 / 可用 / 容量，口径与 Finder 一致（「可用」包含可清除空间；十进制单位，4 TB 硬盘显示为 4.0 TB）
- 显示格式（APFS、ExFAT…）、接口（USB、雷雳…）和挂载位置；用量超过 85% 变橙色，超过 95% 变红色
- 接入或推出硬盘后列表立即更新；点击某个卷即在 Finder 中打开
- 隐藏的系统卷（VM、Preboot、模拟器运行时）不列出。只读——Pharos 不会写入、卸载或推出任何磁盘

**风扇与温度**
- 每个风扇的当前转速、额定范围（如 2317–6800 转/分）和当前由谁控制；CPU、GPU、内存、SSD、电池、供电和机身内部温度（每类显示最热的传感器），以及 macOS 的散热状态
- 直接从系统管理控制器（SMC）读取——监控不需要任何权限或助手
- **风扇控制（可选）**：负载高而系统风扇转得太慢时，可把风扇固定在某个转速或满速。需要一个以 root 运行的小助手（`pharos-fand`）——在「风扇与温度」页通过 macOS 自带的管理员密码框安装一次，也用同样方式卸载。不需要 Apple 开发者账号
- 安全规则由助手自己执行，即使 Pharos 关闭也有效：任一 CPU/GPU 传感器 ≥ 95°C 时所有风扇强制满速（降到 88°C 以下解除）；15 秒没有收到 Pharos 心跳即交还系统；退出 Pharos、卸载或关机时交还系统；转速限制在每个风扇的额定范围内；固件拒绝手动模式时保持系统控制
- 使用未公开的 SMC 键（参考 [agoodkind/macos-smc-fan](https://github.com/agoodkind/macos-smc-fan) 与 [ThermalForge](https://github.com/ProducerGuy/ThermalForge) 的研究，均为 MIT）——不是 Apple 支持的功能，macOS 更新后可能失效，风险自负

**端口总览**
- 项目数 / 端口数 / 对外暴露端口数 / 开发项目总内存
- 端口分布图（对数轴，◆ = 对外暴露）、各项目内存柱状图、开发项目内存堆叠趋势

**常用项目（工作区）**
- **添加工作区…**：选择项目文件夹，从文件夹自身的文件识别启动命令——`package.json` 脚本（按锁文件或 `packageManager` 选 npm / pnpm / yarn / bun）、`deno.json`、`manage.py`、`bin/dev`、`Makefile` 目标、docker compose、`Cargo.toml`、`go.mod`、`Package.swift`、`pyproject.toml` 的 `[project.scripts]`，以及纯脚本项目的入口文件（`run.py`、`serve.py`、`gateway.py`、`server.mjs`…）
- 最佳匹配自动填入；`start.sh` / `run.sh` 只列出、不自动填入；含 `git reset --hard`、`rm -rf`、`sudo` 的脚本会被标记，不能一键设为启动命令
- 在任意运行中项目上点 **☆**，会连同它**实际运行的命令**一起保存（例如正在运行的 `next dev` 会还原成 `pnpm run dev`）。内联代码（`node -e`、`python -c`）、多行或超长命令行不会被保存——它们常含 token
- 常用项目显示运行中（端口、内存、结束）或未运行（上次的端口）；可编辑命令、换用其他识别到的命令、复制 `cd … && 命令`
- **在终端中启动**：在你选的终端（默认「终端」，可在设置中改为 iTerm2、Ghostty 或 Warp）新窗口里用你的登录 shell 运行（PATH、nvm、pyenv 照常生效）；进程归该窗口所有，在那里按 Ctrl-C 即停止。Pharos 不会在后台运行任何命令

**浏览器实例（Chrome、Edge、Brave…）**
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

**磁盘清理**
- **置顶的「临时文件」组**：`/tmp`、`/var/tmp`、你的 `/var/folders/…/T` 和 `…/C`——AI 助手、命令行工具和构建工具不断往这里写临时文件。一个**一键清理临时文件**按钮，加可调的保留期（保留最近：不保留 / 1 小时 / 6 小时 / 1 天 / 3 天；默认 1 天），适合每 1–2 天清理一次
- 其他缓存按组折叠显示，每组有**清理本组**按钮：应用缓存（`~/Library/Caches`）、Xcode 与 Apple 工具链（DerivedData、Archives、DeviceSupport、模拟器、SwiftPM、CocoaPods）、包管理器缓存（npm、pnpm、uv、pip、Gradle、Maven、Cargo、rustup、Go、Homebrew）
- 每个位置有单独的**清理**按钮，还有**全部清理**；所有删除按钮都要点两次确认
- 按单个文件判断：只删属于你、超过保留期的普通文件；socket、FIFO、符号链接和其他用户的文件不动；删空的子目录会回收，目标目录本身保留
- 显示的体积与清理用同一条规则，看到多少就能释放多少；结果横幅会显示释放了多少，或说明为什么没能释放
- `~/Library/Caches` 下嵌套的开发缓存单列一行，并从父目录体积中排除——不会重复计数

**AI 助手会话与数据库管理**
- 自动发现 23+ 款主流 AI 编程助手（Cursor、Trae、Windsurf、VS Code、Antigravity、Qoder、Cherry Studio、CodeBuddy、Kiro、OpenCode、Claude Code、Zed、MiniMax Code、豆包 等）的本地会话 SQLite 数据库
- 显示各数据库大小、会话条数、修改时间与空间占用可视化图表（按编辑器与按类型构成）
- 智能检测已被删除或移除工作区的残留孤立数据库（Orphaned）
- 支持一键安全备份（`.db.bak`）及二次确认清理，释放冗余磁盘空间

**依赖与软件包**
- **全局 CLI 软件统一管理**：自动扫描 Node.js（`npm -g`、Bun、pnpm、yarn）、Homebrew、Cargo / Rust、Python（`uv tool`、`pip`）及 Go（`~/go/bin`）安装的全部命令行工具
- **核心软件与 AI 工具展架**：顶部卡片重点收录已安装的核心开发软件与终端 AI 助手（`claude`、`grok`、`rea`、`aider`、`codebuddy`、`wrangler`、`docker`、`uv`、`bun`、`pnpm`、`cargo-tauri`、`gh`、`rg` 等），带有分类标签、简要功能说明与版本号
- **每张卡片均提供完整快捷操作**：一键在终端执行 `--help` 测试、在 Finder 中定位执行文件、复制路径/指令，以及**安全卸载**（根据包管理生态自动匹配对应卸载命令，在弹出二次确认框后移交终端执行）
- **多技术栈项目依赖洞察**：支持 **Node.js**（`node_modules`）、**Python**（`.venv` / `venv`、解析 `site-packages` 元数据与 `requirements.txt`）、**SwiftPM**（`.build`、`Package.resolved`）、**Rust**（`target`、`Cargo.lock`）及 **Java**（`pom.xml`、`target`/`build`）等技术栈项目的深度扫描
- 项目选择栏与指标卡直接展示缓存目录名称与磁盘体积（如 `[.venv: 124 MB]`、`[node_modules: 1.8 GB]`、`[.build: 320 MB]`、`[target: 850 MB]`），直观标识就绪、缺失、工作区软链接与版本偏离状态，缺失依赖时针对各技术栈自动给出对应的安装指令
- **语言缓存仓库概览**：统计分析 npm 缓存、pnpm 全局硬链接仓库、Python uv Wheel 编译缓存、Cargo 依赖缓存、Bun 运行时缓存、Maven 本地库、SwiftPM 缓存及已安装的 OpenJDK 运行时

**通用**
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
| 磁盘卷 | `FileManager.mountedVolumeURLs` + `URLResourceValues`（容量、含可清除空间的可用量），DiskArbitration `DADiskCopyDescription`（接口、是否磁盘映像） |
| 风扇与温度 | IOKit `AppleSMC` 用户客户端（只读键 `FNum`、`F%dAc/Mn/Mx/Tg`、`T*` 传感器）；`ProcessInfo.thermalState` |

所有写操作都由用户主动触发并二次确认：
- **结束进程**（先 `SIGTERM`，仍存活才 `SIGKILL`）——不会作用于 PID ≤ 1、其他用户的进程或 Pharos 自身
- **磁盘清理**——只在固定的临时/缓存目录内，只删属于你、超过保留期的普通文件
- **在终端中启动**——把一个小 `.command` 脚本（权限 0700）写到 `~/Library/Application Support/Pharos/launch/` 后交给你选的终端打开（打不开时回退到「终端」）；路径和命令都经过 shell 转义
- **启动 / 退出浏览器**——用预设参数执行 `open -na "<浏览器>" --args …`，参数逐个传入（不经过 shell）；退出即向浏览器主进程发 `SIGTERM`，只有点「强制结束」才用 `SIGKILL`
- **风扇控制**（仅在你安装助手之后）——root 助手 `pharos-fand` 只在一个仅你本人能打开的 socket 上接受五条固定指令（`status`、`ping`、`system`、`max`、`fixed <转速>`），只写风扇相关的键（`Ftst`、`F%dMd`、`F%dTg`）。安装位置为 `/Library/PrivilegedHelperTools/local.pharos.fand` 和 `/Library/LaunchDaemons/local.pharos.fand.plist`；卸载会删除两者

### 项目结构

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
│   ├── FanHelperInstall #   助手路径、launchd 配置、安装脚本
│   ├── AgentChats       #   AI 助手会话数据库与孤立工作区识别
│   ├── AgentSQLiteReader#   纯 Swift SQLite 头部与页面解析
│   └── PopoverLayout    #   下拉框各页签显示哪些组件（可自定义）
├── Pharos/              # SwiftUI 应用
│   ├── ProjectStore     #   轮询、状态、操作
│   ├── CleanupStore     #   磁盘清理状态
│   ├── WorkspaceStore   #   常用项目：持久化、收藏、在终端中启动
│   ├── ChromeStore      #   Chrome 预设、启动 / 退出
│   ├── AgentChatStore   #   AI 助手数据库状态、备份、删除
│   ├── Notifier         #   本地通知
│   ├── MenuBarSettings  #   菜单栏数字、全局快捷键
│   ├── BackupActions    #   导出 / 导入面板
│   ├── FanStore         #   风扇助手安装、指令、心跳
│   ├── LegacyDefaults   #   从 UsageBar 一次性迁移设置
│   └── UI/              #   弹窗、主窗口、图表、清理、常用项目、Chrome、设置、L10n
├── pharos-fand/         # 可选的风扇控制 root 助手（仅在用户要求时安装）
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

## Changelog / 更新记录

Times are UTC+8. 时间为北京时间（UTC+8）。

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

### v2.3 — 2026-10-14 20:50

**English**
- **Dynamic menu bar gauge icon**: native CoreGraphics ring icon reflecting live fill fraction (white progress arc vs. gray track) and pressure status dot (green / yellow / red)
- **Project count option & capacity limits**: choose between project count (`projects`) and port count (`ports`) in menu bar; customize "Max projects" and "Max ports" in Settings to scale the dynamic gauge ring
- **AI agent chat databases**: inspect, backup, and clean local session databases and orphaned project records across 23+ AI programming editors (Cursor, Trae, Windsurf, VS Code, Antigravity, OpenCode, Claude Code, MiniMax Code, etc.)

**简体中文**
- **动态菜单栏仪表图标**：CoreGraphics 原生绘制的环形用量图标，展示白色进度弧与灰色底圈的动态比例，中心配备三色健康/压力状态指示点
- **新增项目数显示与容量上限设置**：菜单栏数字支持独立选择「项目数」或「端口数」；设置中提供「最多项目数」与「最多端口数」自定义上限，实时缩放菜单栏图标填充比例
- **AI 编程助手会话管理**：全面扫描与管理 23+ 款本地 AI 编辑器（Cursor、Trae、Windsurf、VS Code、Antigravity、OpenCode、Claude Code、MiniMax 等）的聊天会话与工作区数据库，支持残余孤立数据库检测、安全备份与清理

### v2.2 — 2026-10-13 14:23

**English**
- **Customize the popover like widgets** (Main window → Customize): live snapshot of the popover, its two tabs and a component library; drag blocks to reorder, move between tabs, hide or add. Eight blocks incl. a new **Favorite projects** block; empty tabs hide; Reset to Default
- **Running projects shown**: set how many projects the popover lists before the list scrolls (3 up to the number running, default 5)
- Popover layout is included in backups

**简体中文**
- **像小组件一样自定义下拉框**（主窗口 →「自定义」）：下拉框实时快照、两个页签和组件库；拖动组件调整顺序、在页签间移动、隐藏或添加。共 8 个组件，新增**常用项目**组件；空页签自动隐藏；可恢复默认
- **运行中的项目显示个数**：设置下拉框最多列出几个项目，超过后列表内滚动（最少 3 个，最多为当前运行数，默认 5 个）
- 备份中包含下拉框布局

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

### 2026-10-13 — Disk usage & browser favorites / 磁盘用量与浏览器收藏
- Disk usage for the startup disk, external drives, network shares and disk images, in the popover and the main window; Finder-style numbers, live on plug-in
- Saved browser instances stay listed after quitting, with a copyable launch command
- 磁盘用量：启动磁盘、外接硬盘、网络共享、磁盘映像，菜单栏和主窗口都可查看，口径与 Finder 一致，接入即更新
- 收藏的浏览器实例关闭后仍显示，并可复制启动命令

### 2026-10-12 — Pharos
- Renamed from UsageBar to **Pharos**, new radar-sweep icon drawn in Swift; settings migrate automatically
- Chrome instance manager, broader start-command detection, popover button fixes
- 由 UsageBar 更名为 **Pharos**，新的雷达扫描图标（Swift 绘制）；设置自动迁移
- Chrome 实例管理、更多启动命令识别、修复下拉框按钮

### 2026-10-11 — Favorites & disk cleanup / 常用项目与磁盘清理
- Favorite projects with detected start commands, open in Terminal
- Disk cleanup page with a pinned temp-files group and retention window
- 常用项目：自动识别启动命令，一键在终端中启动
- 磁盘清理页：置顶临时文件组，可设保留期

### 2026-10-10 — First version / 首个版本
- Dev ports & memory monitor for the macOS menu bar
- macOS 菜单栏开发端口与内存监控

---

## License

[MIT](LICENSE) © 2026 Zhengyuuuui. Portions © 2026 Jose Escorcia (original scaffolding).
