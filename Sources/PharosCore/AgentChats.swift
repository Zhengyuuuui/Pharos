import Darwin
import Foundation

/// Supported AI Agent Editors
public enum AgentEditorKind: String, Codable, CaseIterable, Identifiable {
    case cursor = "cursor"
    case trae = "trae"
    case windsurf = "windsurf"
    case vscode = "vscode"
    case antigravity = "antigravity"
    case qoder = "qoder"
    case cherryStudio = "cherryStudio"
    case codeBuddy = "codeBuddy"
    case kiro = "kiro"
    case openCode = "openCode"
    case claudeCode = "claudeCode"
    case zed = "zed"
    case workBuddy = "workBuddy"
    case miniMax = "miniMax"
    case zCode = "zCode"
    case continueExt = "continueExt"
    case aider = "aider"
    case doubao = "doubao"
    case chatgpt = "chatgpt"
    case marvis = "marvis"
    case wechatDevTools = "wechatDevTools"
    case hbuilder = "hbuilder"
    case deepseek = "deepseek"
    case autoClaw = "autoClaw"
    case ccSwitch = "ccSwitch"
    case yDevSphere = "yDevSphere"
    case devin = "devin"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .trae: return "Trae"
        case .windsurf: return "Windsurf"
        case .vscode: return "VS Code"
        case .antigravity: return "Antigravity"
        case .qoder: return "Qoder"
        case .cherryStudio: return "Cherry Studio"
        case .codeBuddy: return "CodeBuddy"
        case .kiro: return "Kiro"
        case .openCode: return "OpenCode"
        case .claudeCode: return "Claude Code"
        case .zed: return "Zed"
        case .workBuddy: return "WorkBuddy"
        case .miniMax: return "MiniMax Code"
        case .zCode: return "ZCode"
        case .continueExt: return "Continue"
        case .aider: return "Aider"
        case .doubao: return "豆包 (Doubao)"
        case .chatgpt: return "ChatGPT / Codex"
        case .marvis: return "Marvis AI"
        case .wechatDevTools: return "微信开发者工具"
        case .hbuilder: return "HBuilderX"
        case .deepseek: return "DeepSeek"
        case .autoClaw: return "AutoClaw"
        case .ccSwitch: return "CC Switch"
        case .yDevSphere: return "YDevSphere"
        case .devin: return "Devin"
        case .custom: return "自定义应用"
        }
    }

    public var systemImage: String {
        switch self {
        case .cursor: return "sparkles"
        case .trae: return "bolt.horizontal.fill"
        case .windsurf: return "wind"
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .antigravity: return "atom"
        case .qoder: return "cpu"
        case .cherryStudio: return "brain.head.profile"
        case .codeBuddy: return "person.2.fill"
        case .kiro: return "sparkle.magnifyingglass"
        case .openCode: return "desktopcomputer"
        case .claudeCode: return "terminal.fill"
        case .zed: return "bolt.fill"
        case .workBuddy: return "person.crop.circle.badge.checkmark"
        case .miniMax: return "waveform.path.ecg"
        case .zCode: return "curlybraces"
        case .continueExt: return "arrow.triangle.2.circlepath"
        case .aider: return "character.cursor.ibeam"
        case .doubao: return "bubble.left.and.text.bubble.right.fill"
        case .chatgpt: return "brain"
        case .marvis: return "cube.transparent"
        case .wechatDevTools: return "chevron.left.forwardslash.chevron.right"
        case .hbuilder: return "hammer.fill"
        case .deepseek: return "fish.fill"
        case .autoClaw: return "gearshape.2.fill"
        case .ccSwitch: return "arrow.triangle.swap"
        case .yDevSphere: return "globe.americas.fill"
        case .devin: return "sparkles.rectangle.stack"
        case .custom: return "app.badge.checkmark"
        }
    }

    public var appNames: [String] {
        switch self {
        case .cursor: return ["Cursor.app"]
        case .trae: return ["Trae CN.app", "Trae.app", "TRAE SOLO CN.app"]
        case .windsurf: return ["Windsurf.app"]
        case .vscode: return ["Visual Studio Code.app", "Code.app"]
        case .antigravity: return ["Antigravity.app"]
        case .qoder: return ["Qoder.app", "Qoder CN.app", "Qoder IDE.app", "Qoder CN IDE.app"]
        case .cherryStudio: return ["Cherry Studio.app", "CherryStudio.app"]
        case .codeBuddy: return ["CodeBuddy CN.app", "CodeBuddy.app"]
        case .kiro: return ["Kiro.app"]
        case .openCode: return ["OpenCode.app"]
        case .claudeCode: return ["Claude.app", "Claude Code.app"]
        case .zed: return ["Zed.app", "Zed Preview.app"]
        case .workBuddy: return ["WorkBuddy.app", "WorkBuddy AI.app"]
        case .miniMax: return ["MiniMax Code.app", "MiniMax Code 2.app", "MiniMax Design.app"]
        case .zCode: return ["ZCode.app"]
        case .continueExt: return ["Visual Studio Code.app", "Code.app"]
        case .aider: return []
        case .doubao: return ["Doubao.app", "豆包浏览器.app"]
        case .chatgpt: return ["ChatGPT.app", "Codex.app"]
        case .marvis: return ["Marvis.app"]
        case .wechatDevTools: return ["wechatwebdevtools.app"]
        case .hbuilder: return ["HBuilderX.app"]
        case .deepseek: return ["DeepSeek Harness.app"]
        case .autoClaw: return ["AutoClaw.app"]
        case .ccSwitch: return ["CC Switch.app"]
        case .yDevSphere: return ["YDevSphere.app"]
        case .devin: return ["Devin.app"]
        case .custom: return []
        }
    }

    public var bundleIdentifiers: [String] {
        switch self {
        case .cursor: return ["com.todesktop.230313mzl4w4u92"]
        case .trae: return ["cn.trae.app", "com.trae.app"]
        case .windsurf: return ["com.exafunction.windsurf"]
        case .vscode: return ["com.microsoft.VSCode"]
        case .antigravity: return ["com.google.antigravity"]
        case .qoder: return ["com.qoder.app", "com.qodercn.app"]
        case .cherryStudio: return ["com.kangfenmao.CherryStudio"]
        case .codeBuddy: return ["com.tencent.codebuddycn", "com.tencent.codebuddy"]
        case .kiro: return ["dev.kiro.desktop"]
        case .openCode: return ["ai.opencode.desktop"]
        case .claudeCode: return ["com.anthropic.claudefordesktop"]
        case .zed: return ["dev.zed.Zed", "dev.zed.Zed-Preview"]
        case .workBuddy: return ["com.tencent.workbuddy.mac", "com.tencent.workbuddy"]
        case .miniMax: return ["com.minimax.agent", "com.minimax.agent.cn", "com.minimax.hub.global"]
        case .zCode: return ["dev.zcode.app"]
        case .continueExt: return ["com.microsoft.VSCode"]
        case .aider: return []
        case .doubao: return ["com.bytedance.doubao", "com.bytedance.coze"]
        case .chatgpt: return ["com.openai.chat", "com.openai.codex"]
        case .marvis: return ["com.tencent.mac.marvis"]
        case .wechatDevTools: return ["com.tencent.wechat.devtools"]
        case .hbuilder: return ["com.dcloud.HBuilderX"]
        case .deepseek: return ["com.deepseek.harness", "com.deepseek.dsh"]
        case .autoClaw: return ["com.zhipuai.autoclaw"]
        case .ccSwitch: return ["com.ccswitch.desktop"]
        case .yDevSphere: return ["com.ydevsphere.app"]
        case .devin: return ["ai.cognition.devin", "com.cognition.devin"]
        case .custom: return []
        }
    }

    public var installedAppPath: String? {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let searchRoots = [
            "/Applications",
            "\(home)/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities"
        ]
        for name in appNames {
            for root in searchRoots {
                let p = "\(root)/\(name)"
                if fm.fileExists(atPath: p) { return p }
            }
        }
        return nil
    }

    public var isAppInstalled: Bool {
        installedAppPath != nil
    }

    public func knownStoragePaths(home: String = NSHomeDirectory()) -> [AgentKnownPath] {
        switch self {
        case .cursor:
            return [
                AgentKnownPath(label: "全局 Composer 与会话数据库", fullPath: "\(home)/Library/Application Support/Cursor/User/globalStorage/state.vscdb", scope: .global),
                AgentKnownPath(label: "工作区存储根目录", fullPath: "\(home)/Library/Application Support/Cursor/User/workspaceStorage", scope: .workspace, isDirectory: true)
            ]
        case .trae:
            return [
                AgentKnownPath(label: "Trae AI Agent 核心数据库", fullPath: "\(home)/Library/Application Support/Trae CN/ModularData/ai-agent/database.db", scope: .global),
                AgentKnownPath(label: "Trae CN 全局状态数据库", fullPath: "\(home)/Library/Application Support/Trae CN/User/globalStorage/state.vscdb", scope: .global),
                AgentKnownPath(label: "Trae CN 工作区存储根目录", fullPath: "\(home)/Library/Application Support/Trae CN/User/workspaceStorage", scope: .workspace, isDirectory: true),
                AgentKnownPath(label: "CKG 知识库图谱缓存", fullPath: "\(home)/Library/Application Support/Trae CN/User/globalStorage/.ckg/storage", scope: .vectorCache, isDirectory: true),
                AgentKnownPath(label: "Trae AI 沙盒会话元数据", fullPath: "\(home)/Library/Application Support/Trae CN/ModularData/ai-agent/sandbox", scope: .global, isDirectory: true),
                AgentKnownPath(label: "Trae 全局数据库", fullPath: "\(home)/Library/Application Support/Trae/User/globalStorage/state.vscdb", scope: .global)
            ]
        case .windsurf:
            return [
                AgentKnownPath(label: "Cascade 全局对话存储", fullPath: "\(home)/Library/Application Support/Windsurf/User/globalStorage/state.vscdb", scope: .global),
                AgentKnownPath(label: "工作区存储根目录", fullPath: "\(home)/Library/Application Support/Windsurf/User/workspaceStorage", scope: .workspace, isDirectory: true)
            ]
        case .vscode:
            return [
                AgentKnownPath(label: "GitHub Copilot Chat 会话存储", fullPath: "\(home)/Library/Application Support/Code/User/globalStorage/github.copilot-chat/session-store.db", scope: .global),
                AgentKnownPath(label: "VS Code 全局状态数据库", fullPath: "\(home)/Library/Application Support/Code/User/globalStorage/state.vscdb", scope: .global),
                AgentKnownPath(label: "工作区存储根目录", fullPath: "\(home)/Library/Application Support/Code/User/workspaceStorage", scope: .workspace, isDirectory: true)
            ]
        case .antigravity:
            return [
                AgentKnownPath(label: "智能体会话汇总数据库", fullPath: "\(home)/.gemini/antigravity/conversation_summaries.db", scope: .global),
                AgentKnownPath(label: "智能体独立会话数据库目录", fullPath: "\(home)/.gemini/antigravity/conversations", scope: .global, isDirectory: true),
                AgentKnownPath(label: "Antigravity 数据根目录", fullPath: "\(home)/.gemini/antigravity", scope: .global, isDirectory: true)
            ]
        case .qoder:
            return [
                AgentKnownPath(label: "Qoder CN 对话本地数据库", fullPath: "\(home)/Library/Application Support/QoderCN/SharedClientCache/cache/db/local.db", scope: .global),
                AgentKnownPath(label: "Qoder CN 向量索引库目录", fullPath: "\(home)/Library/Application Support/QoderCN/SharedClientCache/index/vector/v5", scope: .vectorCache, isDirectory: true),
                AgentKnownPath(label: "Qoder CN 元数据索引目录", fullPath: "\(home)/Library/Application Support/QoderCN/SharedClientCache/index/meta/v8", scope: .vectorCache, isDirectory: true),
                AgentKnownPath(label: "Qoder CN 工作区存储目录", fullPath: "\(home)/Library/Application Support/QoderCN/User/workspaceStorage", scope: .workspace, isDirectory: true),
                AgentKnownPath(label: "知识库与图谱索引", fullPath: "\(home)/Library/Application Support/QoderCN/SharedClientCache/repowiki/knowledge.db", scope: .vectorCache),
                AgentKnownPath(label: "Qoder 对话本地数据库", fullPath: "\(home)/Library/Application Support/Qoder/SharedClientCache/cache/db/local.db", scope: .global)
            ]
        case .cherryStudio:
            return [
                AgentKnownPath(label: "智能体会话核心数据库", fullPath: "\(home)/Library/Application Support/CherryStudio/Data/agents.db", scope: .global),
                AgentKnownPath(label: "Cherry Studio 数据主目录", fullPath: "\(home)/Library/Application Support/CherryStudio/Data", scope: .global, isDirectory: true)
            ]
        case .codeBuddy:
            return [
                AgentKnownPath(label: "CodeBuddy 对话会话数据库", fullPath: "\(home)/Library/Application Support/CodeBuddy CN/codebuddy-sessions.vscdb", scope: .global),
                AgentKnownPath(label: "工作区状态数据库目录", fullPath: "\(home)/Library/Application Support/CodeBuddy CN/User/workspaceStorage", scope: .workspace, isDirectory: true),
                AgentKnownPath(label: "全局状态数据库", fullPath: "\(home)/Library/Application Support/CodeBuddy CN/User/globalStorage/state.vscdb", scope: .global)
            ]
        case .kiro:
            return [
                AgentKnownPath(label: "Kiro 全局状态数据库", fullPath: "\(home)/Library/Application Support/Kiro/User/globalStorage/state.vscdb", scope: .global),
                AgentKnownPath(label: "Kiro 工作区存储目录", fullPath: "\(home)/Library/Application Support/Kiro/User/workspaceStorage", scope: .workspace, isDirectory: true)
            ]
        case .openCode:
            return [
                AgentKnownPath(label: "OpenCode 核心会话数据库", fullPath: "\(home)/.local/share/opencode/opencode.db", scope: .global),
                AgentKnownPath(label: "OpenCode 会话差异存储目录", fullPath: "\(home)/.local/share/opencode/storage/session_diff", scope: .global, isDirectory: true),
                AgentKnownPath(label: "OpenCode 数据主目录", fullPath: "\(home)/.local/share/opencode", scope: .global, isDirectory: true),
                AgentKnownPath(label: "OpenCode Desktop 应用配置", fullPath: "\(home)/Library/Application Support/ai.opencode.desktop", scope: .workspace, isDirectory: true)
            ]
        case .claudeCode:
            return [
                AgentKnownPath(label: "Claude Code CLI 历史记录", fullPath: "\(home)/.claude/history.jsonl", scope: .global)
            ]
        case .zed:
            return [
                AgentKnownPath(label: "Zed 线程与对话数据库目录", fullPath: "\(home)/Library/Application Support/Zed/db", scope: .global, isDirectory: true),
                AgentKnownPath(label: "Zed 共享数据目录", fullPath: "\(home)/.local/share/zed", scope: .global, isDirectory: true)
            ]
        case .workBuddy:
            return [
                AgentKnownPath(label: "WorkBuddy 安全与威胁数据库", fullPath: "\(home)/.workbuddy/security/threat-database", scope: .global, isDirectory: true),
                AgentKnownPath(label: "WorkBuddy AI 威胁数据库", fullPath: "\(home)/.workbuddy-ai/security/threat-database", scope: .global, isDirectory: true),
                AgentKnownPath(label: "WorkBuddy 核心数据库", fullPath: "\(home)/.workbuddy/workbuddy.db", scope: .global),
                AgentKnownPath(label: "WorkBuddy AI 核心数据库", fullPath: "\(home)/.workbuddy-ai/workbuddy.db", scope: .global),
                AgentKnownPath(label: "WorkBuddy 应用主目录", fullPath: "\(home)/Library/Application Support/com.tencent.workbuddy.mac", scope: .global, isDirectory: true)
            ]
        case .miniMax:
            return [
                AgentKnownPath(label: "MiniMax Code 核心对话数据库", fullPath: "\(home)/Library/Application Support/@hilo/MiniMax Hub Global/ai-runtime/data-home/opencode/opencode.db", scope: .global),
                AgentKnownPath(label: "MiniMax Code 运行时数据目录", fullPath: "\(home)/Library/Application Support/@hilo/MiniMax Hub Global/ai-runtime/data-home/opencode", scope: .global, isDirectory: true),
                AgentKnownPath(label: "MiniMax Agent 配置目录", fullPath: "\(home)/Library/Application Support/MiniMax Agent", scope: .global, isDirectory: true)
            ]
        case .zCode:
            return [
                AgentKnownPath(label: "ZCode CLI 核心数据库", fullPath: "\(home)/.zcode/cli/db/db.sqlite", scope: .global),
                AgentKnownPath(label: "ZCode 任务索引库", fullPath: "\(home)/.zcode/v2/tasks-index.sqlite", scope: .global),
                AgentKnownPath(label: "ZCode 会话与数据存储目录", fullPath: "\(home)/Library/Application Support/ZCode/session", scope: .global, isDirectory: true)
            ]
        case .continueExt:
            return [
                AgentKnownPath(label: "Continue 索引数据库", fullPath: "\(home)/.continue/index/index.sqlite", scope: .global),
                AgentKnownPath(label: "Continue 会话存储目录", fullPath: "\(home)/.continue/sessions", scope: .workspace, isDirectory: true)
            ]
        case .aider:
            return [
                AgentKnownPath(label: "Aider 对话历史", fullPath: "\(home)/.aider.chat.history.md", scope: .global),
                AgentKnownPath(label: "Aider 标签缓存目录", fullPath: "\(home)/.aider.tags.cache.v3", scope: .vectorCache, isDirectory: true)
            ]
        case .doubao:
            return [
                AgentKnownPath(label: "豆包智能体 Workspace 与会话目录", fullPath: "\(home)/Library/Application Support/Doubao/Default/.doubao/agent_mode/workspace", scope: .workspace, isDirectory: true),
                AgentKnownPath(label: "豆包全局数据目录", fullPath: "\(home)/Library/Application Support/Doubao", scope: .global, isDirectory: true)
            ]
        case .chatgpt:
            return [
                AgentKnownPath(label: "Codex 会话与调用日志库", fullPath: "\(home)/.codex/logs_2.sqlite", scope: .global),
                AgentKnownPath(label: "Codex 线程历史数据库", fullPath: "\(home)/.codex/thread_history_1.sqlite", scope: .global),
                AgentKnownPath(label: "Codex 运行时状态库", fullPath: "\(home)/.codex/state_5.sqlite", scope: .global),
                AgentKnownPath(label: "Codex 数据主目录", fullPath: "\(home)/.codex", scope: .global, isDirectory: true),
                AgentKnownPath(label: "ChatGPT/Codex 服务数据库", fullPath: "\(home)/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Application Support/Software/Analytics.db", scope: .global),
                AgentKnownPath(label: "OpenAI Codex 支持目录", fullPath: "\(home)/Library/Application Support/com.openai.codex", scope: .global, isDirectory: true)
            ]
        case .marvis:
            return [
                AgentKnownPath(label: "Marvis 数据库主目录", fullPath: "\(home)/.marvis/database", scope: .global, isDirectory: true),
                AgentKnownPath(label: "Marvis 会话核心库", fullPath: "\(home)/.marvis/database/data.db", scope: .global),
                AgentKnownPath(label: "Marvis 工具向量索引库", fullPath: "\(home)/.marvis/database/tool_index_vector.db", scope: .vectorCache),
                AgentKnownPath(label: "腾讯云 Marvis 用户会话数据库", fullPath: "\(home)/Library/Application Support/com.tencent.mac.marvis/MarvisData/User", scope: .global, isDirectory: true),
                AgentKnownPath(label: "腾讯云 Marvis 本地应用数据库", fullPath: "\(home)/Library/Application Support/com.tencent.mac.marvis/db/local_app_info.db", scope: .global),
                AgentKnownPath(label: "腾讯云 Marvis 主数据目录", fullPath: "\(home)/Library/Application Support/com.tencent.mac.marvis", scope: .global, isDirectory: true)
            ]
        case .wechatDevTools:
            return [
                AgentKnownPath(label: "微信开发者工具工作区存储根目录", fullPath: "\(home)/Library/Application Support/微信开发者工具", scope: .workspace, isDirectory: true)
            ]
        case .hbuilder:
            return [
                AgentKnownPath(label: "HBuilder X 索引数据库目录", fullPath: "\(home)/Library/Application Support/HBuilder X/newIndexDb", scope: .workspace, isDirectory: true),
                AgentKnownPath(label: "HBuilder X 项目与配置目录", fullPath: "\(home)/Library/Application Support/HBuilder X/projects", scope: .global, isDirectory: true)
            ]
        case .deepseek:
            return [
                AgentKnownPath(label: "DeepSeek 桌面端持久化库", fullPath: "\(home)/Library/Application Support/@deepseek-ai/dsh-desktop/declarative_performance_observer.db", scope: .global),
                AgentKnownPath(label: "DeepSeek 数据目录", fullPath: "\(home)/Library/Application Support/@deepseek-ai", scope: .global, isDirectory: true)
            ]
        case .autoClaw:
            return [
                AgentKnownPath(label: "AutoClaw 核心状态数据库", fullPath: "\(home)/.openclaw-autoclaw/state/openclaw.sqlite", scope: .global),
                AgentKnownPath(label: "AutoClaw 对话历史目录", fullPath: "\(home)/.openclaw-autoclaw/autoclaw/chat-history", scope: .global, isDirectory: true),
                AgentKnownPath(label: "AutoClaw 应用配置目录", fullPath: "\(home)/Library/Application Support/autoclaw", scope: .global, isDirectory: true)
            ]
        case .ccSwitch:
            return [
                AgentKnownPath(label: "CC Switch 核心配置数据库", fullPath: "\(home)/.cc-switch/cc-switch.db", scope: .global),
                AgentKnownPath(label: "CC Switch 自动备份目录", fullPath: "\(home)/.cc-switch/backups", scope: .global, isDirectory: true),
                AgentKnownPath(label: "CC Switch 桌面端支持目录", fullPath: "\(home)/Library/Application Support/com.ccswitch.desktop", scope: .global, isDirectory: true)
            ]
        case .yDevSphere:
            return [
                AgentKnownPath(label: "YDevSphere 核心数据库", fullPath: "\(home)/.ydevsphere/database.sqlite", scope: .global),
                AgentKnownPath(label: "YDevSphere 数据主目录", fullPath: "\(home)/.ydevsphere", scope: .global, isDirectory: true)
            ]
        case .devin:
            return [
                AgentKnownPath(label: "Devin 全局共享状态数据库", fullPath: "\(home)/.devin-shared/sharedStorage/state.vscdb", scope: .global),
                AgentKnownPath(label: "Devin 数据与扩展配置目录", fullPath: "\(home)/.devin", scope: .global, isDirectory: true)
            ]
        case .custom:
            return [
                AgentKnownPath(label: "自定义应用存储目录", fullPath: "\(home)/Library/Application Support", scope: .global, isDirectory: true)
            ]
        }
    }
}

