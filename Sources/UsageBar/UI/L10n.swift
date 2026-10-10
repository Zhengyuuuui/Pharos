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
    var dataNotice: String {
        en ? "Read-only: lists your own processes with listening TCP ports. Memory = Activity Monitor footprint (incl. child processes)."
           : "只读：列出你自己监听 TCP 端口的进程。内存 = 活动监视器口径（含子进程）。"
    }
}
