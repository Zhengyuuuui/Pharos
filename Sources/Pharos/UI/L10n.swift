import Foundation
import SwiftUI
import PharosCore

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en_US")
        case .simplifiedChinese: return Locale(identifier: "zh_CN")
        }
    }
}

/// App-wide UI strings for en / zh-Hans. Live-switchable: views observe `L10n.shared`.
final class L10n: ObservableObject {
    static let shared = L10n()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = AppLanguage(rawValue: saved) {
            language = lang
        } else {
            language = Self.systemDefaultLanguage()
        }
    }

    private static func systemDefaultLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .simplifiedChinese : .english
    }

    func resetLanguage() {
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        language = Self.systemDefaultLanguage()
    }

    private var en: Bool { language == .english }

    // MARK: - Popover / shared
    // MARK: - Shared

    var appTitle: String { en ? "Dev Ports" : "开发端口" }
    var loading: String { en ? "Scanning…" : "扫描中…" }
    var refreshNow: String { en ? "Refresh Now" : "立即刷新" }
    var settings: String { en ? "Settings" : "设置" }
    var settingsEllipsis: String { en ? "Settings…" : "设置…" }
    var mainWindow: String { en ? "Main Window…" : "主窗口…" }
    var quit: String { en ? "Quit" : "退出" }
    var back: String { en ? "Back" : "返回" }
    var projects: String { en ? "Projects" : "项目" }
    var languageTitle: String { en ? "Language" : "语言" }

    var noProjects: String { en ? "No listening projects" : "没有正在监听端口的项目" }
    var noProjectsDesc: String {
        en ? "Start a dev server (npm run dev, python -m http.server…) and it will show up here."
           : "启动一个开发服务（npm run dev、python -m http.server…）后会显示在这里。"
    }
    var selectProject: String { en ? "Select a project" : "选择一个项目" }
    var selectProjectDesc: String {
        en ? "Choose a project in the sidebar to see its ports, processes and memory."
           : "在侧边栏选择项目，查看端口、进程与内存。"
    }

    func summary(projects: Int, memory: String) -> String {
        en ? "\(projects) project(s) · \(memory)" : "\(projects) 个项目 · \(memory)"
    }
    func processCount(_ n: Int) -> String { en ? "\(n) process(es)" : "\(n) 个进程" }
    func updated(_ age: String) -> String { en ? "Updated \(age)" : "更新于 \(age)" }
    var justNow: String { en ? "just now" : "刚刚" }
    func agoSeconds(_ n: Int) -> String { en ? "\(n)s ago" : "\(n) 秒前" }
    func agoMinutes(_ n: Int) -> String { en ? "\(n)m ago" : "\(n) 分钟前" }

    // MARK: - Project detail

    var ports: String { en ? "Ports" : "端口" }
    var memory: String { en ? "Memory" : "内存" }
    var processes: String { en ? "Processes" : "进程" }
    var directory: String { en ? "Directory" : "目录" }
    var listening: String { en ? "listening" : "监听" }
    var helper: String { en ? "child" : "子进程" }
    var localOnly: String { en ? "local only" : "仅本机" }
    var allInterfaces: String { en ? "all interfaces" : "所有网卡" }
    var localOnlyHelp: String { en ? "Bound to 127.0.0.1 — only this Mac can connect" : "绑定 127.0.0.1——仅本机可访问" }
    var allInterfacesHelp: String { en ? "Bound to 0.0.0.0 — reachable from your network" : "绑定 0.0.0.0——局域网可访问" }
    var pid: String { "PID" }
    var command: String { en ? "Command" : "命令" }

    // MARK: - Actions

    var openInBrowser: String { en ? "Open in Browser" : "在浏览器打开" }
    var revealInFinder: String { en ? "Show in Finder" : "在 Finder 中显示" }
    var stop: String { en ? "Stop" : "结束" }
    var stopProject: String { en ? "Stop Project" : "结束项目" }
    var forceKill: String { en ? "Force Kill" : "强制结束" }
    var cancel: String { en ? "Cancel" : "取消" }
    var confirm: String { en ? "Confirm" : "确认" }
    func confirmStopTitle(_ name: String) -> String { en ? "Stop \(name)?" : "结束「\(name)」？" }
    func confirmStopBody(_ n: Int) -> String {
        en ? "Sends SIGTERM to \(n) process(es). Unsaved state in those processes will be lost."
           : "将向 \(n) 个进程发送 SIGTERM，进程中未保存的状态会丢失。"
    }
    var stillRunning: String {
        en ? "Still running after SIGTERM." : "发送 SIGTERM 后仍在运行。"
    }

    // MARK: - Overview pages

    var dashboard: String { en ? "Dashboard" : "仪表盘" }
    var systemAndHardware: String { en ? "System & Hardware" : "系统与硬件" }
    var runtimeAndServices: String { en ? "Runtime & Services" : "环境与运行时" }
    var systemMaintenance: String { en ? "Maintenance" : "系统维护" }
    var appearance: String { en ? "Appearance" : "外观" }
    var overview: String { en ? "Overview" : "总览" }
    var systemMemory: String { en ? "System Memory" : "本机内存" }
    var portsOverview: String { en ? "Ports Overview" : "端口总览" }
    var memoryUsed: String { en ? "Memory Used" : "已用内存" }
    var appMemory: String { en ? "App" : "App 内存" }
    var wiredMemory: String { en ? "Wired" : "联动内存" }
    var compressedMemory: String { en ? "Compressed" : "已压缩" }
    var cachedFiles: String { en ? "Cached Files" : "缓存文件" }
    var freeMemory: String { en ? "Free" : "空闲" }
    var availableMemory: String { en ? "Available" : "可用" }
    var cachedReclaimable: String { en ? "Cached (reclaimable)" : "缓存（可回收）" }
    var swapUsed: String { en ? "Swap Used" : "已用交换" }
    var physicalMemory: String { en ? "Physical Memory" : "物理内存" }
    var pressure: String { en ? "Pressure" : "内存压力" }
    func pressureLabel(_ p: MemoryPressure) -> String {
        switch p {
        case .normal: return en ? "Normal" : "正常"
        case .warning: return en ? "Warning" : "警告"
        case .critical: return en ? "Critical" : "严重"
        }
    }
    var topApps: String { en ? "Top Apps by Memory" : "内存占用最高的应用" }
    var application: String { en ? "Application" : "应用" }
    var other: String { en ? "Other" : "其他" }
    var lastHour: String { en ? "Last hour" : "近 1 小时" }
    var memoryTrend: String { en ? "Memory Trend" : "内存趋势" }
    var devProjects: String { en ? "Dev Projects" : "开发项目" }
    var devMemoryTrend: String { en ? "Dev Projects Memory" : "开发项目内存趋势" }
    var memoryByProject: String { en ? "Memory by Project" : "各项目内存" }
    var portMap: String { en ? "Port Map" : "端口分布" }
    var project: String { en ? "Project" : "项目" }
    var port: String { en ? "Port" : "端口" }
    var exposed: String { en ? "Exposed" : "对外暴露" }
    var exposedHint: String {
        en ? "Ports bound to all interfaces are reachable from your local network."
           : "绑定到所有网卡的端口可被局域网访问。"
    }
    var shareOfSystem: String { en ? "of used memory" : "占已用内存" }
    var collectingHistory: String {
        en ? "Collecting samples… the chart fills in over the next minutes."
           : "正在采集数据…图表会在接下来几分钟内逐渐填满。"
    }
    var time: String { en ? "Time" : "时间" }
    var used: String { en ? "Used" : "已用" }

    // MARK: - Settings

    var refreshEvery: String { en ? "Refresh every" : "刷新间隔" }
    func seconds(_ n: Int) -> String { en ? "\(n) s" : "\(n) 秒" }
    var showSystem: String { en ? "Show background apps" : "显示后台应用" }
    var showSystemHint: String {
        en ? "Include apps and system services that listen on ports (Spotify, AirPlay, Docker Desktop…)."
           : "同时显示监听端口的应用与系统服务（Spotify、AirPlay、Docker Desktop…）。"
    }
    var launchAtLogin: String { en ? "Launch at login" : "登录时启动" }
    var loginError: String {
        en ? "Only works from the installed app (/Applications)."
           : "仅在已安装的应用（/Applications）中可用。"
    }

    // Terminal
    var terminalTitle: String { en ? "Open projects in" : "项目启动终端" }
    var notInstalled: String { en ? "not installed" : "未安装" }
    func terminalFallback(_ app: String) -> String {
        en ? "\(app) couldn't open the launch script, so Terminal was used instead."
           : "\(app) 无法打开启动脚本，已改用「终端」。"
    }

    // Menu bar text
    var menuBarText: String { en ? "Menu bar shows" : "菜单栏显示" }
    func menuBarTextOption(_ o: MenuBarText) -> String {
        switch o {
        case .none: return en ? "Icon only" : "仅图标"
        case .projects: return en ? "Project count" : "项目数"
        case .ports: return en ? "Port count" : "端口数"
        case .memory: return en ? "Memory used %" : "内存占用 %"
        case .disk: return en ? "Startup disk used %" : "启动磁盘占用 %"
        }
    }
    var maxProjectsCapacity: String { en ? "Max projects capacity" : "最多项目数（容量上限）" }
    var maxPortsCapacity: String { en ? "Max ports capacity" : "最多端口数（容量上限）" }
    var capacityRingHint: String {
        en ? "Used to calculate the icon ring's fill percentage."
           : "用于计算菜单栏小图标环形进度的已用占比。"
    }

    // Global shortcut
    var hotkeyTitle: String { en ? "Open popover shortcut" : "打开菜单栏快捷键" }
    var hotkeyNone: String { en ? "Off" : "关闭" }
    var hotkeyFailed: String {
        en ? "That shortcut is already taken by another app." : "这个快捷键已被其他应用占用。"
    }

    // Notifications
    var notificationsTitle: String { en ? "Notifications" : "通知" }
    var notifyMemory: String { en ? "Memory pressure becomes high" : "内存压力升高时" }
    var notifyDisk: String { en ? "A disk is almost full (≥ 95 %)" : "磁盘快满时（≥ 95%）" }
    var notifyFavoriteExit: String { en ? "A favorite project stops unexpectedly" : "常用项目意外停止时" }
    var notificationsDenied: String {
        en ? "Notifications are turned off for Pharos in System Settings → Notifications."
           : "Pharos 的通知已在「系统设置 → 通知」中关闭。"
    }
    var notifyMemoryTitle: String { en ? "Memory pressure is high" : "内存压力较高" }
    func notifyMemoryBody(_ used: String, _ total: String) -> String {
        en ? "\(used) of \(total) in use. Quit apps or stop dev servers you don't need."
           : "已用 \(used) / \(total)。可以退出不用的应用或结束不需要的开发服务。"
    }
    func notifyDiskTitle(_ name: String) -> String { en ? "\(name) is almost full" : "\(name) 快满了" }
    func notifyDiskBody(_ free: String) -> String {
        en ? "Only \(free) available. Disk Cleanup can free temp files and caches."
           : "仅剩 \(free) 可用。可以用「磁盘清理」清理临时文件和缓存。"
    }
    func notifyExitTitle(_ name: String) -> String { en ? "\(name) stopped" : "\(name) 已停止" }
    func notifyExitBody(_ ports: String) -> String {
        en ? "It was listening on \(ports) and is no longer running." : "它之前监听 \(ports)，现在已不在运行。"
    }

    // Backup
    var backupTitle: String { en ? "Backup" : "备份" }
    var exportSettings: String { en ? "Export…" : "导出…" }
    var importSettings: String { en ? "Import…" : "导入…" }
    var backupHint: String {
        en ? "Favorite projects, browser presets and the popover layout as one JSON file. Importing adds new entries, skips ones you already have, and applies the saved popover layout."
           : "把常用项目、浏览器预设和下拉框布局导出为一个 JSON 文件。导入时只添加新的条目（已有的跳过），并应用备份里的下拉框布局。"
    }
    func exported(_ favorites: Int, _ presets: Int) -> String {
        en ? "Exported \(favorites) projects and \(presets) browser presets." : "已导出 \(favorites) 个常用项目和 \(presets) 个浏览器预设。"
    }
    func imported(_ favorites: Int, _ presets: Int, _ skipped: Int) -> String {
        en ? "Imported \(favorites) projects and \(presets) browser presets\(skipped > 0 ? ", skipped \(skipped) already present" : "")."
           : "已导入 \(favorites) 个常用项目和 \(presets) 个浏览器预设\(skipped > 0 ? "，跳过 \(skipped) 个已存在的" : "")。"
    }
    func backupFailed(_ reason: String) -> String { en ? "Backup failed: \(reason)" : "备份失败：\(reason)" }
    var backupInvalid: String { en ? "This file isn't a Pharos backup." : "这不是 Pharos 的备份文件。" }

    // MARK: - Favorites (saved workspaces)

    var favorites: String { en ? "Favorites" : "常用项目" }
    var runningProjects: String { en ? "Running" : "运行中的项目" }
    var addWorkspace: String { en ? "Add Workspace…" : "添加工作区…" }
    var addWorkspaceMessage: String {
        en ? "Choose project folders. Pharos reads package.json, Makefile, manage.py… to find the start command."
           : "选择项目文件夹。Pharos 会读取 package.json、Makefile、manage.py 等文件来识别启动命令。"
    }
    var favoritesEmpty: String {
        en ? "No favorites yet. Add a workspace folder, or click ☆ on a running project to keep it here with its start command."
           : "还没有常用项目。添加一个工作区文件夹，或点击运行中项目的 ☆，把它连同启动命令保存到这里。"
    }
    var pinToFavorites: String { en ? "Add to Favorites" : "加入常用" }
    var pinned: String { en ? "In Favorites" : "已加入常用" }
    var pinHelp: String { en ? "Save to Favorites with the command it's running with" : "连同当前运行命令保存到常用项目" }
    var unpinHelp: String { en ? "Remove from Favorites" : "从常用项目移除" }
    var removeFavorite: String { en ? "Remove" : "移除" }
    var rename: String { en ? "Rename" : "重命名" }
    var notRunning: String { en ? "Not running" : "未运行" }
    var stoppedShort: String { en ? "off" : "未运行" }
    func notRunningLastPorts(_ ports: String) -> String { en ? "Not running · last seen on \(ports)" : "未运行 · 上次端口 \(ports)" }
    func runningSummary(ports: Int, memory: String) -> String {
        en ? "Running · \(ports) port(s) · \(memory)" : "运行中 · \(ports) 个端口 · \(memory)"
    }
    var startCommand: String { en ? "Start command" : "启动命令" }
    func commandSourceLabel(_ s: Favorite.CommandSource) -> String {
        switch s {
        case .detected: return en ? "detected from project files" : "从项目文件识别"
        case .running: return en ? "taken from the running process" : "取自正在运行的进程"
        case .custom: return en ? "set by you" : "手动设置"
        }
    }
    var noCommandSet: String { en ? "No start command — click ✎ to set one" : "没有启动命令——点 ✎ 设置" }
    var commandPlaceholder: String { en ? "e.g. pnpm run dev" : "例如 pnpm run dev" }
    var editCommand: String { en ? "Edit command" : "编辑命令" }
    var copyCommand: String { en ? "Copy cd + command" : "复制 cd + 命令" }
    var save: String { en ? "Save" : "保存" }
    var openInTerminal: String { en ? "Open in Terminal" : "在终端中启动" }
    var openInTerminalHint: String {
        en ? "Runs in a new Terminal window with your shell setup; Ctrl-C there stops it."
           : "在新的终端窗口里用你的 shell 环境运行；在那里按 Ctrl-C 即可停止。"
    }
    var alreadyRunningHint: String {
        en ? "Already running — starting again may fail with \"port in use\"."
           : "已在运行——再次启动可能会提示端口被占用。"
    }
    var detectedCommands: String { en ? "Other detected commands" : "识别到的其他命令" }
    var useThis: String { en ? "Use" : "使用" }
    var reviewScript: String { en ? "shell script — check it first" : "shell 脚本——请先确认内容" }
    var destructiveScript: String { en ? "discards changes" : "会丢弃改动" }
    var destructiveScriptHelp: String {
        en ? "This script runs commands like git reset --hard or rm -rf. Not offered as a one-click start command; type it yourself if you really want it."
           : "这个脚本含有 git reset --hard、rm -rf 等命令，不提供一键设为启动命令；确实需要请手动填写。"
    }
    var runningNow: String { en ? "Running now" : "当前运行" }
    var dismiss: String { en ? "Dismiss" : "关闭" }
    func folderMissing(_ dir: String) -> String { en ? "Folder not found: \(dir)" : "找不到文件夹：\(dir)" }
    func launchFailed(_ reason: String) -> String { en ? "Couldn't open Terminal: \(reason)" : "无法打开终端：\(reason)" }
    var favoritesLoadFailed: String {
        en ? "Saved favorites couldn't be read and were reset." : "已保存的常用项目无法读取，已重置。"
    }
    var favoritesSaveFailed: String { en ? "Couldn't save favorites." : "常用项目保存失败。" }

    // MARK: - Browser instances (Chromium-based)

    var chromeTitle: String { en ? "Browsers" : "浏览器实例" }
    var manage: String { en ? "Manage…" : "管理…" }
    var chromeRunning: String { en ? "Running" : "运行中" }
    var chromePresets: String { en ? "Saved" : "已保存" }
    func browserMain(_ app: String) -> String { en ? "\(app) (main)" : "\(app)（主）" }
    var newChromePreset: String { en ? "New Instance" : "新建实例" }
    var measureFolders: String { en ? "Measure Folders" : "计算文件夹大小" }
    var measuring: String { en ? "Measuring…" : "计算中…" }
    var notSaved: String { en ? "not saved" : "未保存" }
    var saveChromePreset: String { en ? "Save as preset (keeps its exact flags)" : "保存为预设（保留它的全部参数）" }
    var unsaveChromePreset: String { en ? "Remove from saved" : "取消收藏" }
    var launchCommand: String { en ? "Launch command" : "启动命令" }
    var copyLaunchCommand: String { en ? "Copy launch command" : "复制启动命令" }
    var copied: String { en ? "Copied" : "已复制" }
    var presetDiffers: String {
        en ? "Running with different flags than the saved preset." : "当前运行的参数与已保存的预设不同。"
    }
    var updatePreset: String { en ? "Update Preset" : "更新预设" }
    var savedStopped: String { en ? "saved · not running" : "已收藏 · 未运行" }
    var startChrome: String { en ? "Start" : "启动" }
    var quitChrome: String { en ? "Quit" : "退出" }
    var openDevToolsList: String { en ? "Open DevTools target list in browser" : "在浏览器中打开 DevTools 调试列表" }
    var profileFolder: String { en ? "Profile folder" : "配置文件夹" }
    var defaultProfile: String { en ? "default profile folder" : "默认配置文件夹" }
    var proxy: String { en ? "Proxy" : "代理" }
    var startURL: String { en ? "Start URL" : "启动网址" }
    var chromeAccounts: String { en ? "Profiles" : "账号/配置" }
    var folderSize: String { en ? "Folder size" : "文件夹大小" }
    var extraFlags: String { en ? "Extra flags" : "其他参数" }
    var presetName: String { en ? "Name" : "名称" }
    var debugPort: String { en ? "Debug port" : "调试端口" }
    var invalidPort: String { en ? "Port must be 1024–65535." : "端口必须在 1024–65535 之间。" }
    var flagsMustStartWithDash: String { en ? "Each extra flag must start with -" : "每个附加参数都必须以 - 开头" }
    var chromeEmpty: String { en ? "No browser instances" : "没有浏览器实例" }
    var chromeEmptyDesc: String {
        en ? "Running instances appear here automatically. Use “New Instance” to save a debug profile you start often."
           : "运行中的实例会自动出现在这里。用「新建实例」保存一个常用的调试配置。"
    }
    var chromeAlreadyRunning: String {
        en ? "This profile folder is already in use by a running browser." : "这个配置文件夹已被一个运行中的浏览器使用。"
    }
    func portInUse(_ port: UInt16) -> String {
        en ? "Port \(port) is already in use by another process." : "端口 \(port) 已被其他进程占用。"
    }
    var defaultProfileDebugWarning: String {
        en ? "Chromium browsers ignore --remote-debugging-port on the default profile; set a profile folder."
           : "Chromium 系浏览器在默认配置上会忽略 --remote-debugging-port，请设置一个配置文件夹。"
    }
    var chromeNotInstalled: String {
        en ? "No Chromium browser (Chrome, Edge, Brave, Chromium…) found in /Applications." : "在 /Applications 中找不到 Chromium 系浏览器（Chrome、Edge、Brave、Chromium…）。"
    }
    func chromeStartFailed(_ reason: String) -> String { en ? "Couldn't start the browser: \(reason)" : "无法启动浏览器：\(reason)" }
    func browserNotInstalled(_ app: String) -> String {
        en ? "\(app) not found in /Applications." : "在 /Applications 中找不到 \(app)。"
    }
    var browserTitle: String { en ? "Browser" : "浏览器" }
    var allBrowsers: String { en ? "All" : "全部" }
    var browsersSettings: String { en ? "Browsers" : "浏览器" }
    var browsersSettingsHint: String {
        en ? "Chromium-based browsers share the same flags. Hidden browsers aren't listed on the Browsers page; their saved presets are kept."
           : "Chromium 系浏览器使用相同的启动参数。隐藏的浏览器不会出现在「浏览器实例」页面，已保存的预设会保留。"
    }
    var showInList: String { en ? "Show" : "显示" }
    var defaultBrowserForNew: String { en ? "New instances use" : "新建实例使用" }
    func runningCount(_ n: Int) -> String { en ? "\(n) running" : "\(n) 个运行中" }
    func presetCount(_ n: Int) -> String { en ? "\(n) saved" : "\(n) 个已保存" }
    var revealProfiles: String { en ? "Show default profile folder in Finder" : "在 Finder 中显示默认配置文件夹" }
    var chromeLoadFailed: String { en ? "Saved browser presets couldn't be read and were reset." : "已保存的浏览器预设无法读取，已重置。" }
    var chromeSaveFailed: String { en ? "Couldn't save browser presets." : "浏览器预设保存失败。" }
    var chromeNotice: String {
        en ? "Works with Chrome, Chrome Beta / Canary, Chromium, Edge and Brave. Instances are identified by profile folder (one browser per folder). Start runs `open -na \"<browser>\" --args …`; Quit sends SIGTERM (the browser's normal shutdown, tabs restore next time), force quit only if it stays open. Pharos doesn't connect to the debug ports."
           : "支持 Chrome、Chrome Beta / Canary、Chromium、Edge 和 Brave。实例按配置文件夹区分（每个文件夹只能开一个浏览器）。启动即执行 `open -na \"<浏览器>\" --args …`；退出发送 SIGTERM（浏览器正常关闭，下次可恢复标签页），仍未退出才提供强制结束。Pharos 不会连接调试端口。"
    }

    // MARK: - Thermals & Battery

    var batteryAndThermalsTitle: String { en ? "Power & Thermals" : "电源与散热" }
    var batteryAndThermalsDesc: String {
        en ? "Hardware power management, Tahoe-style charge limits (80%), fan speeds and sensor temperatures"
           : "硬件电源管理、Tahoe 原生风格充电上限 (80%)、风扇转速与芯片温度"
    }
    var thermalTitle: String { en ? "Fans & Temperature" : "风扇与温度" }
    var fansTitle: String { en ? "Fans" : "风扇" }
    var temperaturesTitle: String { en ? "Temperatures" : "温度" }
    func fanName(_ i: Int, of count: Int) -> String {
        if count == 2 { return en ? (i == 0 ? "Left fan" : "Right fan") : (i == 0 ? "左风扇" : "右风扇") }
        return en ? "Fan \(i + 1)" : "风扇 \(i + 1)"
    }
    var fanStopped: String { en ? "stopped" : "停转" }
    func fanRange(_ min: Int, _ max: Int) -> String { en ? "\(min)–\(max) rpm" : "\(min)–\(max) 转/分" }
    func fanMode(_ m: FanReading.Mode) -> String {
        switch m {
        case .system: return en ? "macOS" : "系统控制"
        case .auto: return en ? "Auto" : "自动"
        case .manual: return en ? "Manual" : "手动"
        case .unknown: return en ? "Unknown" : "未知"
        }
    }
    var fanViewModeGauge: String { en ? "Speedometer" : "汽车仪表盘" }
    var fanViewModeBars: String { en ? "Classic Bars" : "经典条形" }
    var fanDutyCycle: String { en ? "Duty Cycle" : "负载率" }
    var fanTargetSpeed: String { en ? "Target" : "目标" }
    var fanSpeedDifferential: String { en ? "Speed Delta" : "转速差" }
    var fanBalanced: String { en ? "Balanced" : "对称均衡" }
    var fanRedline: String { en ? "Redline Zone" : "高转速赤线区" }
    var fanRPMUnit: String { en ? "RPM x 1000" : "转速 x 1000" }
    var fanNoFansInstalled: String { en ? "Fanless Mac (No physical fans)" : "无物理风扇设计 (静音被动散热)" }
    var motionPerformanceMode: String { en ? "Motion & Energy Mode" : "动效与能耗模式" }
    var motionModeSmooth: String { en ? "Smooth Motion" : "流畅动画" }
    var motionModeBalanced: String { en ? "Balanced Energy" : "均衡能耗" }
    var gauge3DAcceleration: String { en ? "3D Gauge Hardware Acceleration" : "仪表盘 3D 渲染与动效加速" }
    var gauge3DAccelerationNotice: String {
        en
            ? "Smooth motion mode: enables 60 FPS mechanical inertia, dynamic Gaussian motion blur, and 3D rendering acceleration for fluid visuals."
            : "流畅动画模式：启用 60 FPS 物理阻尼惯性、动态高斯模糊与 3D 渲染加速，呈现最流畅细腻的动效体验。"
    }
    var gaugeReducedMotionNotice: String {
        en
            ? "Balanced energy mode: disables dynamic Gaussian blur and 3D trailing ghosts for ultra-low GPU overhead and optimal battery life."
            : "均衡能耗模式：关闭动态高斯模糊与 3D 残影拖尾，采用轻量级 2D 动效，以极低 GPU 能耗兼顾流畅与续航。"
    }
    var gaugeReduceMotionAction: String { en ? "Switch to Balanced" : "切换为均衡能耗" }
    var gaugeEnable3DAction: String { en ? "Switch to Smooth" : "切换为流畅动画" }
    var gaugeMotionNoticeBanner: String {
        en
            ? "Smooth 3D gauge motion uses GPU performance cores and increases energy consumption"
            : "已开启流畅动效加速 · 调用 GPU 核心增加能耗"
    }
    var systemReduceMotionNotice: String {
        en
            ? "System “Reduce Motion” enabled: locked to balanced mode with 3D acceleration and motion blurs disabled"
            : "系统「减弱动态效果」已开启 · 已锁定为均衡能耗模式（自动关闭 3D 与动态模糊）"
    }
    var popoverGaussianBlur: String { en ? "Menu Bar Gaussian Blur Animation" : "菜单栏高斯动画" }
    var popoverGaussianBlurHint: String {
        en
            ? "Enables smooth Gaussian blur resolves, tab crossfades, and gentle refresh dissolves in the menu bar popover; disable for instant crisp 2D rendering."
            : "在菜单栏下拉框中启用窗口展开高斯动效、标签页切换模糊混合与数据刷新柔和过渡；关闭后采用即时静态渲染。"
    }
    func sensorGroup(_ g: SensorGroup) -> String {
        switch g {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return en ? "Memory" : "内存"
        case .ssd: return "SSD"
        case .battery: return en ? "Battery" : "电池"
        case .power: return en ? "Power" : "供电"
        case .ambient: return en ? "Inside case" : "机身内部"
        }
    }
    var thermalStateTitle: String { en ? "Thermal state" : "散热状态" }
    func thermalStateName(_ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal: return en ? "Normal" : "正常"
        case .fair: return en ? "Warm" : "略高"
        case .serious: return en ? "Hot — throttling" : "较高（降频中）"
        case .critical: return en ? "Critical" : "严重"
        @unknown default: return "—"
        }
    }
    var thermalUnavailable: String {
        en ? "Fan and temperature sensors couldn't be read on this Mac." : "这台 Mac 上无法读取风扇和温度传感器。"
    }
    var thermalReadNotice: String {
        en ? "Read directly from the System Management Controller (no permission needed). Sensor names aren't public Apple API, so groups show the hottest sensor of each kind; numbers may differ slightly from other tools."
           : "直接从系统管理控制器（SMC）读取，无需权限。传感器名称不是 Apple 公开接口，所以每组显示同类中最热的传感器；数值可能与其他工具略有差异。"
    }
    var openEnergySettings: String { en ? "Energy Mode Settings…" : "能耗模式设置…" }

    // Fan control
    var fanControlTitle: String { en ? "Fan control" : "风扇控制" }
    var fanControlIntro: String {
        en ? "Keep fans faster than macOS would when your Mac runs hot. Needs a small helper that runs as root (installed once with your administrator password). Not supported by Apple — use at your own risk."
           : "在 Mac 发热时让风扇比系统默认转得更快。需要安装一个以 root 运行的小助手（输入一次管理员密码）。这不是 Apple 支持的功能，风险自负。"
    }
    var fanInstall: String { en ? "Install Fan Control…" : "安装风扇控制…" }
    var fanUninstall: String { en ? "Uninstall" : "卸载" }
    var fanInstallPrompt: String { en ? "Pharos wants to install its fan control helper." : "Pharos 要安装风扇控制助手。" }
    var fanUninstallPrompt: String { en ? "Pharos wants to remove its fan control helper." : "Pharos 要卸载风扇控制助手。" }
    func fanInstallFailed(_ reason: String) -> String { en ? "Fan helper install failed: \(reason)" : "风扇助手安装失败：\(reason)" }
    var fanHelperMissing: String {
        en ? "The fan helper isn't in this build. Reinstall Pharos with `make install`." : "当前版本缺少风扇助手，请用 `make install` 重新安装 Pharos。"
    }
    var fanNotResponding: String {
        en ? "Fan helper installed but not responding. Try uninstalling and installing again." : "风扇助手已安装但没有响应，请卸载后重新安装。"
    }
    var fanCommandFailed: String { en ? "The fan helper didn't respond." : "风扇助手没有响应。" }
    var fanModeSystem: String { en ? "macOS" : "系统控制" }
    var fanModeFixed: String { en ? "Fixed speed" : "固定转速" }
    var fanModeMax: String { en ? "Max" : "满速" }
    var fanApply: String { en ? "Apply" : "应用" }
    var fanOverheat: String {
        en ? "Above 95 °C — all fans forced to max until it cools below 88 °C."
           : "温度超过 95°C——所有风扇强制满速，降到 88°C 以下才恢复。"
    }
    var fanUnsupported: String {
        en ? "This Mac's firmware refused manual fan control. Fans stay with macOS."
           : "这台 Mac 的固件拒绝了手动风扇控制，风扇仍由系统控制。"
    }
    var fanHeld: String { en ? "Fans held by Pharos" : "风扇由 Pharos 控制中" }
    var fanSafety: String {
        en ? "Safety: fans go back to macOS when Pharos quits, crashes or stops responding for 15 s, after sleep the setting is re-applied, and any CPU/GPU sensor at 95 °C forces max. Speeds are limited to each fan's rated range."
           : "安全措施：Pharos 退出、崩溃或 15 秒无响应时，风扇自动交还系统；睡眠唤醒后重新应用；任一 CPU/GPU 传感器达到 95°C 时强制满速。转速限制在每个风扇的额定范围内。"
    }

    // MARK: - Customize popover

    var customizePopover: String { en ? "Customize Popover…" : "自定义下拉框…" }
    var customizeTitle: String { en ? "Customize" : "自定义" }
    var livePreview: String { en ? "Live Preview" : "实时预览" }
    var customizeIntro: String {
        en ? "Arrange the menu bar popover like widgets: drag blocks between the two tabs to reorder them, drag one out to the library to hide it, or drag one in from the library. The preview on the left is the real popover with live data."
           : "像编辑小组件一样排列菜单栏下拉框：在两个页签之间拖动块来调整顺序，拖到右侧组件库即可隐藏，从组件库拖进来即可添加。左边的预览就是实际的下拉框，显示实时数据。"
    }
    var componentLibrary: String { en ? "Library" : "组件库" }
    var libraryEmpty: String { en ? "Every block is in use." : "所有组件都已使用。" }
    var dropHere: String { en ? "Drop a block here" : "把组件拖到这里" }
    var dropToRemove: String { en ? "Drop here to remove" : "拖到这里移除" }
    var resetLayout: String { en ? "Reset to Default" : "恢复默认" }
    var moveUp: String { en ? "Move up" : "上移" }
    var moveDown: String { en ? "Move down" : "下移" }
    var removeBlock: String { en ? "Remove" : "移除" }
    func addTo(_ tab: String) -> String { en ? "Add to \(tab)" : "添加到「\(tab)」" }
    var popoverEmpty: String {
        en ? "No blocks. Add some in Main window → Customize." : "没有组件，可在主窗口 →「自定义」中添加。"
    }
    var favoritesEmptyShort: String { en ? "No favorite projects yet." : "还没有常用项目。" }
    var projectRowsTitle: String { en ? "Running projects shown" : "运行中的项目显示个数" }
    func projectRowsRange(_ lo: Int, _ hi: Int, running: Int) -> String {
        en ? "\(running) running · range \(lo)–\(hi)" : "当前运行 \(running) 个 · 可设 \(lo)–\(hi)"
    }
    func rowsAll(_ n: Int) -> String { en ? "All (\(n))" : "全部（\(n)）" }
    var projectsUnit: String { en ? "projects" : "个" }
    var customRowLimit: String { en ? "Custom count:" : "自定义数值：" }
    func popoverTabName(_ t: PopoverTab) -> String {
        switch t {
        case .overview: return overview
        case .projects: return projects
        }
    }
    func blockName(_ b: PopoverBlock) -> String {
        switch b {
        case .memory: return systemMemory
        case .disk: return diskUsage
        case .thermals: return thermalTitle
        case .devProjects: return devProjects
        case .topApps: return topApps
        case .projects: return en ? "Running projects" : "运行中的项目"
        case .browsers: return chromeTitle
        case .favorites: return favorites
        case .battery: return batteryTitle
        }
    }
    func blockDescription(_ b: PopoverBlock) -> String {
        switch b {
        case .memory: return en ? "Used / available, pressure, 1-hour trend" : "已用 / 可用、内存压力、1 小时趋势"
        case .disk: return en ? "Every volume incl. external drives" : "所有卷，含外接硬盘"
        case .thermals: return en ? "Fan speeds, CPU / GPU temperature" : "风扇转速、CPU / GPU 温度"
        case .devProjects: return en ? "Dev memory trend and top projects" : "开发项目内存趋势与排行"
        case .topApps: return en ? "Apps using the most memory" : "内存占用最多的应用"
        case .projects: return en ? "Ports, memory, stop" : "端口、内存、结束"
        case .browsers: return en ? "Start / quit browser instances" : "启动 / 退出浏览器实例"
        case .favorites: return en ? "Saved projects, open in Terminal" : "常用项目，一键在终端启动"
        case .battery: return en ? "Charge limits (80%), power plug status, health" : "充电上限控制 (80%)、小插头状态、电池健康"
        }
    }

    // MARK: - Disk usage

    var diskUsage: String { en ? "Disk Usage" : "磁盘用量" }
    var diskUsed: String { en ? "Used" : "已用" }
    var diskAvailable: String { en ? "Available" : "可用" }
    var diskTotal: String { en ? "Capacity" : "容量" }
    var diskVolumes: String { en ? "Volumes" : "卷" }
    var diskExternalCount: String { en ? "External" : "外接" }
    var diskFormat: String { en ? "Format" : "格式" }
    var diskConnection: String { en ? "Connection" : "接口" }
    var diskMountPoint: String { en ? "Mounted at" : "挂载位置" }
    var diskReadOnly: String { en ? "read-only" : "只读" }
    var diskOpenInFinder: String { en ? "Open in Finder" : "在 Finder 中打开" }
    var diskNoExternal: String {
        en ? "No external drives connected. Plugged-in drives and network shares appear here automatically."
           : "没有接入外接硬盘。接入的硬盘和网络共享会自动出现在这里。"
    }
    var diskLow: String { en ? "Low space" : "空间不足" }
    var diskFreeUpSpace: String { en ? "Free Up Space…" : "释放空间…" }
    var diskNotice: String {
        en ? "Same numbers as Finder: “Available” includes purgeable space macOS frees on demand. Hidden system volumes (VM, Preboot, simulator runtimes) aren't listed. Read only — Pharos never writes to or ejects drives."
           : "口径与 Finder 一致：「可用」包含 macOS 可按需释放的可清除空间。隐藏的系统卷（VM、Preboot、模拟器运行时）不列出。只读——Pharos 不会写入或推出任何磁盘。"
    }
    func diskKind(_ k: DiskVolume.Kind) -> String {
        switch k {
        case .startup: return en ? "Startup disk" : "启动磁盘"
        case .internalDisk: return en ? "Internal" : "内置"
        case .external: return en ? "External" : "外接硬盘"
        case .network: return en ? "Network" : "网络共享"
        case .diskImage: return en ? "Disk image" : "磁盘映像"
        }
    }
    func diskFreeOf(_ free: String, _ total: String) -> String {
        en ? "\(free) available of \(total)" : "可用 \(free) / 共 \(total)"
    }

    // MARK: - Disk cleanup

    var diskCleanup: String { en ? "Disk Cleanup" : "磁盘清理" }
    var cleanupIntro: String {
        en ? "Frees disk space, not RAM. Sizes count only your own regular files older than each location's retention window — exactly what a clean can delete. System/other users' files, sockets and symlinks are never touched; folders themselves are kept."
           : "释放的是磁盘空间，不是内存。体积只统计超过保留期且属于你自己的普通文件——也就是清理时真正能删的部分。系统或其他用户的文件、socket、符号链接不会被动；文件夹本身保留。"
    }
    var cleanupScan: String { en ? "Rescan" : "重新扫描" }
    var cleanEverything: String { en ? "Clean Everything" : "全部清理" }
    func cleanEverythingHelp(_ size: String) -> String {
        en ? "Cleans every location below (\(size)), including long-lived caches like Xcode and npm."
           : "清理下面所有位置（\(size)），包括 Xcode、npm 等长期缓存。"
    }
    var cleanTemp: String { en ? "Clean Temp Files" : "一键清理临时文件" }
    var cleanGroup: String { en ? "Clean Group" : "清理本组" }
    var cleanRow: String { en ? "Clean" : "清理" }
    var confirmClean: String { en ? "Confirm" : "确认清理" }
    var cleaning: String { en ? "Cleaning…" : "清理中…" }
    var scanning: String { en ? "Scanning…" : "扫描中…" }
    var otherCaches: String { en ? "Other caches (clean occasionally)" : "其他缓存（偶尔清理）" }
    func locationCount(_ n: Int) -> String { en ? "\(n) locations" : "\(n) 个位置" }
    var tempGroupHint: String {
        en ? "/tmp, /var/tmp and your /var/folders T & C dirs — where AI agents, CLIs and build tools keep writing scratch files."
           : "/tmp、/var/tmp 以及 /var/folders 下你的 T、C 目录——AI 助手、命令行工具和构建工具不断往这里写临时文件。"
    }
    var keepNewerThan: String { en ? "Keep files newer than" : "保留最近" }
    func retentionLabel(hours: Int) -> String {
        switch hours {
        case 0: return en ? "None" : "不保留"
        case 1: return en ? "1 h" : "1 小时"
        case 24: return en ? "1 day" : "1 天"
        case let h where h % 24 == 0: return en ? "\(h / 24) days" : "\(h / 24) 天"
        default: return en ? "\(hours) h" : "\(hours) 小时"
        }
    }

    func groupTitle(_ group: DiskCleaner.Group) -> String {
        switch group {
        case .temp: return en ? "Temp files" : "临时文件"
        case .appCaches: return en ? "App caches" : "应用缓存"
        case .apple: return en ? "Xcode & Apple toolchain" : "Xcode 与 Apple 工具链"
        case .packages: return en ? "Package managers" : "包管理器缓存"
        }
    }

    func groupIcon(_ group: DiskCleaner.Group) -> String {
        switch group {
        case .temp: return "pin.fill"
        case .appCaches: return "square.stack.3d.up"
        case .apple: return "hammer"
        case .packages: return "shippingbox"
        }
    }
    func freedReport(_ size: String, files: Int, failed: Int) -> String {
        let base = en ? "freed \(size) (\(files) item(s))." : "已释放 \(size)（\(files) 项）。"
        return failed > 0
            ? base + (en ? " \(failed) in-use item(s) could not be deleted." : " \(failed) 项正在使用，无法删除。")
            : base
    }
    func nothingFreed(failed: Int) -> String {
        failed > 0
            ? (en ? "nothing freed — \(failed) item(s) are in use or protected."
                  : "没有释放空间——\(failed) 项正在使用或受保护。")
            : (en ? "nothing to clean — remaining files are newer than the age window or not yours."
                  : "没有可清理的内容——剩余文件还在保留期内，或不属于你。")
    }
    var cleanupTmp: String { en ? "System temp (/tmp)" : "系统临时目录（/tmp）" }
    var cleanupVarTmp: String { en ? "Persistent temp (/var/tmp)" : "持久临时目录（/var/tmp）" }
    var cleanupUserTemp: String { en ? "User temp (/var/folders/…/T)" : "用户临时目录（/var/folders/…/T）" }
    var cleanupUserCache: String { en ? "User cache (/var/folders/…/C)" : "用户缓存目录（/var/folders/…/C）" }
    var cleanupAppCaches: String { en ? "App caches (~/Library/Caches)" : "应用缓存（~/Library/Caches）" }
    var cleanupXcodeDerived: String { en ? "Xcode DerivedData" : "Xcode DerivedData" }
    var cleanupXcodeArchives: String { en ? "Xcode Archives" : "Xcode 归档（Archives）" }
    var cleanupXcodeDeviceSupport: String { en ? "Xcode iOS DeviceSupport" : "Xcode iOS DeviceSupport" }
    var cleanupSimulatorCaches: String { en ? "Simulator caches" : "模拟器缓存" }
    var cleanupNpm: String { en ? "npm cache" : "npm 缓存" }
    var cleanupUv: String { en ? "uv cache" : "uv 缓存" }
    var cleanupGradle: String { en ? "Gradle caches" : "Gradle 缓存" }
    var cleanupMaven: String { en ? "Maven repository" : "Maven 仓库" }
    var cleanupCargo: String { en ? "Cargo registry" : "Cargo registry 缓存" }
    var cleanupPnpm: String { en ? "pnpm store" : "pnpm store" }
    var cleanupRustup: String { en ? "rustup toolchains" : "rustup 工具链" }
    var cleanupSpm: String { en ? "SwiftPM caches" : "SwiftPM 缓存" }
    var cleanupCocoapods: String { en ? "CocoaPods caches" : "CocoaPods 缓存" }
    var cleanupPip: String { en ? "pip cache" : "pip 缓存" }
    var cleanupGoBuild: String { en ? "Go build cache" : "Go 编译缓存" }
    var cleanupGoMod: String { en ? "Go module cache" : "Go 模块缓存" }
    var cleanupHomebrew: String { en ? "Homebrew downloads" : "Homebrew 下载缓存" }

    func cleanupTargetTitle(_ id: String) -> String {
        switch id {
        case "tmp": return cleanupTmp
        case "var-tmp": return cleanupVarTmp
        case "user-temp": return cleanupUserTemp
        case "user-cache": return cleanupUserCache
        case "app-caches": return cleanupAppCaches
        case "xcode-derived": return cleanupXcodeDerived
        case "xcode-archives": return cleanupXcodeArchives
        case "xcode-device-support": return cleanupXcodeDeviceSupport
        case "simulator-caches": return cleanupSimulatorCaches
        case "npm": return cleanupNpm
        case "uv": return cleanupUv
        case "gradle-caches": return cleanupGradle
        case "maven": return cleanupMaven
        case "cargo-registry": return cleanupCargo
        case "pnpm-store": return cleanupPnpm
        case "rustup-toolchains": return cleanupRustup
        case "spm": return cleanupSpm
        case "cocoapods": return cleanupCocoapods
        case "pip": return cleanupPip
        case "go-build": return cleanupGoBuild
        case "go-mod": return cleanupGoMod
        case "homebrew": return cleanupHomebrew
        default: return id
        }
    }

    var dataNotice: String {
        en ? "Read-only: lists your own processes with listening TCP ports. Memory = Activity Monitor footprint (incl. child processes)."
           : "只读：列出你自己监听 TCP 端口的进程。内存 = 活动监视器口径（含子进程）。"
    }

    // MARK: - AI Agent Chats
    var agentChats: String { en ? "Agent Chats" : "AI 对话管理" }
    var agentChatTitle: String { en ? "AI Agent Conversations" : "AI 对话管理" }
    var agentChatSubtitle: String {
        en ? "Inspect and manage conversation databases, workspace storage, and caches from Cursor, Trae, VS Code, Claude Code, and Windsurf."
           : "管理本地 Cursor、Trae、VS Code、Claude Code 等 AI 编程助手的对话数据库、工作区存储与缓存。"
    }
    var totalDatabases: String { en ? "Databases" : "数据库总数" }
    var totalConversations: String { en ? "Conversations" : "解析对话数" }
    var totalStorageSize: String { en ? "Total Storage" : "占用总大小" }
    var orphanedWorkspaces: String { en ? "Orphaned Projects" : "失效项目残留" }
    var cleanOrphaned: String { en ? "Clean Orphaned" : "清理失效残留" }
    var cleanOrphanedHelp: String {
        en ? "Remove workspace storage folders whose corresponding project directory has been deleted from your Mac."
           : "一键清理所有在本地已被删除或移动的项目残留的工作区数据库文件夹。"
    }
    var cleanOrphanedConfirm: String { en ? "Clean All Orphaned?" : "确定清理全部残留？" }
    var allEditors: String { en ? "All Editors" : "全部编辑器" }
    var allScopes: String { en ? "All Types" : "全部类型" }
    var scopeGlobal: String { en ? "Global Sessions" : "全局会话" }
    var scopeWorkspace: String { en ? "Workspace Storage" : "工作区存储" }
    var scopeVectorCache: String { en ? "Knowledge & Cache" : "知识库与缓存" }
    var onlyOrphaned: String { en ? "Only Orphaned" : "仅看残留" }
    var searchDatabasesPlaceholder: String { en ? "Search project, conversation, or path…" : "搜索项目名、对话标题或路径…" }
    var sortBy: String { en ? "Sort by" : "排序" }
    var sortBySize: String { en ? "Size" : "文件大小" }
    var sortByDate: String { en ? "Modified" : "修改时间" }
    var sortByName: String { en ? "Name" : "名称" }
    var projectFolder: String { en ? "Project Folder" : "关联项目" }
    var databaseFile: String { en ? "Database File" : "数据库文件" }
    var orphanedWarning: String { en ? "Project directory no longer exists on disk" : "关联的本地项目文件夹已不存在（残留）" }
    var backupDatabase: String { en ? "Backup DB" : "备份数据库" }
    var cleanDatabase: String { en ? "Delete DB" : "删除数据库" }
    var confirmCleanDb: String { en ? "Confirm Delete?" : "确认删除？" }
    var delete: String { en ? "Delete" : "删除" }
    func deleteDbFirstAlertTitle(_ name: String) -> String {
        en ? "Delete \"\(name)\" database?" : "确认删除「\(name)」数据库？"
    }
    func deleteDbFirstAlertMessage(path: String, size: String, scope: String) -> String {
        en ? "This will remove the local conversation database file:\n• Scope: \(scope)\n• Size: \(size)\n• Path: \(path)\n\nAre you sure you want to proceed?"
           : "即将删除该本地对话数据库文件：\n• 类型：\(scope)\n• 大小：\(size)\n• 路径：\(path)\n\n确定要继续吗？"
    }
    func deleteDbEditorRunningWarning(_ editorName: String) -> String {
        en ? "\(editorName) is currently running. Deleting active database files may cause editor anomalies or data loss."
           : "当前 \(editorName) 正在运行中。删除正在使用的数据库可能导致编辑器异常或数据丢失。"
    }
    var deleteDbProceedToConfirm: String {
        en ? "Continue to Delete…" : "继续删除…"
    }
    func deleteDbSecondAlertTitle(_ name: String) -> String {
        en ? "Permanently delete \"\(name)\"?" : "最终确认：彻底删除「\(name)」？"
    }
    var deleteDbSecondAlertMessage: String {
        en ? "This action is PERMANENT and IRREVERSIBLE. All associated chat history in this database will be completely removed. We strongly recommend making a backup before proceeding."
           : "此操作不可逆！该数据库及其中包含的全部历史对话记录将被彻底清除，无法恢复。如果数据重要，请务必先点击备份。"
    }
    var deleteDbFinalConfirmButton: String {
        en ? "Permanently Delete" : "确认彻底删除"
    }
    var conversationsInDb: String { en ? "Conversations in Database" : "数据库内对话记录" }
    var noConversationsParsed: String {
        en ? "No individual session records parsed (internal state or binary cache)."
           : "未解析到独立对话记录（可能为系统内部状态或索引缓存库）。"
    }
    var noAgentDbsFound: String { en ? "No AI agent databases found" : "未发现本地 AI Agent 对话数据库" }
    var noAgentDbsFoundDesc: String {
        en ? "Databases from Cursor, Trae, VS Code, Claude Code, or Windsurf will appear here once used."
           : "在本地使用 Cursor、Trae、VS Code、Claude Code 或 Windsurf 后，相关对话与工作区数据库将显示在此。"
    }
    func agentDbCleanSuccess(_ name: String) -> String {
        en ? "Successfully removed '\(name)'." : "已成功删除 '\(name)'。"
    }
    func agentDbBackupSuccess(_ path: String) -> String {
        en ? "Backup saved to: \(path)" : "已备份至：\(path)"
    }
    func agentOrphanedCleanResult(count: Int, size: String, skipped: Int, failed: Int) -> String {
        var text = en ? "Cleaned \(count) orphaned database(s), freed \(size)." : "已清理 \(count) 个残留工作区，释放 \(size) 空间。"
        if skipped > 0 { text += en ? " Skipped \(skipped) outside known storage paths." : " 跳过 \(skipped) 个不在已知存储路径内的条目。" }
        if failed > 0 { text += en ? " \(failed) failed." : " \(failed) 个删除失败。" }
        return text
    }
    func agentBackupFailed(_ reason: String) -> String { en ? "Backup failed: \(reason)" : "备份失败：\(reason)" }
    func agentDeleteFailed(_ reason: String) -> String { en ? "Delete failed: \(reason)" : "删除失败：\(reason)" }
    func agentDeleteRefused(_ verdict: AgentDeletePolicy.Verdict) -> String {
        switch verdict {
        case .allowed: return ""
        case .globalDatabase:
            return en ? "Global databases hold the editor's settings and every session — back them up instead of deleting."
                      : "全局数据库包含编辑器设置与全部会话，不提供删除，可使用备份。"
        case .outsideKnownPaths:
            return en ? "This file is outside the editor's known storage folders, so Pharos leaves it alone."
                      : "该文件不在此编辑器的已知存储目录内，Pharos 不会删除。"
        case .appRunning:
            return en ? "Quit the editor first — it may be writing to this database."
                      : "请先退出该编辑器，它可能正在写入此数据库。"
        }
    }
    func agentDeleteDisabledHelp(_ verdict: AgentDeletePolicy.Verdict) -> String { agentDeleteRefused(verdict) }
    var agentScopeShortGlobal: String { en ? "Global" : "全局" }
    var agentScopeShortWorkspace: String { en ? "Workspace" : "工作区" }
    var agentScopeShortCache: String { en ? "Cache" : "缓存" }
    func agentMessages(_ n: Int) -> String { en ? "\(n) msg" : "\(n) 条消息" }
    func agentDbCount(_ n: Int) -> String { en ? "\(n) DBs" : "\(n) 个库" }
    var agentChartCollapse: String { en ? "Collapse chart" : "收起图表" }
    var agentChartExpand: String { en ? "Expand chart" : "展开图表" }
    var agentAddCustomApp: String { en ? "Add Application" : "手动添加应用" }
    var agentAddCustomAppShort: String { en ? "Add App" : "手动添加" }
    var agentAddCustomAppHelp: String {
        en ? "Select and scan an unrecognized editor or AI app from /Applications"
           : "从 /Applications 中选择并单独扫描未自动识别的编辑器或 AI 应用"
    }
    var agentAddAppPanelTitle: String { en ? "Select Application to Scan" : "选择要扫描的应用程序" }
    var agentAddAppPanelMessage: String {
        en ? "Select an unrecognized editor or AI application from /Applications to scan its local conversation databases and workspace storage."
           : "选择 /Applications 下未识别的编辑器或 AI 应用，单独扫描其本地对话数据库与工作区存储。"
    }
    var agentAddAppPanelPrompt: String { en ? "Add & Scan" : "添加并扫描" }
    func agentAddAppSuccess(_ name: String, count: Int, size: String) -> String {
        en ? "Scanned “\(name)”: found \(count) database(s) (\(size))."
           : "已添加并扫描「\(name)」：发现 \(count) 个数据库（共 \(size)）。"
    }
    func agentAddAppNoDbsFound(_ name: String) -> String {
        en ? "Scanned “\(name)”, but no conversation databases were found in standard storage paths."
           : "已扫描「\(name)」，但在标准存储目录中未发现对话数据库。"
    }
    var agentRemoveCustomApp: String { en ? "Remove App" : "移除应用" }
    var agentRemoveCustomAppHelp: String {
        en ? "Remove this application from Pharos management"
           : "从 Pharos 管理列表中移除此手动添加的应用"
    }
    func agentRemoveCustomAppConfirm(_ name: String) -> String {
        en ? "Are you sure you want to remove “\(name)” from the list?"
           : "确定从列表中移除「\(name)」吗？"
    }
    var agentForceFullScan: String { en ? "Force Full Rescan" : "强制全量重新扫描" }
    var agentEditorsHeader: String { en ? "AI Editors" : "AI 编辑器" }
    func agentInactiveEditorsHeader(_ n: Int) -> String { en ? "Editors without data (\(n))" : "无数据的编辑器（\(n)）" }
    var agentBackToAll: String { en ? "All Editors" : "全部编辑器" }
    var agentTabDatabases: String { en ? "Databases" : "数据库" }
    var agentTabConversations: String { en ? "Conversations" : "对话" }
    var agentSearchConversations: String { en ? "Search titles or snippets…" : "搜索对话标题或摘要…" }
    var agentSearchResults: String { en ? "Search Results" : "搜索结果" }
    var allDatabasesHeader: String { en ? "All Databases" : "全部数据库" }
    var agentDbNoMatch: String { en ? "No databases match." : "没有匹配的数据库。" }
    var cleanEditorOrphaned: String { en ? "Clean Orphaned" : "清理残留工作区" }
    var cleanEditorOrphanedHelp: String {
        en ? "Delete orphaned workspace storage folders for this editor"
           : "清理该编辑器中项目已不存在的残留工作区存储"
    }
    var cleanEditorOrphanedConfirm: String { en ? "Clean Orphaned?" : "确认清理残留？" }
    func agentPathsNotCreated(_ n: Int) -> String { en ? "\(n) known path(s) not created yet" : "\(n) 个已知路径尚未生成" }
    var agentTruncatedNote: String {
        en ? "Only the latest 100 sessions per database are read."
           : "每个数据库只读取最近 100 条会话。"
    }
    var agentConvTitle: String { en ? "Title" : "标题" }
    var agentConvMode: String { en ? "Mode" : "模式" }
    var agentConvMessages: String { en ? "Messages" : "消息数" }
    var agentConvCreated: String { en ? "Created" : "创建时间" }
    var agentConvUpdated: String { en ? "Updated" : "更新时间" }
    var agentConvDatabase: String { en ? "Database" : "所属库" }
    var agentConvSnippet: String { en ? "Snippet" : "摘要" }
    var agentConvId: String { en ? "Session ID" : "会话 ID" }
    var agentConvNoMatch: String { en ? "No conversations match." : "没有匹配的对话。" }
    var agentLastActive: String { en ? "Last active" : "最近活动" }
    var agentEditorLayoutTitle: String { en ? "AI chats: editor list style" : "AI 对话管理：编辑器入口样式" }
    func agentEditorLayoutOption(_ l: AgentEditorLayout) -> String {
        switch l {
        case .grid: return en ? "Cards (grid)" : "卡片网格"
        case .strip: return en ? "Icon strip" : "横向图标条"
        }
    }
    var agentEditorLayoutHint: String {
        en ? "How editors are listed on the AI Agent Conversations overview."
           : "AI 对话管理总览页中编辑器入口的显示方式。"
    }
    var showAll: String { en ? "Show All" : "显示全部" }
    var loadMore: String { en ? "Load More (+60)" : "加载更多 (+60)" }
    func showingCount(shown: Int, total: Int) -> String {
        en ? "Showing \(shown) of \(total)" : "正在显示 \(shown) / \(total) 项"
    }
    var editorStorageChart: String { en ? "Database Storage by AI Editor" : "各 AI 编辑器数据库占用" }
    var editorStorageDesc: String {
        en ? "Compare database and cache usage across local AI editors. Pick an editor below to open its details."
           : "对比本地各 AI 编程助手的数据库与缓存占用。在下方选择编辑器查看详情。"
    }
    var chartModeTotal: String { en ? "Total" : "总占用" }
    var chartModeBreakdown: String { en ? "By Type" : "分类构成" }

    var configuredDbPaths: String { en ? "Database Storage Paths" : "数据库存储路径" }
    var configuredDbPathsDesc: String {
        en ? "Discovered and known database / cache locations on your Mac for this AI editor."
           : "此 AI 编辑器在当前系统中的数据库、工作区存储及缓存索引路径。"
    }
    var loadedConversations: String { en ? "Loaded Conversations" : "已加载的会话记录" }
    var noConversationsForEditor: String {
        en ? "No conversation records found in this editor's database (or yet to initiate a chat)."
           : "当前数据库中暂无独立对话记录（可能尚未发起会话或仅存储了配置与索引）。"
    }
    var appInstalled: String { en ? "Installed" : "已安装" }
    var appNotInstalled: String { en ? "Not Installed" : "未检测到" }
    var dbPathNotCreated: String { en ? "File not created yet" : "文件尚未生成" }
    var editorPathInspectorTitle: String { en ? "Database Paths & Conversations" : "数据库路径与会话加载" }
    var conversationsCountLabel: String { en ? "conversations" : "条对话" }
    var databasesCountLabel: String { en ? "databases" : "个数据库" }
    var inactiveEditors: String { en ? "Inactive / No Data" : "不常用 (无数据)" }
    var uninstalledAppResidual: String { en ? "Uninstalled (Residual)" : "已卸载 (残留)" }

    // MARK: - Package & Dependency Manager
    var isZh: Bool { !en }
    var packagesTitle: String { en ? "Packages & Dependencies" : "依赖与软件包" }
    var packagesSubtitle: String {
        en ? "Manage global CLI tools, project dependencies, and package caches"
           : "全局命令行软件、项目依赖与语言缓存统一管理"
    }
    var tabGlobalCli: String { en ? "Global CLI Tools" : "全局 CLI 软件" }
    var tabProjectDeps: String { en ? "Project Dependencies" : "项目依赖洞察" }
    var tabCacheRepos: String { en ? "Cache Repositories" : "语言缓存仓库" }
    var declaredVersion: String { en ? "Declared" : "声明版本" }
    var installedVersion: String { en ? "Installed" : "实际安装" }
    var statusMissing: String { en ? "Missing" : "未安装" }
    var statusNormal: String { en ? "Ready" : "已就绪" }
    var statusWorkspace: String { en ? "Workspace Link" : "本地工作区" }
    var statusMismatched: String { en ? "Mismatched" : "版本偏离" }
    var testInTerminal: String { en ? "Test in Terminal" : "在终端测试运行" }
    var prodDependencies: String { en ? "Production" : "生产依赖" }
    var devDependencies: String { en ? "Development" : "开发依赖" }
    var missingDependenciesWarn: String {
        en ? "Missing dependencies detected, please install packages"
           : "检测到依赖缺失，请在终端执行依赖安装"
    }
    var allEcosystems: String { en ? "All Ecosystems" : "全部生态" }
    var searchPackages: String { en ? "Search packages or commands…" : "搜索软件包或指令…" }
    var selectProjectPrompt: String { en ? "Select Project" : "选择项目" }
    var noPackagesFound: String { en ? "No packages found" : "未找到匹配的软件包" }
    var cacheSize: String { en ? "Cache Size" : "缓存占用" }
    var fileCount: String { en ? "Files" : "文件数" }
    var executableBinary: String { en ? "Executable" : "执行文件" }
    var packagePath: String { en ? "Package Path" : "包路径" }
    var license: String { en ? "License" : "开源协议" }
    var refreshPackages: String { en ? "Refresh" : "刷新列表" }
    var totalCliToolsCount: String { en ? "CLI Tools" : "命令行工具" }
    var directDependencies: String { en ? "Direct Dependencies" : "直接依赖" }
    var copyCliCommand: String { en ? "Copy Command" : "复制指令" }
    var commandCopied: String { en ? "Copied" : "已复制" }
    var runCommandTest: String { en ? "Run --help Test" : "执行 --help 测试" }
    func filterByEcosystemHelp(_ name: String) -> String {
        en ? "Click to filter \(name) tools" : "点击筛选 \(name) 命令行工具"
    }
    var showAllCliTools: String {
        en ? "Click to show all CLI tools" : "点击查看全部命令行工具"
    }
    var featuredToolsTitle: String { en ? "Installed Software & AI Tools" : "已下载的核心软件与 AI 工具" }
    var featuredToolsSubtitle: String {
        en ? "Standalone developer software and AI agents installed globally on your Mac"
           : "已独立安装在当前 Mac 上的核心开发软件与 AI 助手，可直接在终端中运行或定位"
    }
    var featuredSoftwareCard: String { en ? "Featured Tools" : "核心软件" }
    var filterByFeaturedHelp: String { en ? "Click to filter featured developer software and AI tools" : "点击仅查看核心软件与 AI 工具" }
    var runInTerminal: String { en ? "Run in Terminal" : "终端运行" }
    var copyPath: String { en ? "Copy Path" : "复制路径" }
    var coreSoftwareBadge: String { en ? "Featured" : "核心软件" }
    var collapseSection: String { en ? "Collapse" : "收起" }
    var expandSection: String { en ? "Expand" : "展开" }
    func readyToolsCount(_ n: Int) -> String { en ? "\(n) ready" : "\(n) 个已就绪" }
    var uninstall: String { en ? "Uninstall" : "卸载" }
    func uninstallConfirmTitle(_ name: String) -> String {
        en ? "Uninstall \(name)?" : "确认卸载 \(name)？"
    }
    func uninstallConfirmMessage(_ name: String, _ cmd: String) -> String {
        en ? "This will launch your terminal to run the uninstall command:\n\n\(cmd)\n\nYou can review the progress and confirm any prompts in terminal."
           : "即将打开终端并执行对应的卸载指令：\n\n\(cmd)\n\n你可以在终端窗口中查看进度，并在需要时进行确认。"
    }
    var confirmUninstallInTerminal: String {
        en ? "Uninstall in Terminal" : "在终端中执行卸载"
    }
    func uninstallHelp(_ name: String) -> String {
        en ? "Uninstall \(name)" : "卸载 \(name)"
    }
    var cacheDirectory: String { en ? "Cache Folder" : "缓存目录" }
    var projectCacheSize: String { en ? "Project Cache" : "缓存依赖体积" }
    var noCacheYet: String { en ? "No cache yet" : "尚未生成缓存" }
    func missingInstallCommand(for ecosystem: PackageEcosystem) -> String {
        switch ecosystem {
        case .node: return "npm install"
        case .python: return "pip install -r requirements.txt"
        case .swift: return "swift package resolve"
        case .rust: return "cargo build"
        case .java: return "mvn clean install"
        default: return "install"
        }
    }

    // MARK: - Project Dependencies Display Mode & Bundle Hero Card
    var packageSettingsTitle: String { en ? "Packages & Dependencies" : "依赖与软件包" }
    var projectDepsDisplayMode: String { en ? "Project dependencies display" : "项目依赖展示方式" }
    func projectDepsDisplayModeOption(_ mode: PackageDepsDisplayMode) -> String {
        switch mode {
        case .bundleOnly:
            return en ? "Primary Bundle (node_modules / .venv, collapsed breakdown)"
                      : "主依赖大包（如 node_modules，默认折叠具体清单）"
        case .detailedList:
            return en ? "Full Breakdown (Expand all packages by default)"
                      : "完整依赖清单（默认展开所有具体包）"
        }
    }
    var projectDepsDisplayModeHint: String {
        en ? "Choose whether Project Dependencies aggregates into a primary bundle folder card by default, or always expands the full dependency list."
           : "设置项目依赖洞察默认以核心大包（如 node_modules / .venv）聚合呈现，还是直接展开完整的依赖清单。"
    }

    var primaryDependencyBundle: String { en ? "Primary Dependency Bundle" : "核心主依赖包" }
    var bundleTotalSize: String { en ? "Bundle Size" : "主包磁盘占用" }
    var bundlePathLabel: String { en ? "Bundle Path" : "主包物理路径" }
    var bundleInstalledReady: String { en ? "Dependency bundle ready" : "主依赖包已安装就绪" }
    var bundleNotInstalled: String { en ? "Bundle not generated (Not installed)" : "主包尚未生成（未安装依赖）" }
    func bundleSubtitle(for ecosystem: PackageEcosystem, bundleName: String) -> String {
        switch ecosystem {
        case .node:
            return en ? "Node.js npm dependency bundle (\(bundleName))" : "Node.js 核心依赖包 (\(bundleName))"
        case .python:
            return en ? "Python virtual environment & packages (\(bundleName))" : "Python 虚拟环境与依赖集合 (\(bundleName))"
        case .swift:
            return en ? "SwiftPM build cache & package checkouts (\(bundleName))" : "SwiftPM 构建缓存与依赖检出 (\(bundleName))"
        case .rust:
            return en ? "Cargo build targets & crates cache (\(bundleName))" : "Cargo 构建产物与依赖缓存 (\(bundleName))"
        case .java:
            return en ? "Maven/Gradle build outputs & dependencies (\(bundleName))" : "Maven/Gradle 构建产物与依赖缓存 (\(bundleName))"
        default:
            return en ? "Project dependencies bundle (\(bundleName))" : "项目主依赖包 (\(bundleName))"
        }
    }
    func expandDetailedDependencies(_ count: Int) -> String {
        en ? "Expand Detailed Packages (\(count) packages)" : "展开具体依赖包清单（共 \(count) 个包）"
    }
    var collapseDetailedDependencies: String {
        en ? "Collapse Detailed Packages" : "收起具体依赖包清单"
    }
    var totalPackagesCountLabel: String { en ? "Total Packages" : "依赖包总计" }
    var declaredCountLabel: String { en ? "Declared Direct" : "直接声明" }
    var devDepsCountLabel: String { en ? "Dev Dependencies" : "开发依赖" }
    var missingDepsCountLabel: String { en ? "Missing" : "未安装" }
    var modeConfigNotice: String {
        en ? "Default display mode can be changed in Settings" : "可在「设置」中修改默认展示模式"
    }

    // Deleting Project Dependencies Bundle
    var deleteDependencyBundle: String { en ? "Delete Bundle" : "删除依赖包" }
    func deleteBundleConfirmTitle(_ name: String) -> String {
        en ? "Delete \"\(name)\"?" : "确认删除 \(name)？"
    }
    func deleteBundleConfirmMessage(_ name: String, _ size: String, _ cmd: String) -> String {
        en ? "This will move \"\(name)\"\(size.isEmpty ? "" : " (\(size))") to the Trash to free up disk space.\n\nYou can reinstall dependencies anytime by running:\n\(cmd)"
           : "即将把 \(name)\(size.isEmpty ? "" : "（\(size)）")移入废纸篓以释放磁盘空间。\n\n删除后可随时在项目目录中运行以下指令重新安装：\n\(cmd)"
    }
    var deleteBundleAction: String { en ? "Move to Trash" : "移入废纸篓" }
    func deleteBundleSuccessNotice(_ name: String) -> String {
        en ? "\(name) moved to Trash" : "\(name) 已成功移入废纸篓"
    }

    // Clean Language Caches (Jump to Disk Cleanup)
    var cleanLanguageCaches: String { en ? "Clean Caches" : "清除缓存" }
    var cleanLanguageCachesHelp: String {
        en ? "Jump to Disk Cleanup to inspect and clean package manager caches"
           : "跳转至「磁盘清理」页面，安全清理包管理器与语言构建缓存"
    }
    var cleanLanguageCachesBannerText: String {
        en ? "Global package & language caches (npm, pnpm, uv, Cargo, Maven, etc.) are safely managed and cleaned by the Disk Cleanup module."
           : "全局语言与包管理器缓存（npm、pnpm、uv、Cargo、Maven 等）由「磁盘清理」模块统一扫描，并支持按保留期策略安全清理。"
    }
    var goToDiskCleanup: String { en ? "Open Disk Cleanup" : "前往磁盘清理" }
    var allDiskCleanup: String { en ? "All Disk Cleanups" : "全部磁盘清理" }
    var languageCachesCleanupTitle: String { en ? "Language & Package Caches" : "语言与包管理器缓存清理" }
    var languageCachesCleanupSubtitle: String {
        en ? "Clean download & build caches for npm, pnpm, uv, pip, Cargo, Maven, Gradle, Go, and Homebrew"
           : "清理 npm、pnpm、uv、pip、Cargo、Maven、Gradle、Go、Homebrew 等语言与包管理器的构建与下载缓存"
    }
    var cleanLanguageCachesGroup: String { en ? "Clean All Language Caches" : "一键清理全部语言缓存" }
    func viewGroupDetailHelp(_ name: String) -> String {
        en ? "Click to view detailed \(name) cleanup page" : "点击进入 \(name) 独立清理页面"
    }
    var appCachesCleanupTitle: String { en ? "Application Caches" : "应用长效缓存清理" }
    var appCachesCleanupSubtitle: String {
        en ? "Clean cached web data, media, and temporary storage from macOS desktop apps in ~/Library/Caches"
           : "清理 ~/Library/Caches 目录下各第三方与系统桌面应用生成的长效缓存、临时数据与日志"
    }
    var appleToolchainCleanupTitle: String { en ? "Xcode & Apple Toolchain Caches" : "Xcode 与 Apple 工具链缓存清理" }
    var appleToolchainCleanupSubtitle: String {
        en ? "Clean DerivedData build artifacts, archives, iOS simulator caches, and CocoaPods/SPM dependencies"
           : "清理 Xcode 编译生成物 DerivedData、版本归档 Archives、模拟器缓存与开发支持符号"
    }
    var tempCleanupTitle: String { en ? "System Temp & Immediate Scratch Caches" : "系统临时目录与即时缓存清理" }
    var tempCleanupSubtitle: String {
        en ? "Clean scratch files generated by build scripts, CLI tools, and background agents in /tmp and /var/tmp"
           : "清理 /private/tmp、/var/tmp 及用户临时文件夹中积累的即时生成物"
    }

    // Homebrew Management & Control
    var homebrewControlTitle: String { en ? "Homebrew System & Package Control" : "Homebrew 软件包与系统管控" }
    var homebrewControlSubtitle: String {
        en ? "Manage installed Formulae, Casks, background services, and prune bottle download caches"
           : "管控本地已安装的 Formula 依赖、Cask 应用、后台运行服务，并一键清理缓存与诊断体检"
    }
    var homebrewCleanCacheBtn: String { en ? "Clean Cache (brew cleanup)" : "清理缓存 (brew cleanup)" }
    var homebrewCleanCacheHelp: String {
        en ? "Runs brew cleanup in terminal to prune outdated formula bottles, cask downloads, and free gigabytes of space"
           : "在终端运行 brew cleanup --prune=all，清理所有旧版本软件包、过期的 Bottle 与 Cask 下载缓存"
    }
    var homebrewDoctorBtn: String { en ? "Doctor (brew doctor)" : "环境体检 (brew doctor)" }
    var homebrewDoctorHelp: String {
        en ? "Runs brew doctor in terminal to inspect Homebrew setup and diagnose formula conflicts or broken symlinks"
           : "在终端运行 brew doctor，检查 Homebrew 环境健康度、符号链接完整性与潜在配置冲突"
    }
    var homebrewOutdatedBtn: String { en ? "Outdated (brew outdated)" : "检查可升级 (brew outdated)" }
    var homebrewOutdatedHelp: String {
        en ? "Inspect formulas and casks that have new versions available upstream"
           : "在终端运行 brew outdated，列出当前已安装且上游有新版本可更新的 Formula 与 Cask"
    }
    var homebrewServicesBtn: String { en ? "Services (brew services)" : "后台服务 (brew services)" }
    var homebrewServicesHelp: String {
        en ? "Inspect or manage background daemons (e.g. MySQL, Redis, Nginx, PostgreSQL) managed by Homebrew"
           : "在终端运行 brew services list，查看由 Homebrew 启动管理的后台数据库与守护进程状态"
    }
    var homebrewCleanDirectlyBtn: String { en ? "Clean Folder Directly" : "直接清理缓存目录" }
    func homebrewCleanDirectlySuccess(_ size: String) -> String {
        en ? "Cleaned Homebrew cache: \(size) freed" : "Homebrew 缓存清理成功，已释放 \(size)"
    }

    // MARK: - Battery & Charging Control

    var batteryTitle: String { en ? "Battery & Charging" : "电池与充电" }
    var batteryChargeLimit: String { en ? "Charge Limit" : "充电上限" }
    var batteryChargeLimitDesc: String {
        en ? "Holds battery charging at a custom threshold (e.g. 80%) to prolong battery lifespan and reduce high-voltage stress."
           : "限制电池最高充电比例（如 80%），避免长期维持高压满电，从而有效延缓电池老化。"
    }
    func batteryHoldingAtLimit(_ limit: Int) -> String {
        en ? "Charging On Hold (\(limit)%)" : "暂停充电（\(limit)%）"
    }
    func batteryHoldingAboveLimit(_ current: Int, limit: Int) -> String {
        en ? "Charging On Hold (\(limit)% Limit · Current \(current)%)" : "暂停充电（设定 \(limit)% · 当前 \(current)%）"
    }
    var batteryHoldingSubtitle: String {
        en ? "Power Adapter connected · Battery is not charging" : "已连接电源适配器 · 电池未在充电"
    }
    var batteryAboveLimitNote: String {
        en ? "Battery level is above target limit. Hardware charging is inhibited and Mac runs on adapter power. Battery will cap at limit once naturally drained."
           : "当前电量高于设定上限，硬件限充已生效，电脑由外接电源供电。电量自然回落至上限后将自动保持，无需切断电源强行放电以保护电池电芯。"
    }
    var batterySafeLimitTip: String {
        en ? "Safe by Design: Pharos uses Apple's native approach, inhibiting charging via hardware SMC registers while keeping the Mac on continuous adapter power (0 mA cell current). It never forcibly cuts adapter power, preventing screen flickering and preserving battery health."
           : "安全设计：Pharos 采用与 Apple 官方 Tahoe 相同的原生硬件逻辑，仅切断电芯充电回路（直通外接电源供电，零电池损耗），绝不切断外接电源去强行放电，彻底避免屏幕闪烁与电池循环损伤。"
    }
    func batteryChargingTo(_ target: Int) -> String {
        en ? "Charging to \(target)%" : "正在充电至 \(target)%"
    }
    var batteryDischarging: String { en ? "On Battery" : "正在使用电池" }
    var batteryFullyCharged: String { en ? "Fully Charged" : "已充满电" }
    var batteryChargeToFullNow: String { en ? "Charge to Full Now" : "立即充满电" }
    var batteryResumeLimit: String { en ? "Resume Charge Limit" : "恢复充电上限" }
    var batteryForceDischarge: String { en ? "Discharge to Limit" : "放电至上限" }
    var batteryForceDischargeActive: String { en ? "Discharging on Battery" : "纯电池放电中" }
    var batterySyncMagSafe: String { en ? "Sync MagSafe LED" : "同步 MagSafe 指示灯" }
    var batterySyncMagSafeDesc: String {
        en ? "Like macOS 15 \"Not Charging\": the MagSafe LED stays amber while holding at the limit and is never switched off. Turn off to let the firmware drive the LED."
           : "与 macOS 15 原生「未在充电」一致：限充保持时 MagSafe 指示灯保持黄色/橙色常亮，绝不熄灭。关闭后完全由系统固件控制指示灯。"
    }
    var batteryPersistentGuard: String { en ? "Persistent Guard (Sleep & Lid-close)" : "合盖与后台持续守护" }
    var batteryPersistentGuardDesc: String {
        en ? "Keeps enforcing the hardware charge limit continuously in the background, even when the lid is closed, the Mac enters sleep, or Pharos is closed. Turn off to restore native macOS charging when Pharos is not running."
           : "合上笔记本屏幕、Mac 进入睡眠或退出 Pharos 时，后台系统守护进程依然持续保持硬件限充（电芯电流 0 mA 直通供电）。关闭后，超时未收到前台心跳将自动恢复 macOS 原生充电。"
    }
    var recommendedTag: String { en ? "Recommended" : "推荐" }
    var batteryHealth: String { en ? "Battery Health" : "电池健康度" }
    var batteryCycleCount: String { en ? "Cycle Count" : "循环次数" }
    var batteryDesignCapacity: String { en ? "Design Capacity" : "设计容量" }
    var batteryMaxCapacity: String { en ? "Maximum Capacity" : "当前最大容量" }
    var batteryPowerFlow: String { en ? "Power Flow" : "充放电功率" }
    var batteryTemperature: String { en ? "Battery Temperature" : "电池温度" }
    var batteryAdapter: String { en ? "Power Adapter" : "电源适配器" }
    var batteryInstallHelper: String { en ? "Install Battery Control" : "安装电池控制" }
    var batteryUninstallHelper: String { en ? "Uninstall Battery Control" : "卸载电池控制" }
    var reinstallHelper: String { en ? "Update Helper" : "更新特权组件" }
    var batteryHelperInstalled: String { en ? "Battery Control Active" : "硬件控制运行中" }
    var batteryHelperDesc: String {
        en ? "Pharos uses a lightweight background service (local.pharos.battd) to safely manage Apple Silicon SMC registers."
           : "Pharos 使用轻量级守护程序 (local.pharos.battd) 安全管理 Apple Silicon 硬件充电寄存器。"
    }
    var batteryHelperMissing: String {
        en ? "Helper binary (pharos-battd) not found in application bundle."
           : "应用包内未找到辅助守护程序 (pharos-battd)。"
    }
    var batteryInstallPrompt: String {
        en ? "Pharos needs administrator privileges to install the battery charging helper (local.pharos.battd)."
           : "Pharos 需要管理员权限以安装电池充电控制服务 (local.pharos.battd)。"
    }
    var batteryUninstallPrompt: String {
        en ? "Pharos needs administrator privileges to uninstall the battery charging helper."
           : "Pharos 需要管理员权限以卸载电池充电控制服务。"
    }
    var batteryCommandFailed: String {
        en ? "Failed to send command to battery helper service."
           : "向电池充电控制服务发送指令失败。"
    }
    var batteryUnsupported: String {
        en ? "Hardware charging control is not supported on this Mac."
           : "当前 Mac 硬件或固件不支持硬件级充电控制。"
    }
    var batteryNotChargingPlug: String {
        en ? "Not Charging (Plugged In)" : "暂不充电（小插头）"
    }
    var batteryCurrentAmperage: String { en ? "Current" : "瞬时电流" }
    var batteryVoltage: String { en ? "Voltage" : "电池电压" }
    var batterySystemManaged: String { en ? "System Managed" : "交由系统管理" }
    var batteryPharosActive: String { en ? "Pharos hardware charge limit active" : "Pharos 硬件限充生效中" }
    var batteryMacOSManaged: String { en ? "Managed natively by macOS" : "macOS 原生托管中" }
    var batteryHelperOffline: String { en ? "Battery control helper not connected" : "电池控制服务未连接" }
    func batteryActiveLimitBadge(_ limit: Int) -> String { en ? "Limit \(limit)%" : "上限 \(limit)%" }
    var batteryFullOverrideBadge: String { en ? "Charging to 100% once" : "临时充满至 100%" }
    func batteryCellCurrent(_ mA: Int) -> String { en ? "Battery cell current: \(mA) mA" : "电池电芯电流: \(mA) mA" }
    var batteryFlowPassthrough: String { en ? "Adapter powering the Mac directly" : "外接电源直通主板供电" }
    var batteryFlowCharging: String { en ? "Adapter charging the battery" : "外接电源正在为电池充电" }
    var batteryFlowSupplementing: String { en ? "Battery assisting the adapter (high load)" : "负载较高，电池正在辅助供电" }
    var batteryFlowOnBattery: String { en ? "Running on battery" : "正在使用电池供电" }
    var batteryPresetRecommended: String { en ? "80% (Recommended)" : "80%（推荐）" }
    func batteryDesignCapacityCaption(_ mAh: Int) -> String { en ? "\(mAh) mAh design" : "\(mAh) mAh 原厂" }
    func batteryRemainingCaption(_ mAh: Int) -> String { en ? "\(mAh) mAh remaining" : "\(mAh) mAh 剩余" }
    func batteryCurrentCaption(_ mA: Int) -> String { en ? "\(mA) mA current" : "\(mA) mA 电流" }
    var batteryBMSSensor: String { en ? "BMS sensor" : "BMS 传感器" }
    var batteryStatusNotInstalled: String { en ? "Not Installed" : "未安装" }
    var batteryStatusNotResponding: String { en ? "Not Responding" : "未响应" }
    var batteryStatusRunning: String { en ? "Running" : "运行正常" }

    // MARK: - Settings Modern Redesign (Target App Alignment)
    var quickActions: String { en ? "Quick Action" : "快捷动作" }
    var aboutPharos: String { en ? "About Pharos" : "关于与版本" }
    var generalSettings: String { en ? "General & System" : "常规与系统" }
    var appearanceSettings: String { en ? "Menu Bar & Appearance" : "菜单栏与视觉" }
    var devToolsSettings: String { en ? "Developer & Workspaces" : "开发工具与环境" }
    var openSourceSubtitle: String { en ? "100% Native Swift · Local Dev Lighthouse · Zero Network" : "100% 原生 Swift 构建 · 本地开发环境灯塔 · 纯净零网络请求" }
    var viewOnGitHub: String { en ? "GitHub Repo" : "访问 GitHub 仓库" }
    var resetAllSettings: String { en ? "Reset Settings" : "恢复默认设置" }
    var resetAllSettingsConfirm: String {
        en ? "Are you sure you want to restore all preferences and popover layout to default? Saved workspaces, browser presets, and hardware fan/battery controls will not be affected."
           : "确定要将所有偏好设置及下拉框布局恢复为默认值吗？已收藏的工作区、浏览器预设及风扇/电池硬件控制不会受到影响。"
    }
    var resetSettingsDone: String { en ? "All settings have been restored to defaults." : "所有设置已恢复为默认值。" }
    var launchAtLoginHelp: String { en ? "Automatically launch Pharos in the menu bar when you log into your Mac." : "在登录 Mac 时自动在菜单栏启动 Pharos。" }
    var footerCrafted: String { en ? "By zys with ♡" : "由 zys 精心打造 ♡" }
    var trafficLightGlassTitle: String { en ? "Traffic Lights Glass Transparency" : "交通灯毛玻璃透明度" }
    var trafficLightGlassHint: String {
        en ? "Adjust the frosted glass translucency over the top-left traffic lights when scrolling the sidebar. Live preview on the left shows overlapping text."
           : "调节向下滑动侧边栏时，左上方三个交通灯按钮区域的毛玻璃通透度。左侧预览实时展示文字滑入按钮下方的模糊效果。"
    }
    var trafficLightGlassPreviewLabel: String { en ? "LIVE PREVIEW" : "实时预览" }
    var trafficLightGlassFrosted: String { en ? "Frosted" : "浓雾" }
    var trafficLightGlassClear: String { en ? "Clear" : "通透" }
}