/// Known database or storage path descriptor for an AI editor
public struct AgentKnownPath: Identifiable, Codable, Equatable {
    public let id: String
    public let label: String
    public let fullPath: String
    public let scope: AgentDatabaseScope
    public let isDirectory: Bool

    public init(label: String, fullPath: String, scope: AgentDatabaseScope, isDirectory: Bool = false) {
        self.id = fullPath
        self.label = label
        self.fullPath = fullPath
        self.scope = scope
        self.isDirectory = isDirectory
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: fullPath)
    }

    public var sizeBytes: UInt64 {
        guard exists else { return 0 }
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
            guard let enumerator = fm.enumerator(atPath: fullPath) else { return 0 }
            var total: UInt64 = 0
            while let file = enumerator.nextObject() as? String {
                let p = (fullPath as NSString).appendingPathComponent(file)
                if let attrs = try? fm.attributesOfItem(atPath: p), let s = attrs[.size] as? UInt64 {
                    total += s
                }
            }
            return total
        } else if let attrs = try? fm.attributesOfItem(atPath: fullPath), let s = attrs[.size] as? UInt64 {
            return s
        }
        return 0
    }
}

/// Scope of the AI conversation storage
public enum AgentDatabaseScope: String, Codable, CaseIterable, Identifiable {
    case global = "global"
    case workspace = "workspace"
    case vectorCache = "vectorCache"

