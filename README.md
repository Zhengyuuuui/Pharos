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

The only write action is the user-initiated stop (`SIGTERM` / `SIGKILL`); it never targets PID ≤ 1, other users' processes, or UsageBar itself.

### Project structure

```
Sources/
├── UsageBarCore/        # Pure Swift logic, no UI — fully unit-tested
│   ├── ProcessScanner   #   libproc + sysctl scanning, kill
│   ├── ProjectGrouper   #   processes → projects
│   ├── AppGrouper       #   processes → apps
│   ├── SystemMemory     #   machine-wide memory stats
│   └── MemoryHistory    #   rolling 1-hour samples for charts
├── UsageBar/            # SwiftUI app
│   ├── ProjectStore     #   polling, state, actions
│   └── UI/              #   popover, main window, charts, settings, L10n
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

UsageBar **不发起任何网络请求**，只读取**当前用户自己**的进程，使用与 `lsof`、活动监视器相同的内核接口（见上方英文表格）。唯一的写操作是用户主动点击的结束进程，且不会作用于 PID ≤ 1、其他用户的进程或 UsageBar 自身。

纯 Swift + Apple 原生 SDK，**零第三方依赖**。贡献规则见 [`AGENTS.md`](AGENTS.md)。

---

## License

[MIT](LICENSE)
