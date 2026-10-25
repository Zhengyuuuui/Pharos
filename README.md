<p align="center">
  <img src="docs/icon.png" width="160" alt="Pharos icon">
</p>

<h1 align="center">Pharos</h1>

<p align="center">
  <b>A lighthouse for your local dev environment — a native macOS menu bar app.</b><br>
  See which projects are running, which ports they hold and how much memory they use; stop them, clean caches, launch favorites and manage browser instances (Chrome, Edge, Brave…) in one click.
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

<p align="center"><sub>Last updated / 最后更新：2026-10-24 10:46 (UTC+8) · v3.0 · Author / 作者：zys · Model / 模型：Gemini 4 Argon</sub></p>

<p align="center"><b>English</b> · <a href="README_CN.md">简体中文</a> · <a href="CHANGELOG.md">Changelog / 更新记录</a></p>

---

## Why "Pharos"?

The Pharos of Alexandria was the great lighthouse of the ancient world, watching over a busy harbor. A **port** is literally a harbor — and your Mac is full of them: `npm run dev`, `python -m http.server`, API gateways, databases, debug-mode Chrome… Pharos sits quietly in the menu bar and sweeps its light over all of them: what's docked where, how much it weighs, and lets you send it off when it's done.

The icon is that idea drawn literally: a radar-like beam sweeping a dot grid, lighting up the ports it finds.

---

## At a glance

| Section | Capabilities |
|---|---|
| **Ports & memory** | Every dev project listening on a TCP port, grouped by folder, with memory incl. child processes; machine-wide memory, pressure and a 1-hour trend |
| **Disk usage** | Startup disk, external drives, network shares and disk images — used / available like Finder, updated the moment a drive is plugged in |
| **Battery charge limit** | macOS 15 native-style "Not Charging" plug state: hold the battery at 80 / 85 / 90 / 95 / 100 %, adapter powers the Mac directly (0 mA cell current), never cuts the adapter; optional **Persistent Lid-Closed & Background Guard** survives lid sleep, app exit, and reboots via state-persisted root daemon; one click back to macOS |
| **Fans & temperature** | Fan speeds and CPU / GPU / memory / SSD / battery temperatures; automotive cockpit speedometer dials (60 FPS mechanical inertia engine & dynamic motion blur) & classic horizontal bars; optional fan control (fixed speed or max) with built-in safety rules |
| **Stop processes** | `SIGTERM` first, `SIGKILL` only if it refuses; never system or other users' processes |
| **Disk cleanup** | Temp folders and dev caches, file by file, with a retention window; the size shown is exactly what gets freed |
| **Favorite projects** | Save project folders, start commands detected automatically, open in Terminal with one click |
| **Browser instances** | Chrome, Chrome Beta / Canary, Chromium, Edge and Brave — every profile folder with its debug port, proxy and memory; save favorites that stay listed with their launch command after quitting; start and quit |
| **AI agent chat databases** | Inspect, clean and backup local chat / session databases from 23+ AI IDEs and editors (Cursor, Trae, Windsurf, VS Code, Antigravity, OpenCode, Claude Code, MiniMax…); nanosecond-precision incremental fingerprint cache (`DB + WAL` size/mtime) skips unchanged databases; detect orphaned workspaces; manually add and scan any custom application under `/Applications` |
| **Packages & CLI tools** | Real Homebrew Cellar formula & Caskroom package scanning, diagnostics (`brew doctor`/`services`) and cache cleanup; global CLI tools (Node, Homebrew, Rust, Python, Go) with terminal run, reveal and uninstall; two-stage progressive project dependency scanning with `mtime` + lockfile fingerprint cache across 10 developer workspace directories (`.venv`, `node_modules`, `.build`, `target`); language cache repos overview |
| **Design system & sidebar** | Strict 3-step lightness hierarchy (`background` → `surface` → `fill` with calibrated high-contrast tokens and `Font.TextStyle` dynamic typography), floating sidebar island with native traffic lights and customizable frosted-glass scroll blur (0%–100% slider + live top-left 3-buttons preview in Settings), zero AppKit blue highlight clashing, and adaptive responsive popover customizer (`ViewThatFits`) |