    public var id: String { rawValue }
}

/// Individual conversation or composer session inside a database
public struct AgentConversationSummary: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let createdAt: Date?
    public let updatedAt: Date?
    public let mode: String?
    public let messageCount: Int?
    public let snippet: String?

    public init(
        id: String,
        title: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        mode: String? = nil,
        messageCount: Int? = nil,
        snippet: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.mode = mode
        self.messageCount = messageCount
        self.snippet = snippet
    }
}

/// Fingerprint of a database file and its WAL file for incremental scanning cache.
public struct AgentDatabaseFingerprint: Hashable, Sendable, Codable {
    public let path: String
    public let fileSizeBytes: UInt64
    public let modificationDate: Date
    public let walSizeBytes: UInt64
    public let walModificationDate: Date?
    public let isOrphaned: Bool

    public init(
        path: String,
        fileSizeBytes: UInt64,
        modificationDate: Date,
        walSizeBytes: UInt64 = 0,
        walModificationDate: Date? = nil,
        isOrphaned: Bool = false
    ) {
        self.path = path
        self.fileSizeBytes = fileSizeBytes
        self.modificationDate = modificationDate
        self.walSizeBytes = walSizeBytes
        self.walModificationDate = walModificationDate
        self.isOrphaned = isOrphaned
    }

