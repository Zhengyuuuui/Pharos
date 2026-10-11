# UsageBar

**A native macOS menu bar app that shows which dev projects you have running, which ports they listen on, and how much memory they — and your whole Mac — are using.**

[简体中文](#简体中文) · [English](#english)

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![License](https://img.shields.io/badge/license-MIT-green)

---

## English

### Why?

After a day of work you end up with a pile of `npm run dev`, `python -m http.server`, API proxies, databases… UsageBar shows them all in one place: which project owns which port, how much memory it eats, and lets you open, reveal or stop it in one click.

### Features

**Projects (menu bar popover + main window)**
- Every process of yours that **listens on a TCP port**, grouped into projects by working directory
- Ports as clickable chips → opens `http://localhost:<port>`; 🌐 marks ports exposed to the LAN (bound to `0.0.0.0`)
- Memory per project, **including all child processes** (bundlers, workers…)
- **Show in Finder** for the project directory
- **Stop project**: confirm → `SIGTERM` → offers **Force Kill** (`SIGKILL`) only if it's still alive after 1.5 s
- Per-project detail: directory, ports (local only / all interfaces), process table with full command lines

**System Memory**
- Used / Available (cached files counted as reclaimable), swap, memory pressure — same formulas as Activity Monitor
- Composition bar: App / Wired / Compressed | Cached / Free
- Memory trend over the last hour
- Top apps by memory (helper processes rolled up into their app, e.g. all Chrome helpers → "Google Chrome")

**Ports Overview**
- Projects / ports / exposed ports / total dev memory at a glance
- Port map chart (log scale, ◆ = exposed), memory-by-project bars, stacked dev-memory trend

**Favorites (saved workspaces)**
- **Add Workspace…** (sidebar ＋ or Ports Overview): pick project folders; the start command is detected from the folder's own files — `package.json` scripts (npm/pnpm/yarn/bun from the lockfile or `packageManager`), `deno.json`, `manage.py`, `bin/dev`, `Makefile` targets, docker compose, `Cargo.toml`, `go.mod`, `Package.swift`
- **☆ on any running project** saves it with the command it is *actually running with* (e.g. a running `next dev` maps back to `pnpm run dev`). Inline code (`node -e`, `python -c`), multi-line or huge command lines are never saved — they often contain tokens
- Favorites show running (ports, memory, stop) or stopped (last seen ports) in the sidebar and on Ports Overview; edit the command, pick another detected one, copy `cd … && command`
- **Open in Terminal** runs the command in a new Terminal.app window with your login shell (PATH, nvm, pyenv as usual); the process belongs to that window — Ctrl-C there stops it. UsageBar never runs commands in the background

**Disk Cleanup**
- **Pinned "Temp files" group** on top: `/tmp`, `/var/tmp`, and your `/var/folders/…/T` and `…/C` — where AI agents, CLIs and build tools constantly write scratch files. One **Clean Temp Files** button, plus an adjustable retention (keep files newer than none / 1 h / 6 h / 1 day / 3 days; default 1 day, saved across restarts), meant for cleaning every day or two
- Other caches in collapsible groups, each with its own **Clean Group** button: App caches (`~/Library/Caches`), Xcode & Apple toolchain (DerivedData, Archives, DeviceSupport, Simulator, SwiftPM, CocoaPods), Package managers (npm, pnpm, uv, pip, Gradle, Maven, Cargo, rustup, Go, Homebrew)
- Every location also has its own **Clean** button; **Clean Everything** cleans all groups at once. All destructive buttons need a second click to confirm. Decided file by file: only your own regular files older than the retention window are deleted; sockets, FIFOs, symlinks and other users' files are left alone; emptied subfolders are removed, the target folder itself is kept
- The size shown uses the exact same rule as the clean, so it's what you'll actually get back; a result banner reports freed space or why nothing could be freed
- Nested dev caches (SwiftPM, pip, Go…) under `~/Library/Caches` get their own rows and are excluded from the parent's size — no double counting

**General**
- English / 简体中文, switchable live
- Refresh every 2 / 5 / 10 / 30 s while a window is visible; low-frequency (30 s) background sampling keeps 1 hour of history
- Optional "show background apps" (Spotify, AirPlay, Docker Desktop…)
- Launch at login

### Install

Requires **macOS 14+** and the Swift toolchain (Command Line Tools are enough, no Xcode needed).

```sh
git clone https://github.com/Zhengyuuuui/usagebar.git
cd usagebar
make test      # run the test suite (includes a real listening-socket scan)
make install   # build release, bundle UsageBar.app, copy to /Applications, launch
```

### How it works

UsageBar makes **no network requests** and only reads **your own** processes, via the same kernel APIs `lsof` and Activity Monitor use:

| Data | Source |
|---|---|
| Processes, cwd, executable path | `libproc` (`proc_listallpids`, `proc_pidinfo`, `proc_pidpath`) |
| Listening TCP ports | `proc_pidfdinfo(PROC_PIDFDSOCKETINFO)` |
| Command line | `sysctl(KERN_PROCARGS2)` |
| Per-process memory | `proc_pid_rusage` → `ri_phys_footprint` |
| System memory | `host_statistics64(HOST_VM_INFO64)`, `vm.swapusage`, `kern.memorystatus_vm_pressure_level` |

Every write action is user-initiated:
- **Stop** (`SIGTERM`, then `SIGKILL` only if still alive) — never PID ≤ 1, other users' processes, or UsageBar itself
- **Disk cleanup** — only inside the fixed list of temp/cache folders, only your own regular files past the retention window
- **Open in Terminal** for a favorite — writes a small `.command` script to `~/Library/Application Support/UsageBar/launch/` and hands it to Terminal.app

### Project structure

```
Sources/
├── UsageBarCore/        # Pure Swift logic, no UI — fully unit-tested
│   ├── ProcessScanner   #   libproc + sysctl scanning, kill
│   ├── ProjectGrouper   #   processes → projects
│   ├── AppGrouper       #   processes → apps
│   ├── SystemMemory     #   machine-wide memory stats
│   ├── MemoryHistory    #   rolling 1-hour samples for charts
│   ├── DiskCleaner      #   temp/cache scan + clean (one shared per-file rule)
│   └── Workspaces       #   favorites model, start-command detection, launch script
├── UsageBar/            # SwiftUI app
│   ├── ProjectStore     #   polling, state, actions
│   ├── CleanupStore     #   disk cleanup state
│   ├── WorkspaceStore   #   favorites: persist, pin, open in Terminal
│   └── UI/              #   popover, main window, charts, cleanup, favorites, settings, L10n
└── usagebar-tests/      # Test suite (`make test`)
```

Pure Swift + Apple SDKs only — **zero third-party dependencies**. See [`AGENTS.md`](AGENTS.md) for contribution rules.

### Debug

```sh
swift build
.build/debug/UsageBar --check        # print system memory, top apps, projects/ports
.build/debug/UsageBar --check --all  # include background apps
```

---

## 简体中文

### 为什么做这个？

开发一天下来，后台堆满了 `npm run dev`、`python -m http.server`、各种反代、数据库……UsageBar 把它们集中展示：哪个项目占了哪个端口、吃了多少内存，一键打开、定位或结束。

### 功能

**项目（菜单栏弹窗 + 主窗口）**
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
- **添加工作区…**（侧栏 ＋ 或端口总览）：选择项目文件夹，从文件夹自身的文件识别启动命令——`package.json` 脚本（按锁文件或 `packageManager` 选 npm/pnpm/yarn/bun）、`deno.json`、`manage.py`、`bin/dev`、`Makefile` 目标、docker compose、`Cargo.toml`、`go.mod`、`Package.swift`
- 在任意运行中项目上点 **☆**，会连同它**实际运行的命令**一起保存（例如正在运行的 `next dev` 会还原成 `pnpm run dev`）。内联代码（`node -e`、`python -c`）、多行或超长命令行不会被保存——它们常含 token
- 常用项目在侧栏和端口总览里显示运行状态（端口、内存、结束）或未运行（上次端口）；可编辑命令、换用其他识别到的命令、复制 `cd … && 命令`
- **在终端中启动**：在新的 Terminal.app 窗口里用你的登录 shell 运行（PATH、nvm、pyenv 照常生效）；进程归该窗口所有，在那里按 Ctrl-C 即停止。UsageBar 不会在后台运行任何命令

**磁盘清理**
- **置顶的「临时文件」组**：`/tmp`、`/var/tmp`、你的 `/var/folders/…/T` 和 `…/C`——AI 助手、命令行工具和构建工具不断往这里写临时文件。一个**一键清理临时文件**按钮，加可调的保留期（保留最近：不保留 / 1 小时 / 6 小时 / 1 天 / 3 天；默认 1 天，重启后保留设置），适合每 1–2 天清理一次
- 其他缓存按组折叠显示，每组有**清理本组**按钮：应用缓存（`~/Library/Caches`）、Xcode 与 Apple 工具链（DerivedData、Archives、DeviceSupport、模拟器、SwiftPM、CocoaPods）、包管理器缓存（npm、pnpm、uv、pip、Gradle、Maven、Cargo、rustup、Go、Homebrew）
- 每个位置也有单独的**清理**按钮；**全部清理**一次清理所有组。所有删除按钮都要点两次确认。按单个文件判断：只删属于你、超过保留期的普通文件；socket、FIFO、符号链接和其他用户的文件不动；删空的子目录会回收，目标目录本身保留
- 显示的体积与清理用同一条规则，看到多少就能释放多少；结果横幅会显示释放了多少，或说明为什么没能释放
- `~/Library/Caches` 下嵌套的开发缓存（SwiftPM、pip、Go…）单列一行，并从父目录体积中排除——不会重复计数

**通用**
- 中文 / English 即时切换
- 窗口可见时每 2 / 5 / 10 / 30 秒刷新；后台 30 秒低频采样，保留 1 小时历史
- 可选「显示后台应用」（Spotify、AirPlay、Docker Desktop…）
- 登录时启动

### 安装

需要 **macOS 14+** 与 Swift 工具链（Command Line Tools 即可，无需 Xcode）。

```sh
git clone https://github.com/Zhengyuuuui/usagebar.git
cd usagebar
make test      # 运行测试（含真实监听端口扫描）
make install   # 编译 release、打包 UsageBar.app、安装到 /Applications 并启动
```

### 原理

UsageBar **不发起任何网络请求**，只读取**当前用户自己**的进程，使用与 `lsof`、活动监视器相同的内核接口（见上方英文表格）。所有写操作都由用户主动触发：
- **结束进程**（先 `SIGTERM`，仍存活才 `SIGKILL`）——不会作用于 PID ≤ 1、其他用户的进程或 UsageBar 自身
- **磁盘清理**——只在固定的临时/缓存目录内，只删属于你、超过保留期的普通文件
- 常用项目的**在终端中启动**——把一个小 `.command` 脚本写到 `~/Library/Application Support/UsageBar/launch/` 后交给 Terminal.app 打开

纯 Swift + Apple 原生 SDK，**零第三方依赖**。贡献规则见 [`AGENTS.md`](AGENTS.md)。

---

## License

[MIT](LICENSE)