---

## Features

### Menu bar popover
- **Overview** tab: system memory, pressure, disk usage of every volume (incl. external drives), top apps
- **Projects** tab: running projects with ports and memory, plus your browser instances (start / quit / open debug list, “Manage…” jumps to the Browsers page)
- Quick buttons to open the main window or jump straight to Disk Cleanup
- **Customizable like widgets** (Main window → Customize): a live snapshot of the popover next to its two tabs and a component library — drag blocks to reorder them, move them between tabs, drag them out to hide or in to add (memory, disk, fans & temperature, dev projects, top apps, running projects, browser instances, favorite projects). Adaptive side-by-side or stacked layout (`ViewThatFits`) prevents window squeezing; Empty tabs disappear; Reset to Default restores the original layout
- Below the library, **Running projects shown** sets how many projects the popover lists before scrolling: quick picks (3 / 5 / 8 / 10 / 15 / all running) or type a number — minimum 3, maximum the number of projects running right now (default 5). Extra projects scroll inside the list

### Projects
- Every process of yours that **listens on a TCP port**, grouped into projects by working directory
- Ports as clickable chips → opens `http://localhost:<port>`; 🌐 marks ports exposed to the LAN (bound to `0.0.0.0`)
- Memory per project, **including all child processes** (bundlers, workers…)
- **Show in Finder** for the project directory
- **Stop project**: confirm → `SIGTERM` → offers **Force Kill** (`SIGKILL`) only if it's still alive after 1.5 s
- Per-project detail: directory, ports (local only / all interfaces), process table with full command lines

### System memory
- Used / Available (cached files counted as reclaimable), swap, memory pressure — same formulas as Activity Monitor
- Composition bar: App / Wired / Compressed | Cached / Free
- Memory trend over the last hour
- Top apps by memory (helper processes rolled up into their app, e.g. all Chrome helpers → “Google Chrome”)

### Disk usage
- Every volume Finder shows: startup disk, other internal disks, **external drives**, network shares and mounted disk images, each labeled by type
- Used / available / capacity with the same numbers as Finder (“available” includes purgeable space; decimal units, so a 4 TB drive reads 4.0 TB)
- Format (APFS, ExFAT…), connection (USB, Thunderbolt…) and mount point; bars turn orange at 85 % and red at 95 %
- Plugging in or ejecting a drive updates the list immediately; click a volume to open it in Finder
- Hidden system volumes (VM, Preboot, simulator runtimes) are skipped. Read only — Pharos never writes to, unmounts or ejects drives