    /// Computes fingerprint for a database file and its companion `-wal` file (if present).
    public static func compute(
        for path: String,
        isOrphaned: Bool = false
    ) -> AgentDatabaseFingerprint? {
        var st = stat()
        guard path.withCString({ stat($0, &st) }) == 0 else {
            return nil
        }
        let size = UInt64(st.st_size)
        let mtimeSec = TimeInterval(st.st_mtimespec.tv_sec) + TimeInterval(st.st_mtimespec.tv_nsec) / 1_000_000_000.0
        let mtime = Date(timeIntervalSince1970: mtimeSec)

        var walSize: UInt64 = 0
        var walMtime: Date? = nil
        let walPath = path + "-wal"
        var walSt = stat()
        if walPath.withCString({ stat($0, &walSt) }) == 0 {
            walSize = UInt64(walSt.st_size)
            let walSec = TimeInterval(walSt.st_mtimespec.tv_sec) + TimeInterval(walSt.st_mtimespec.tv_nsec) / 1_000_000_000.0
            walMtime = Date(timeIntervalSince1970: walSec)
        }

        return AgentDatabaseFingerprint(
            path: path,
            fileSizeBytes: size,
            modificationDate: mtime,
            walSizeBytes: walSize,
            walModificationDate: walMtime,
            isOrphaned: isOrphaned
        )
    }

