import Foundation
import SwiftUI
import UsageBarCore

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
            let preferred = Locale.preferredLanguages.first ?? "en"
            language = preferred.hasPrefix("zh") ? .simplifiedChinese : .english
        }
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
    func confirmStopTitle(_ name: String) -> String { en ? "Stop \(name)?" : "结束「\(name)」？" }
    func confirmStopBody(_ n: Int) -> String {
        en ? "Sends SIGTERM to \(n) process(es). Unsaved state in those processes will be lost."
           : "将向 \(n) 个进程发送 SIGTERM，进程中未保存的状态会丢失。"
    }
    var stillRunning: String {
        en ? "Still running after SIGTERM." : "发送 SIGTERM 后仍在运行。"
    }

    // MARK: - Overview pages

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

    // MARK: - Favorites (saved workspaces)

    var favorites: String { en ? "Favorites" : "常用项目" }
    var runningProjects: String { en ? "Running" : "运行中的项目" }
    var addWorkspace: String { en ? "Add Workspace…" : "添加工作区…" }
    var addWorkspaceMessage: String {
        en ? "Choose project folders. UsageBar reads package.json, Makefile, manage.py… to find the start command."
           : "选择项目文件夹。UsageBar 会读取 package.json、Makefile、manage.py 等文件来识别启动命令。"
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

    // MARK: - Chrome instances

    var chromeTitle: String { en ? "Chrome" : "Chrome 实例" }
    var manage: String { en ? "Manage…" : "管理…" }
    var chromeRunning: String { en ? "Running" : "运行中" }
    var chromePresets: String { en ? "Saved" : "已保存" }
    var chromeMain: String { en ? "Chrome (main)" : "Chrome（主）" }
    var newChromePreset: String { en ? "New Instance" : "新建实例" }
    var measureFolders: String { en ? "Measure Folders" : "计算文件夹大小" }
    var measuring: String { en ? "Measuring…" : "计算中…" }
    var notSaved: String { en ? "not saved" : "未保存" }
    var saveChromePreset: String { en ? "Save as preset (keeps its exact flags)" : "保存为预设（保留它的全部参数）" }
    var startChrome: String { en ? "Start" : "启动" }
    var quitChrome: String { en ? "Quit" : "退出" }
    var openDevToolsList: String { en ? "Open DevTools target list in browser" : "在浏览器中打开 DevTools 调试列表" }
    var profileFolder: String { en ? "Profile folder" : "配置文件夹" }
    var defaultProfile: String { en ? "default (~/Library/…/Google/Chrome)" : "默认（~/Library/…/Google/Chrome）" }
    var proxy: String { en ? "Proxy" : "代理" }
    var startURL: String { en ? "Start URL" : "启动网址" }
    var chromeAccounts: String { en ? "Profiles" : "账号/配置" }
    var folderSize: String { en ? "Folder size" : "文件夹大小" }
    var extraFlags: String { en ? "Extra flags" : "其他参数" }
    var presetName: String { en ? "Name" : "名称" }
    var debugPort: String { en ? "Debug port" : "调试端口" }
    var invalidPort: String { en ? "Port must be 1024–65535." : "端口必须在 1024–65535 之间。" }
    var flagsMustStartWithDash: String { en ? "Each extra flag must start with -" : "每个附加参数都必须以 - 开头" }
    var chromeEmpty: String { en ? "No Chrome running" : "没有运行中的 Chrome" }
    var chromeEmptyDesc: String {
        en ? "Running instances appear here automatically. Use “New Instance” to save a debug profile you start often."
           : "运行中的实例会自动出现在这里。用「新建实例」保存一个常用的调试配置。"
    }
    var chromeAlreadyRunning: String {
        en ? "This profile folder is already in use by a running Chrome." : "这个配置文件夹已被一个运行中的 Chrome 使用。"
    }
    func portInUse(_ port: UInt16) -> String {
        en ? "Port \(port) is already in use by another process." : "端口 \(port) 已被其他进程占用。"
    }
    var defaultProfileDebugWarning: String {
        en ? "Chrome ignores --remote-debugging-port on the default profile; set a profile folder."
           : "Chrome 在默认配置上会忽略 --remote-debugging-port，请设置一个配置文件夹。"
    }
    var chromeNotInstalled: String {
        en ? "Google Chrome not found in /Applications." : "在 /Applications 中找不到 Google Chrome。"
    }
    func chromeStartFailed(_ reason: String) -> String { en ? "Couldn't start Chrome: \(reason)" : "无法启动 Chrome：\(reason)" }
    var chromeLoadFailed: String { en ? "Saved Chrome presets couldn't be read and were reset." : "已保存的 Chrome 预设无法读取，已重置。" }
    var chromeSaveFailed: String { en ? "Couldn't save Chrome presets." : "Chrome 预设保存失败。" }
    var chromeNotice: String {
        en ? "Instances are identified by profile folder (Chrome allows one per folder). Start runs `open -na \"Google Chrome\" --args …`; Quit sends SIGTERM (Chrome's normal shutdown, tabs restore next time), force quit only if it stays open. UsageBar doesn't connect to the debug ports."
           : "实例按配置文件夹区分（Chrome 每个文件夹只能开一个）。启动即执行 `open -na \"Google Chrome\" --args …`；退出发送 SIGTERM（Chrome 正常关闭，下次可恢复标签页），仍未退出才提供强制结束。UsageBar 不会连接调试端口。"
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
}