### Fans & temperature
- Each fan's current speed, rated range (e.g. 2317–6800 rpm) and who controls it; CPU, GPU, memory, SSD, battery, power and in-case temperatures (hottest sensor of each kind), plus macOS's thermal state
- **Automotive Cockpit Speedometer**: High-precision automotive tachometer dials with a 270° sweep arc, redline danger zone, upright polar numerals, and target speed notch marker, driven by an authentic 60 FPS mechanical inertia engine ($3t^2 - 2t^3$); smoothly toggle back to classic horizontal bars anytime
- Read straight from the System Management Controller — no permission or helper needed for monitoring
- **Fan control (optional)**: when macOS keeps the fans too slow under load, hold them at a fixed speed or at max. Requires a small helper (`pharos-fand`) that runs as root — installed once from the Fans & Temperature page with macOS's own administrator password dialog, removable the same way. No Apple Developer account needed
- Safety rules enforced by the helper itself, even if Pharos is closed: any CPU/GPU sensor ≥ 95 °C forces all fans to max (released below 88 °C); no heartbeat from Pharos for 15 s → fans go back to macOS; quitting Pharos, uninstalling or shutting down hands fans back; speeds are clamped to each fan's rated range; if the firmware refuses manual mode, fans stay with macOS
- Uses undocumented SMC keys (research by [agoodkind/macos-smc-fan](https://github.com/agoodkind/macos-smc-fan) and [ThermalForge](https://github.com/ProducerGuy/ThermalForge), both MIT) — not supported by Apple, may stop working after a macOS update. Use at your own risk

### Ports overview
- Projects / ports / exposed ports / total dev memory at a glance
- Port map chart (log scale, ◆ = exposed), memory-by-project bars, stacked dev-memory trend

### Favorite projects (workspaces)
- **Add Workspace…**: pick project folders; the start command is detected from the folder's own files — `package.json` scripts (npm / pnpm / yarn / bun from the lockfile or `packageManager`), `deno.json`, `manage.py`, `bin/dev`, `Makefile` targets, docker compose, `Cargo.toml`, `go.mod`, `Package.swift`, `pyproject.toml` `[project.scripts]`, and entry files for script-only projects (`run.py`, `serve.py`, `gateway.py`, `server.mjs`…)
- The best match is filled in automatically; `start.sh` / `run.sh` are listed but never auto-filled, and scripts containing `git reset --hard`, `rm -rf` or `sudo` are flagged and can't be applied with one click
- **☆ on any running project** saves it with the command it is *actually running with* (e.g. a running `next dev` maps back to `pnpm run dev`). Inline code (`node -e`, `python -c`), multi-line or huge command lines are never saved — they often contain tokens
- Favorites show running (ports, memory, stop) or stopped (last seen ports); edit the command, pick another detected one, copy `cd … && command`
- **Open in Terminal** runs the command in a new window of your terminal (Terminal by default; iTerm2, Ghostty or Warp in Settings) with your login shell (PATH, nvm, pyenv as usual); the process belongs to that window — Ctrl-C there stops it. Pharos never runs commands in the background

### Browser instances (Chrome, Edge, Brave…)
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

### Disk cleanup
- **Pinned “Temp files” group**: `/tmp`, `/var/tmp`, and your `/var/folders/…/T` and `…/C` — where AI agents, CLIs and build tools constantly write scratch files. One **Clean Temp Files** button with an adjustable retention (keep files newer than none / 1 h / 6 h / 1 day / 3 days; default 1 day), meant for cleaning every day or two
- Other caches in collapsible groups, each with its own **Clean Group** button: App caches (`~/Library/Caches`), Xcode & Apple toolchain (DerivedData, Archives, DeviceSupport, Simulator, SwiftPM, CocoaPods), package managers (npm, pnpm, uv, pip, Gradle, Maven, Cargo, rustup, Go, Homebrew)
- Per-location **Clean** buttons and **Clean Everything**; every destructive button needs a second click
- Decided file by file: only your own regular files older than the retention window are deleted; sockets, FIFOs, symlinks and other users' files are left alone; emptied subfolders are removed, the target folder itself is kept
- The size shown uses the exact same rule as the clean, so it's what you'll actually get back; a result banner reports freed space or why nothing could be freed
- Nested dev caches under `~/Library/Caches` get their own rows and are excluded from the parent's size — no double counting

### AI agent chat databases
- Scans local SQLite and state databases across 23+ AI IDEs and assistants (Cursor, Trae, Windsurf, VS Code, Antigravity, Qoder, Cherry Studio, CodeBuddy, Kiro, OpenCode, Claude Code, Zed, MiniMax Code, Doubao, etc.)
- Database size, conversation counts, last modified date, and storage breakdown chart (by editor and database type)
- Detects orphaned databases left behind from deleted projects or uninstalled editors
- Overview with a collapsible storage chart and an editor grid or icon strip (Settings); each editor opens its own detail page with **Databases** and **Conversations** tabs; conversations show metadata only (title, mode, messages, dates, database)
- **Manual application addition**: click **+ Add App** to select any `.app` bundle from `/Applications` or custom locations; automatically extracts bundle identifiers, names, and native macOS icons via `NSWorkspace`
- **Targeted custom scanner**: probes associated `~/Library/Application Support`, `~/Library/Containers`, and `~/.<app>` directories for SQLite session tables with universal schema fallback (`chats`, `conversations`, `sessions`, `threads`, `messages`, `ItemTable`); custom applications persist in user preferences and can be rescanned or removed at any time
- Backup to a file you pick (with `-wal`); deletion only inside each editor's known storage folders with secondary confirmation (prominent red button), never global databases, never while the editor is running

### Packages & dependencies
- **Real Homebrew formula & cask management**: deeply scans `/opt/homebrew` and `/usr/local` `Cellar` (reading `INSTALL_RECEIPT.json` metadata, versions, descriptions, and pinned status) and `Caskroom`; quick terminal actions for `brew doctor`, `brew services list`, and `brew outdated`
- **Homebrew cache cleanup**: detects and frees cached downloads and bottles under `~/Library/Caches/Homebrew` from both Disk Cleaner and Package Manager
- **Multi-root project discovery**: searches across 10 standard developer workspaces (`~/Projects`, `~/Developer`, `~/Workspace`, `~/Code`, `~/src`, `~/Desktop`, `~/Documents`, `~/Downloads`, `~/dev`, and `~`) for active projects and dependencies
- **Global CLI software**: automatically identifies all global binaries installed across Node.js (`npm -g`, Bun, pnpm, yarn), Homebrew, Cargo / Rust, Python (`uv tool`, `pip`), and Go (`~/go/bin`)
- **Featured tools shelf**: prominent cards for core standalone software and AI agents (`claude`, `grok`, `rea`, `aider`, `codebuddy`, `wrangler`, `docker`, `uv`, `bun`, `pnpm`, `cargo-tauri`, `gh`, `rg`), with category badges, descriptions and version tags
- **Quick actions on every tool**: run `--help` test in Terminal, reveal in Finder, copy command or path, and **uninstall** (generates ecosystem-specific uninstall command and executes in Terminal after secondary confirmation)
- **Project dependency insight**: scans projects across **Node.js** (`node_modules`), **Python** (`.venv`/`venv`, `site-packages` metadata, `requirements.txt`, `pyproject.toml`), **SwiftPM** (`.build`, `Package.resolved`), **Rust** (`target`, `Cargo.lock`), and **Java** (`pom.xml`, `target`/`build`)
- Shows exact cache directory name and disk footprint in the project picker (e.g. `[.venv: 124 MB]`, `[node_modules: 1.8 GB]`, `[.build: 320 MB]`, `[target: 850 MB]`), with status indicators (ready, missing, workspace link, mismatched) and smart install command suggestions
- **Language cache repositories**: aggregates disk usage and file counts for npm cache, pnpm store, Python uv wheels, Cargo registry, Bun cache, Maven `.m2`, SwiftPM caches, and OpenJDK runtimes

### General
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

---

## Install

Requires **macOS 14+** (Sonoma / Sequoia).

### Option 1: Homebrew (Recommended)

Install via Homebrew Cask with a single command:

```sh
brew install --cask https://raw.githubusercontent.com/Zhengyuuuui/Pharos/main/Casks/pharos.rb
```

Or via Homebrew Tap:

```sh
brew tap zhengyuuuui/tap
brew install --cask pharos
```

### Option 2: Direct DMG Download

Download the latest `Pharos-3.0.0.dmg` from [GitHub Releases](https://github.com/Zhengyuuuui/Pharos/releases/latest), open the disk image, and drag `Pharos.app` to your `/Applications` folder.

### Option 3: Build from Source

Requires the Swift toolchain (Command Line Tools are enough, no Xcode needed):

```sh
git clone https://github.com/Zhengyuuuui/Pharos.git
cd Pharos
make test      # run the test suite (includes a real listening-socket scan)
make install   # build release, bundle Pharos.app, copy to /Applications, launch
# or: make dmg # build standalone signed DMG into dist/Pharos.dmg
```

Upgrading from the old **UsageBar** build: your settings (language, favorites, Chrome presets, cleanup retention…) are copied over on first launch. Delete `/Applications/UsageBar.app` afterwards, and re-enable “Launch at login” in Settings.

---

## Privacy & safety

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
- **Start / Quit a browser** — `open -na "<browser>"` with the preset's flags passed one by one (no shell); quit = `SIGTERM` to the browser process, `SIGKILL` only on explicit force quit
- **Fan control** (only after you install the helper) — the root helper `pharos-fand` accepts five fixed commands (`status`, `ping`, `system`, `max`, `fixed <rpm>`) on a socket only your user can open, and writes only the fan keys (`Ftst`, `F%dMd`, `F%dTg`). Installed to `/Library/PrivilegedHelperTools/local.pharos.fand` + `/Library/LaunchDaemons/local.pharos.fand.plist`; Uninstall removes both

---

## Project structure

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
│   ├── FanGaugeMath     #   pure math scaling & polar angles for fan speedometer
│   ├── FanHelperInstall #   helper paths, launchd plist, install script
│   ├── Battery...       #   hardware battery charge limiting & SMC writes
│   ├── AgentChats       #   AI agent chat databases & custom app scanning
│   ├── AgentChatCatalog #   cached session summaries & grouping
│   ├── AgentSQLiteReader#   pure Swift SQLite header & page reader
│   ├── PackageScanner   #   Homebrew, global CLI, project deps, cache repos
│   ├── PackageModels    #   packages and language cache data models
│   └── PopoverLayout    #   which blocks each popover tab shows (customizable)
├── Pharos/              # SwiftUI app
│   ├── ProjectStore     #   polling, state, actions
│   ├── CleanupStore     #   disk cleanup state
│   ├── WorkspaceStore   #   favorites: persist, pin, open in Terminal
│   ├── ChromeStore      #   Chrome presets, start / quit
│   ├── AgentChatStore   #   agent chat databases state, custom apps, backup, delete
│   ├── PackageStore     #   package manager & Homebrew state, diagnostics
│   ├── BatteryStore     #   battery charge limit state, hardware monitoring
│   ├── Notifier         #   local notifications
│   ├── MenuBarSettings  #   menu bar text, global shortcut
│   ├── BackupActions    #   export / import panels
│   ├── FanStore         #   fan helper install, commands, heartbeat
│   ├── LegacyDefaults   #   one-time settings migration from UsageBar
│   └── UI/              #   popover, main window, speedometer gauge, charts, cleanup, favorites, Chrome, packages, settings, L10n
├── pharos-fand/         # optional root helper for fan control (installed only on request)
├── pharos-battd/        # optional root helper for battery charge limit (installed only on request)
└── pharos-tests/        # Test suite (`make test`)
Scripts/make-icon.swift  # draws the app icon in CoreGraphics; `make icon` rebuilds Resources/Pharos.icns
```

Pure Swift + Apple SDKs only — **zero third-party dependencies**, Swift Package Manager + `Makefile`, no Xcode project. See [`AGENTS.md`](AGENTS.md) for contribution rules (memory management, i18n, safety).

---

## Development

```sh
swift build
make test                           # all assertions must pass
.build/debug/Pharos --check         # print system memory, top apps, projects/ports
.build/debug/Pharos --check --all   # include background apps
make icon                           # regenerate the app icon from Scripts/make-icon.swift
```

---

## Recent Updates

### v3.0 (2026-10-24)
- **Floating Sidebar Island & Controllable Traffic Lights Frosted Glass**: redesigned the main window with a rounded floating sidebar island housing the native macOS traffic lights (`NSToolbar` unified layout) and a bottom status/settings footer island; scrolling sidebar items underneath the top-left traffic lights row triggers real-time Gaussian frosted-glass blur (`NSClipView.boundsDidChangeNotification`), with a 0%–100% transparency slider and a live miniature top-left 3-buttons preview card in **Settings → Menu Bar & Appearance**.
- **Calibrated High-Contrast & Dynamic Typography Tokens**: `PharosColor` provides calibrated high-contrast lightness steps in both light and dark modes (increasing both `background`→`surface` and `surface`→`fill` separation), and `PharosFont` uses relative `Font.TextStyle` tokens with `.monospacedDigit()`.
- **Comprehensive Settings Reset**: confirming **Reset Settings** in the modern Settings page restores all persisted preferences across stores (`ProjectStore`, `L10n`, `PopoverLayoutStore`, `MenuBarSettings`, `WorkspaceStore`, `Notifier`, `ChromeStore`, `PackageStore`, `AgentChatStore`, and visual toggles) while preserving saved workspaces, browser presets, and hardware fan/battery daemons.

### v2.9 (2026-10-23)
- **Persistent Lid-Closed & Background Battery Guard**: optional toggle in Battery & Charging lets `pharos-battd` persist its target mode/limit to `/Library/PrivilegedHelperTools/local.pharos.battd.state` (mode `0600`) and maintain the hardware charge limit across lid-close sleep, DarkWake, app quits, and reboots without requiring UI heartbeats.
- **Zero-Redundancy SMC Write Deduplication & Visibility-Driven Polling**: `pharos-battd` deduplicates identical SMC hardware writes (re-asserting at most once per 60s), switches to a 3s tick loop, fast-returns in `.system` mode, and automatically rotates daemon logs (`512 KB` cap); `BatteryStore`, `FanStore`, and `ProjectStore` downclock background timers to 30s when all windows/popovers are closed.
- **Incremental AI Chat Database Fingerprint Cache**: nanosecond-precision `AgentDatabaseFingerprint` (`DB + -wal` size & `mtime`) skips SQLite parsing on unchanged multi-GB databases (e.g. 6.5 GB `opencode.db`), reducing repeat scans to near-zero latency while supporting one-click forced full rescan.
- **Two-Stage Progressive Project Dependency Scanning**: Stage 1 instantaneously renders project dependency manifests and CLI tools; Stage 2 progressively computes and caches `node_modules` / `.venv` / `.build` / `target` bundle sizes in the background keyed by directory & lockfile `mtime`.
- **Modularized Core & UI Architecture**: cleanly split `PackageScanner`, `AgentChats`/`AgentScanner`, `PackageView`, and `AgentChatView` into cohesive, focused Swift modules under ~1,000 lines each with 765 unit test assertions passing.

### v2.8 (2026-10-19)
- **Automotive Cockpit Fan Speedometer**: high-precision dual-dial cockpit gauges with 270° sweep, upright polar numerals, redline danger zone, and manual target speed marker.
- **60 FPS Mechanical Inertia Acceleration Engine**: smooth cubic S-curve ($3t^2 - 2t^3$) spool-up, rolling continuous frame-by-frame HUD RPM digits.
- **Dynamic Gaussian Motion Blur & 3D Acceleration**: velocity-driven Gaussian motion blur on needle trails, ribbons, and HUD digits, with a quick toggle for energy savings.
- **Concentric Needle Pivot Alignment**: 100% concentric needle geometry at `(0, 0)` and downward HUD offset to prevent hub cap overlap.
- **SwiftUI Gaussian Motion Blur Handbook**: comprehensive pure Swift reusable templates in `docs/SWIFTUI_GAUSSIAN_MOTION_BLUR_GUIDE.md`.

👉 **See the complete version history in [CHANGELOG.md](CHANGELOG.md)**.

---

## License

[MIT](LICENSE) © 2026 Zhengyuuuui. Portions © 2026 Jose Escorcia (original scaffolding).