    /// Compares physical database file attributes (main DB size & mtime, WAL size & mtime).
    public func matchesFileAttributes(of other: AgentDatabaseFingerprint) -> Bool {
        guard path == other.path,
              fileSizeBytes == other.fileSizeBytes,
              abs(modificationDate.timeIntervalSince(other.modificationDate)) < 0.001,
              walSizeBytes == other.walSizeBytes else {
            return false
        }
        switch (walModificationDate, other.walModificationDate) {
        case (nil, nil):
            return true
        case let (d1?, d2?):
            return abs(d1.timeIntervalSince(d2)) < 0.001
        default:
            return false
        }
    }

    /// Checks if this fingerprint matches a previous entry's fingerprint or attributes.
    public func matchesPrevious(entry: AgentDatabaseEntry) -> Bool {
        if let prevFp = entry.fingerprint {
            return matchesFileAttributes(of: prevFp)
        }
        return path == entry.filePath &&
            fileSizeBytes == entry.fileSizeBytes &&
            abs(modificationDate.timeIntervalSince(entry.lastModified)) < 0.001 &&
            walSizeBytes == 0
    }
}

/// A detected AI agent conversation database / storage item
public struct AgentDatabaseEntry: Identifiable, Codable, Equatable {
    public let id: String
    public let editor: AgentEditorKind
    public let scope: AgentDatabaseScope
    public let filePath: String
    public let fileName: String
    public let storageDirectory: String
    public let fileSizeBytes: UInt64
    public let lastModified: Date
    public let workspacePath: String?
    public let workspaceName: String
    public let isOrphaned: Bool
    public let conversationCount: Int
    public let conversations: [AgentConversationSummary]
    public let customEditorName: String?
    public let customAppPath: String?
    public let fingerprint: AgentDatabaseFingerprint?

    public init(
        id: String,
        editor: AgentEditorKind,
        scope: AgentDatabaseScope,
        filePath: String,
        fileName: String,
        storageDirectory: String,
        fileSizeBytes: UInt64,
        lastModified: Date,
        workspacePath: String?,
        workspaceName: String,
        isOrphaned: Bool,
        conversationCount: Int,
        conversations: [AgentConversationSummary] = [],
        customEditorName: String? = nil,
        customAppPath: String? = nil,
        fingerprint: AgentDatabaseFingerprint? = nil
    ) {
        self.id = id
        self.editor = editor
        self.scope = scope
        self.filePath = filePath
        self.fileName = fileName
        self.storageDirectory = storageDirectory
        self.fileSizeBytes = fileSizeBytes
        self.lastModified = lastModified
        self.workspacePath = workspacePath
        self.workspaceName = workspaceName
        self.isOrphaned = isOrphaned
        self.conversationCount = conversationCount
        self.conversations = conversations
        self.customEditorName = customEditorName
        self.customAppPath = customAppPath
        self.fingerprint = fingerprint ?? AgentDatabaseFingerprint(
            path: filePath,
            fileSizeBytes: fileSizeBytes,
            modificationDate: lastModified,
            isOrphaned: isOrphaned
        )
    }
}



public enum AgentDatabaseManager {
    public enum DeleteError: Error, Equatable {
        case refused(AgentDeletePolicy.Verdict)
    }

    /// Deletes a database only when `AgentDeletePolicy` allows it; the policy is re-evaluated here
    /// so no caller can bypass it. Removes SQLite `-wal`/`-shm`/`-journal` siblings too.
    @discardableResult
    public static func deleteEntry(
        _ entry: AgentDatabaseEntry,
        knownPaths: [AgentKnownPath]? = nil,
        appRunning: Bool
    ) throws -> UInt64 {
        let verdict = AgentDeletePolicy.evaluate(entry, knownPaths: knownPaths ?? entry.editor.knownStoragePaths(), appRunning: appRunning)
        guard case .allowed(let target, let isDirectory) = verdict else { throw DeleteError.refused(verdict) }
        let fm = FileManager.default
        if isDirectory {
            if fm.fileExists(atPath: target) { try fm.removeItem(atPath: target) }
            return entry.fileSizeBytes
        }
        if fm.fileExists(atPath: target) { try fm.removeItem(atPath: target) }
        for suffix in ["-wal", "-shm", "-journal"] where fm.fileExists(atPath: target + suffix) {
            try? fm.removeItem(atPath: target + suffix)
        }
        return entry.fileSizeBytes
    }

    public struct OrphanCleanResult: Equatable {
        public var deletedIds: [String] = []
        public var bytesFreed: UInt64 = 0
        public var skipped = 0
        public var failed = 0
    }

    /// Cleans orphaned workspaces one by one; refused or failing entries are counted, never fatal.
    public static func cleanOrphanedEntries(
        _ entries: [AgentDatabaseEntry],
        knownPaths: (AgentEditorKind) -> [AgentKnownPath] = { $0.knownStoragePaths() }
    ) -> OrphanCleanResult {
        var result = OrphanCleanResult()
        for entry in entries where entry.isOrphaned {
            do {
                result.bytesFreed += try deleteEntry(entry, knownPaths: knownPaths(entry.editor), appRunning: false)
                result.deletedIds.append(entry.id)
            } catch DeleteError.refused {
                result.skipped += 1
            } catch {
                result.failed += 1
            }
        }
        return result
    }

    /// Copies the database (and its `-wal`, so un-checkpointed sessions are kept) to the
    /// file the user picked in the save panel. Never overwrites an existing file.
    public static func backupEntry(_ entry: AgentDatabaseEntry, to targetURL: URL) throws {
        let fm = FileManager.default
        try fm.copyItem(at: URL(fileURLWithPath: entry.filePath), to: targetURL)
        let walPath = entry.filePath + "-wal"
        if fm.fileExists(atPath: walPath) {
            try? fm.copyItem(at: URL(fileURLWithPath: walPath), to: URL(fileURLWithPath: targetURL.path + "-wal"))
        }
    }

    /// Suggested file name for the save panel: `<editor>_<name>_<yyyyMMdd_HHmmss>.<ext>`.
    public static func suggestedBackupName(for entry: AgentDatabaseEntry, now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let safeName = entry.workspaceName.map { "/: ".contains($0) ? "_" : $0 }
        let ext = (entry.fileName as NSString).pathExtension.isEmpty ? "db" : (entry.fileName as NSString).pathExtension
        return "\(entry.editor.rawValue)_\(String(safeName))_\(formatter.string(from: now)).\(ext)"
    }
}
