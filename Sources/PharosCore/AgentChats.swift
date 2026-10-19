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
        customAppPath: String? = nil
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
    }
}

public enum AgentScanner {
    /// Scans all supported local AI agent editors for conversation databases, plus any user-specified custom application paths.
    public static func scan(homeDirectory: String = NSHomeDirectory(), customAppPaths: [String] = []) -> [AgentDatabaseEntry] {
        var entries: [AgentDatabaseEntry] = []
        entries += scanCursor(home: homeDirectory)
        entries += scanTrae(home: homeDirectory)
        entries += scanWindsurf(home: homeDirectory)
        entries += scanVSCode(home: homeDirectory)
        entries += scanAntigravity(home: homeDirectory)
        entries += scanQoder(home: homeDirectory)
        entries += scanCherryStudio(home: homeDirectory)
        entries += scanCodeBuddy(home: homeDirectory)
        entries += scanKiro(home: homeDirectory)
        entries += scanOpenCode(home: homeDirectory)
        entries += scanClaudeCode(home: homeDirectory)
        entries += scanZed(home: homeDirectory)
        entries += scanWorkBuddy(home: homeDirectory)
        entries += scanMiniMax(home: homeDirectory)
        entries += scanZCode(home: homeDirectory)
        entries += scanContinue(home: homeDirectory)
        entries += scanAider(home: homeDirectory)
        entries += scanDoubao(home: homeDirectory)
        entries += scanChatGPT(home: homeDirectory)
        entries += scanMarvis(home: homeDirectory)
        entries += scanWeChatDevTools(home: homeDirectory)
        entries += scanHBuilder(home: homeDirectory)
        entries += scanDeepSeek(home: homeDirectory)
        entries += scanAutoClaw(home: homeDirectory)
        entries += scanCCSwitch(home: homeDirectory)
        entries += scanYDevSphere(home: homeDirectory)
        entries += scanDevin(home: homeDirectory)

        for path in customAppPaths {
            entries += scanApplication(at: path, homeDirectory: homeDirectory)
        }

        // Deduplicate by entry.id and sort by file size descending
        var seen = Set<String>()
        var deduped: [AgentDatabaseEntry] = []
        for e in entries {
            if seen.insert(e.id).inserted {
                deduped.append(e)
            }
        }
        return deduped.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
    }

    /// Specifically scans a single application added by the user (from /Applications or any path).
    public static func scanApplication(at appPath: String, homeDirectory: String = NSHomeDirectory()) -> [AgentDatabaseEntry] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: appPath) else { return [] }

        // Read Info.plist if available
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        var bundleId: String?
        var bundleName: String?
        var displayName: String?

        if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            bundleId = plist["CFBundleIdentifier"] as? String
            bundleName = plist["CFBundleName"] as? String
            displayName = plist["CFBundleDisplayName"] as? String
        }

        let rawAppName = ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
        let resolvedName = displayName ?? bundleName ?? rawAppName

        // Check if it matches a predefined AgentEditorKind
        let appFileName = (appPath as NSString).lastPathComponent
        var matchedKind: AgentEditorKind? = nil
        for kind in AgentEditorKind.allCases where kind != .custom {
            if let bid = bundleId, kind.bundleIdentifiers.contains(bid) { matchedKind = kind; break }
            if kind.appNames.contains(appFileName) { matchedKind = kind; break }
            if kind.displayName.lowercased() == resolvedName.lowercased() { matchedKind = kind; break }
            if resolvedName.lowercased().contains(kind.rawValue.lowercased()) { matchedKind = kind; break }
        }

        var results: [AgentDatabaseEntry] = []

        if let kind = matchedKind {
            switch kind {
            case .cursor: results += scanCursor(home: homeDirectory)
            case .trae: results += scanTrae(home: homeDirectory)
            case .windsurf: results += scanWindsurf(home: homeDirectory)
            case .vscode: results += scanVSCode(home: homeDirectory)
            case .antigravity: results += scanAntigravity(home: homeDirectory)
            case .qoder: results += scanQoder(home: homeDirectory)
            case .cherryStudio: results += scanCherryStudio(home: homeDirectory)
            case .codeBuddy: results += scanCodeBuddy(home: homeDirectory)
            case .kiro: results += scanKiro(home: homeDirectory)
            case .openCode: results += scanOpenCode(home: homeDirectory)
            case .claudeCode: results += scanClaudeCode(home: homeDirectory)
            case .zed: results += scanZed(home: homeDirectory)
            case .workBuddy: results += scanWorkBuddy(home: homeDirectory)
            case .miniMax: results += scanMiniMax(home: homeDirectory)
            case .zCode: results += scanZCode(home: homeDirectory)
            case .continueExt: results += scanContinue(home: homeDirectory)
            case .aider: results += scanAider(home: homeDirectory)
            case .doubao: results += scanDoubao(home: homeDirectory)
            case .chatgpt: results += scanChatGPT(home: homeDirectory)
            case .marvis: results += scanMarvis(home: homeDirectory)
            case .wechatDevTools: results += scanWeChatDevTools(home: homeDirectory)
            case .hbuilder: results += scanHBuilder(home: homeDirectory)
            case .deepseek: results += scanDeepSeek(home: homeDirectory)
            case .autoClaw: results += scanAutoClaw(home: homeDirectory)
            case .ccSwitch: results += scanCCSwitch(home: homeDirectory)
            case .yDevSphere: results += scanYDevSphere(home: homeDirectory)
            case .devin: results += scanDevin(home: homeDirectory)
            case .custom: break
            }
        }

        // Deep probe candidate storage directories for this app
        var candidateDirs: Set<String> = []
        var namesToProbe: [String] = [resolvedName, rawAppName]
        if let bn = bundleName { namesToProbe.append(bn) }
        if let bid = bundleId, let lastPart = bid.components(separatedBy: ".").last { namesToProbe.append(lastPart) }

        for name in namesToProbe {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/\(trimmed)")
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/\(trimmed) CN")
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/\(trimmed) AI")
            candidateDirs.insert("\(homeDirectory)/.\(trimmed.lowercased())")
            candidateDirs.insert("\(homeDirectory)/.\(trimmed.lowercased())-ai")
            candidateDirs.insert("\(homeDirectory)/.config/\(trimmed.lowercased())")
            candidateDirs.insert("\(homeDirectory)/.local/share/\(trimmed.lowercased())")
        }

        if let bid = bundleId, !bid.isEmpty {
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/\(bid)")
            candidateDirs.insert("\(homeDirectory)/Library/Containers/\(bid)/Data/Library/Application Support/\(resolvedName)")
            candidateDirs.insert("\(homeDirectory)/Library/Containers/\(bid)/Data/Library/Application Support")
        }

        if resolvedName.lowercased().contains("ollama") {
            candidateDirs.insert("\(homeDirectory)/.ollama")
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/Ollama")
        }
        if resolvedName.lowercased().contains("lm studio") {
            candidateDirs.insert("\(homeDirectory)/.cache/lm-studio")
            candidateDirs.insert("\(homeDirectory)/Library/Application Support/LM Studio")
        }

        let editorKind = matchedKind ?? .custom

        for dir in candidateDirs {
            guard fm.fileExists(atPath: dir) else { continue }

            // 1. VS Code style workspaceStorage
            let wsCandidates = [
                (dir as NSString).appendingPathComponent("User/workspaceStorage"),
                (dir as NSString).appendingPathComponent("workspaceStorage")
            ]
            for wsRoot in wsCandidates where fm.fileExists(atPath: wsRoot) {
                let wsEntries = scanWorkspaceStorage(root: wsRoot, editor: editorKind)
                for entry in wsEntries {
                    results.append(AgentDatabaseEntry(
                        id: entry.id,
                        editor: editorKind,
                        scope: .workspace,
                        filePath: entry.filePath,
                        fileName: entry.fileName,
                        storageDirectory: entry.storageDirectory,
                        fileSizeBytes: entry.fileSizeBytes,
                        lastModified: entry.lastModified,
                        workspacePath: entry.workspacePath,
                        workspaceName: entry.workspaceName,
                        isOrphaned: entry.isOrphaned,
                        conversationCount: entry.conversationCount,
                        conversations: entry.conversations,
                        customEditorName: resolvedName,
                        customAppPath: appPath
                    ))
                }
            }

            // 2. Global state.vscdb
            let globalCandidates = [
                (dir as NSString).appendingPathComponent("User/globalStorage/state.vscdb"),
                (dir as NSString).appendingPathComponent("globalStorage/state.vscdb")
            ]
            for gPath in globalCandidates where fm.fileExists(atPath: gPath) {
                if let attrs = try? fm.attributesOfItem(atPath: gPath),
                   let size = attrs[.size] as? UInt64,
                   let mtime = attrs[.modificationDate] as? Date {
                    var total = size
                    if let wal = try? fm.attributesOfItem(atPath: gPath + "-wal"), let ws = wal[.size] as? UInt64 {
                        total += ws
                    }
                    let convs = AgentSQLiteReader.readCursorConversations(dbPath: gPath)
                    results.append(AgentDatabaseEntry(
                        id: gPath,
                        editor: editorKind,
                        scope: .global,
                        filePath: gPath,
                        fileName: "state.vscdb",
                        storageDirectory: (gPath as NSString).deletingLastPathComponent,
                        fileSizeBytes: total,
                        lastModified: mtime,
                        workspacePath: nil,
                        workspaceName: "\(resolvedName) 全局状态",
                        isOrphaned: false,
                        conversationCount: convs.count,
                        conversations: convs,
                        customEditorName: resolvedName,
                        customAppPath: appPath
                    ))
                }
            }

            // 3. Scan directory files for SQLite databases (*.db, *.sqlite, *.sqlite3)
            let dbFiles = findDatabaseFiles(in: dir, maxDepth: 2)
            for filePath in dbFiles {
                let fileName = (filePath as NSString).lastPathComponent
                if fileName == "state.vscdb" && results.contains(where: { $0.filePath == filePath }) {
                    continue
                }
                guard AgentSQLiteReader.isSQLiteFile(atPath: filePath) else { continue }
                guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                      let size = attrs[.size] as? UInt64,
                      let mtime = attrs[.modificationDate] as? Date else { continue }

                var total = size
                if let wal = try? fm.attributesOfItem(atPath: filePath + "-wal"), let ws = wal[.size] as? UInt64 {
                    total += ws
                }

                let convs = AgentSQLiteReader.readGenericConversations(dbPath: filePath)
                let scope: AgentDatabaseScope = filePath.contains("cache") || filePath.contains("index") ? .vectorCache : .global

                results.append(AgentDatabaseEntry(
                    id: filePath,
                    editor: editorKind,
                    scope: scope,
                    filePath: filePath,
                    fileName: fileName,
                    storageDirectory: (filePath as NSString).deletingLastPathComponent,
                    fileSizeBytes: total,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "\(resolvedName) (\(fileName))",
                    isOrphaned: false,
                    conversationCount: convs.count,
                    conversations: convs,
                    customEditorName: resolvedName,
                    customAppPath: appPath
                ))
            }
        }

        // Deduplicate by entry.id
        var seen = Set<String>()
        var uniqueResults: [AgentDatabaseEntry] = []
        for e in results {
            if seen.insert(e.id).inserted {
                uniqueResults.append(e)
            }
        }

        return uniqueResults.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
    }

    private static func findDatabaseFiles(in dir: String, maxDepth: Int) -> [String] {
        guard maxDepth >= 0 else { return [] }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        var results: [String] = []
        for item in items {
            if item.hasPrefix(".") || item == "node_modules" || item == "Pods" || item == "DerivedData" || item == "Cache" || item == "Caches" {
                continue
            }
            let fullPath = (dir as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: fullPath, isDirectory: &isDir) {
                if isDir.boolValue {
                    if maxDepth > 0 && !["GPUCache", "DawnCache", "blob_storage", "Session Storage", "IndexedDB", "Local Storage"].contains(item) {
                        results += findDatabaseFiles(in: fullPath, maxDepth: maxDepth - 1)
                    }
                } else {
                    let ext = (item as NSString).pathExtension.lowercased()
                    if ["db", "sqlite", "sqlite3", "vscdb", "db3"].contains(ext) {
                        if !item.hasSuffix("-wal") && !item.hasSuffix("-shm") && !item.hasSuffix("-journal") {
                            results.append(fullPath)
                        }
                    }
                }
            }
        }
        return results
    }

    // MARK: - Cursor
    public static func scanCursor(home: String) -> [AgentDatabaseEntry] {
        let base = (home as NSString).appendingPathComponent("Library/Application Support/Cursor/User")
        var results: [AgentDatabaseEntry] = []

        // Global storage
        let globalDb = (base as NSString).appendingPathComponent("globalStorage/state.vscdb")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: globalDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            let conversations = AgentSQLiteReader.readCursorConversations(dbPath: globalDb)
            results.append(AgentDatabaseEntry(
                id: globalDb,
                editor: .cursor,
                scope: .global,
                filePath: globalDb,
                fileName: "state.vscdb",
                storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "Global Composer Sessions",
                isOrphaned: false,
                conversationCount: conversations.count,
                conversations: conversations
            ))
        }

        // AI code tracking
        let trackDb = (home as NSString).appendingPathComponent(".cursor/ai-tracking/ai-code-tracking.db")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: trackDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            results.append(AgentDatabaseEntry(
                id: trackDb,
                editor: .cursor,
                scope: .global,
                filePath: trackDb,
                fileName: "ai-code-tracking.db",
                storageDirectory: (trackDb as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "Cursor AI 代码追踪库",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }

        // Workspace storage
        let wsRoot = (base as NSString).appendingPathComponent("workspaceStorage")
        results += scanWorkspaceStorage(root: wsRoot, editor: .cursor)

        return results
    }

    // MARK: - Trae
    public static func scanTrae(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let variants = ["Trae CN", "TRAE SOLO CN", "Trae"]

        for variant in variants {
            let base = (home as NSString).appendingPathComponent("Library/Application Support/\(variant)/User")

            // Modular AI Agent Database (Trae's primary conversation DB ~481+ MB)
            let modularDb = (home as NSString).appendingPathComponent("Library/Application Support/\(variant)/ModularData/ai-agent/database.db")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: modularDb),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                var totalSize = size
                let wal = modularDb + "-wal"
                if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                   let walSize = walAttrs[.size] as? UInt64 {
                    totalSize += walSize
                }
                let modularDir = (modularDb as NSString).deletingLastPathComponent
                let sessions = AgentSQLiteReader.readTraeAgentDatabaseSessions(modularDir: modularDir)
                results.append(AgentDatabaseEntry(
                    id: modularDb,
                    editor: .trae,
                    scope: .global,
                    filePath: modularDb,
                    fileName: "database.db (AI Agent)",
                    storageDirectory: (modularDb as NSString).deletingLastPathComponent,
                    fileSizeBytes: totalSize,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "\(variant) AI Agent Sessions",
                    isOrphaned: false,
                    conversationCount: sessions.count,
                    conversations: sessions
                ))
            }

            // Global storage
            let globalDb = (base as NSString).appendingPathComponent("globalStorage/state.vscdb")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: globalDb),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                let sessions = AgentSQLiteReader.readTraeSessions(dbPath: globalDb)
                results.append(AgentDatabaseEntry(
                    id: globalDb,
                    editor: .trae,
                    scope: .global,
                    filePath: globalDb,
                    fileName: "state.vscdb",
                    storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "\(variant) Global Storage",
                    isOrphaned: false,
                    conversationCount: sessions.count,
                    conversations: sessions
                ))
            }

            // Vector & Knowledge Graph DBs (.ckg/storage)
            let ckgRoot = (base as NSString).appendingPathComponent("globalStorage/.ckg/storage")
            if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: ckgRoot) {
                for dir in subdirs {
                    let dirPath = (ckgRoot as NSString).appendingPathComponent(dir)
                    if let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath) {
                        for file in files where file.hasSuffix(".db") {
                            let filePath = (dirPath as NSString).appendingPathComponent(file)
                            if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                                let size = attrs[.size] as? UInt64,
                                let mtime = attrs[.modificationDate] as? Date {
                                // Extract project name from file name (e.g. "campus-wall_xxx_codekg.db")
                                let cleanName = file.components(separatedBy: "_").first ?? file
                                results.append(AgentDatabaseEntry(
                                    id: filePath,
                                    editor: .trae,
                                    scope: .vectorCache,
                                    filePath: filePath,
                                    fileName: file,
                                    storageDirectory: dirPath,
                                    fileSizeBytes: size,
                                    lastModified: mtime,
                                    workspacePath: nil,
                                    workspaceName: "\(cleanName) (Knowledge Cache)",
                                    isOrphaned: false,
                                    conversationCount: 0,
                                    conversations: []
                                ))
                            }
                        }
                    }
                }
            }

            // Workspaces
            let wsRoot = (base as NSString).appendingPathComponent("workspaceStorage")
            results += scanWorkspaceStorage(root: wsRoot, editor: .trae)
        }

        // Forensics baseline database if available (~428 MB)
        let forensicsRoot = (home as NSString).appendingPathComponent("trae-forensics/original-copies")
        if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: forensicsRoot) {
            for sub in subdirs {
                let db = (forensicsRoot as NSString).appendingPathComponent("\(sub)/database.db")
                if let attrs = try? FileManager.default.attributesOfItem(atPath: db),
                   let size = attrs[.size] as? UInt64,
                   let mtime = attrs[.modificationDate] as? Date {
                    var total = size
                    let wal = db + "-wal"
                    if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                       let walSize = walAttrs[.size] as? UInt64 {
                        total += walSize
                    }
                    results.append(AgentDatabaseEntry(
                        id: db,
                        editor: .trae,
                        scope: .global,
                        filePath: db,
                        fileName: "database.db (Forensics Baseline)",
                        storageDirectory: (db as NSString).deletingLastPathComponent,
                        fileSizeBytes: total,
                        lastModified: mtime,
                        workspacePath: nil,
                        workspaceName: "Trae 基准归档数据库 (\(sub))",
                        isOrphaned: false,
                        conversationCount: 0,
                        conversations: []
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Windsurf
    public static func scanWindsurf(home: String) -> [AgentDatabaseEntry] {
        let base = (home as NSString).appendingPathComponent("Library/Application Support/Windsurf/User")
        var results: [AgentDatabaseEntry] = []

        let globalDb = (base as NSString).appendingPathComponent("globalStorage/state.vscdb")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: globalDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            let rowCount = AgentSQLiteReader.countItemTableRows(dbPath: globalDb)
            results.append(AgentDatabaseEntry(
                id: globalDb,
                editor: .windsurf,
                scope: .global,
                filePath: globalDb,
                fileName: "state.vscdb",
                storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "Windsurf Global Cascade",
                isOrphaned: false,
                conversationCount: rowCount,
                conversations: []
            ))
        }

        let wsRoot = (base as NSString).appendingPathComponent("workspaceStorage")
        results += scanWorkspaceStorage(root: wsRoot, editor: .windsurf)

        return results
    }

    // MARK: - VS Code
    public static func scanVSCode(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let variants = ["Code", "Code - Insiders"]

        for variant in variants {
            let base = (home as NSString).appendingPathComponent("Library/Application Support/\(variant)/User")

            // GitHub Copilot Chat Session Store DB
            let copilotDb = (base as NSString).appendingPathComponent("globalStorage/github.copilot-chat/session-store.db")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: copilotDb),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                let convs = AgentSQLiteReader.readCopilotConversations(dbPath: copilotDb)
                results.append(AgentDatabaseEntry(
                    id: copilotDb,
                    editor: .vscode,
                    scope: .global,
                    filePath: copilotDb,
                    fileName: "session-store.db",
                    storageDirectory: (copilotDb as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "Copilot Chat Sessions",
                    isOrphaned: false,
                    conversationCount: convs.count,
                    conversations: convs
                ))
            }

            // Global storage state.vscdb
            let globalDb = (base as NSString).appendingPathComponent("globalStorage/state.vscdb")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: globalDb),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                results.append(AgentDatabaseEntry(
                    id: globalDb,
                    editor: .vscode,
                    scope: .global,
                    filePath: globalDb,
                    fileName: "state.vscdb",
                    storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "VS Code Global State",
                    isOrphaned: false,
                    conversationCount: 0,
                    conversations: []
                ))
            }

            // Workspaces
            let wsRoot = (base as NSString).appendingPathComponent("workspaceStorage")
            results += scanWorkspaceStorage(root: wsRoot, editor: .vscode)
        }

        return results
    }

    // MARK: - Antigravity
    public static func scanAntigravity(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let dbPath = (home as NSString).appendingPathComponent(".gemini/antigravity/conversation_summaries.db")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            let convs = AgentSQLiteReader.readAntigravityConversations(dbPath: dbPath)
            results.append(AgentDatabaseEntry(
                id: dbPath,
                editor: .antigravity,
                scope: .global,
                filePath: dbPath,
                fileName: "conversation_summaries.db",
                storageDirectory: (dbPath as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "Antigravity 对话汇总数据库",
                isOrphaned: false,
                conversationCount: convs.count,
                conversations: convs
            ))
        }

        // Scan individual conversation databases in ~/.gemini/antigravity/conversations/*.db
        let convsDir = (home as NSString).appendingPathComponent(".gemini/antigravity/conversations")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: convsDir) {
            for file in files where file.hasSuffix(".db") {
                let fullPath = (convsDir as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? UInt64,
                   let mtime = attrs[.modificationDate] as? Date {
                    var totalSize = size
                    let wal = fullPath + "-wal"
                    if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                       let walSize = walAttrs[.size] as? UInt64 {
                        totalSize += walSize
                    }
                    let convId = (file as NSString).deletingPathExtension
                    results.append(AgentDatabaseEntry(
                        id: fullPath,
                        editor: .antigravity,
                        scope: .global,
                        filePath: fullPath,
                        fileName: file,
                        storageDirectory: convsDir,
                        fileSizeBytes: totalSize,
                        lastModified: mtime,
                        workspacePath: nil,
                        workspaceName: "Antigravity 会话库 (\(convId.prefix(8)))",
                        isOrphaned: false,
                        conversationCount: 1,
                        conversations: []
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Qoder / Qoder CN
    public static func scanQoder(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let variants = ["QoderCN", "Qoder"]

        for variant in variants {
            let base = (home as NSString).appendingPathComponent("Library/Application Support/\(variant)")

            // Main chat session SQLite local.db
            let localDb = (base as NSString).appendingPathComponent("SharedClientCache/cache/db/local.db")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: localDb),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                var total = size
                let wal = localDb + "-wal"
                if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                   let walSize = walAttrs[.size] as? UInt64 {
                    total += walSize
                }
                let convs = AgentSQLiteReader.readQoderConversations(dbPath: localDb)
                results.append(AgentDatabaseEntry(
                    id: localDb,
                    editor: .qoder,
                    scope: .global,
                    filePath: localDb,
                    fileName: "local.db",
                    storageDirectory: (localDb as NSString).deletingLastPathComponent,
                    fileSizeBytes: total,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "\(variant) Chat Sessions",
                    isOrphaned: false,
                    conversationCount: convs.count,
                    conversations: convs
                ))
            }

            // Vector index DBs in index/vector/v5
            let vectorRoot = (base as NSString).appendingPathComponent("SharedClientCache/index/vector/v5")
            if let enumerator = FileManager.default.enumerator(atPath: vectorRoot) {
                while let item = enumerator.nextObject() as? String {
                    if item.hasSuffix(".db") {
                        let fullPath = (vectorRoot as NSString).appendingPathComponent(item)
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                           let size = attrs[.size] as? UInt64,
                           let mtime = attrs[.modificationDate] as? Date {
                            var total = size
                            let wal = fullPath + "-wal"
                            if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                               let walSize = walAttrs[.size] as? UInt64 {
                                total += walSize
                            }
                            let projName = item.components(separatedBy: "/").first ?? item
                            results.append(AgentDatabaseEntry(
                                id: fullPath,
                                editor: .qoder,
                                scope: .vectorCache,
                                filePath: fullPath,
                                fileName: (item as NSString).lastPathComponent,
                                storageDirectory: (fullPath as NSString).deletingLastPathComponent,
                                fileSizeBytes: total,
                                lastModified: mtime,
                                workspacePath: nil,
                                workspaceName: "\(variant) 向量索引 (\(projName.prefix(20)))",
                                isOrphaned: false,
                                conversationCount: 0,
                                conversations: []
                            ))
                        }
                    }
                }
            }

            // Meta index DBs in index/meta/v8
            let metaRoot = (base as NSString).appendingPathComponent("SharedClientCache/index/meta/v8")
            if let enumerator = FileManager.default.enumerator(atPath: metaRoot) {
                while let item = enumerator.nextObject() as? String {
                    if item.hasSuffix(".db") {
                        let fullPath = (metaRoot as NSString).appendingPathComponent(item)
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                           let size = attrs[.size] as? UInt64,
                           let mtime = attrs[.modificationDate] as? Date {
                            results.append(AgentDatabaseEntry(
                                id: fullPath,
                                editor: .qoder,
                                scope: .vectorCache,
                                filePath: fullPath,
                                fileName: (item as NSString).lastPathComponent,
                                storageDirectory: (fullPath as NSString).deletingLastPathComponent,
                                fileSizeBytes: size,
                                lastModified: mtime,
                                workspacePath: nil,
                                workspaceName: "\(variant) 元数据索引",
                                isOrphaned: false,
                                conversationCount: 0,
                                conversations: []
                            ))
                        }
                    }
                }
            }

            // Knowledge DB
            let knowledgeDb = (base as NSString).appendingPathComponent("SharedClientCache/repowiki/knowledge.db")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: knowledgeDb),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                results.append(AgentDatabaseEntry(
                    id: knowledgeDb,
                    editor: .qoder,
                    scope: .vectorCache,
                    filePath: knowledgeDb,
                    fileName: "knowledge.db",
                    storageDirectory: (knowledgeDb as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "\(variant) Knowledge Base",
                    isOrphaned: false,
                    conversationCount: 0,
                    conversations: []
                ))
            }

            // Global state.vscdb
            let globalDb = (base as NSString).appendingPathComponent("User/globalStorage/state.vscdb")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: globalDb),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                results.append(AgentDatabaseEntry(
                    id: globalDb,
                    editor: .qoder,
                    scope: .global,
                    filePath: globalDb,
                    fileName: "state.vscdb",
                    storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "\(variant) Global Storage",
                    isOrphaned: false,
                    conversationCount: 0,
                    conversations: []
                ))
            }

            // Workspace storage
            let wsRoot = (base as NSString).appendingPathComponent("User/workspaceStorage")
            results += scanWorkspaceStorage(root: wsRoot, editor: .qoder)
        }

        // Main.sqlite in stable support dirs
        let appSupportDirs = [
            "Library/Application Support/com.qoder.app.stable",
            "Library/Application Support/com.qodercn.app.stable"
        ]
        for rel in appSupportDirs {
            let fullPath = (home as NSString).appendingPathComponent("\(rel)/main.sqlite")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                var total = size
                let wal = fullPath + "-wal"
                if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                   let walSize = walAttrs[.size] as? UInt64 {
                    total += walSize
                }
                results.append(AgentDatabaseEntry(
                    id: fullPath,
                    editor: .qoder,
                    scope: .global,
                    filePath: fullPath,
                    fileName: "main.sqlite",
                    storageDirectory: (fullPath as NSString).deletingLastPathComponent,
                    fileSizeBytes: total,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "\((rel as NSString).lastPathComponent) 主数据库",
                    isOrphaned: false,
                    conversationCount: 0,
                    conversations: []
                ))
            }
        }

        return results
    }

    // MARK: - Cherry Studio
    public static func scanCherryStudio(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let candidates = [
            "Library/Application Support/CherryStudio/Data/agents.db",
            "Library/Application Support/Cherry Studio/Data/agents.db",
            "Library/Application Support/CherryStudio/agents.db"
        ]

        for rel in candidates {
            let dbPath = (home as NSString).appendingPathComponent(rel)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                let convs = AgentSQLiteReader.readCherryStudioConversations(dbPath: dbPath)
                results.append(AgentDatabaseEntry(
                    id: dbPath,
                    editor: .cherryStudio,
                    scope: .global,
                    filePath: dbPath,
                    fileName: "agents.db",
                    storageDirectory: (dbPath as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "Cherry Studio Agent Sessions",
                    isOrphaned: false,
                    conversationCount: convs.count,
                    conversations: convs
                ))
                break
            }
        }

        return results
    }

    // MARK: - CodeBuddy
    public static func scanCodeBuddy(home: String) -> [AgentDatabaseEntry] {
        let base = (home as NSString).appendingPathComponent("Library/Application Support/CodeBuddy CN")
        var results: [AgentDatabaseEntry] = []

        // Dedicated session database
        let sessionDb = (base as NSString).appendingPathComponent("codebuddy-sessions.vscdb")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: sessionDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            let convs = AgentSQLiteReader.readCodeBuddyConversations(dbPath: sessionDb)
            results.append(AgentDatabaseEntry(
                id: sessionDb,
                editor: .codeBuddy,
                scope: .global,
                filePath: sessionDb,
                fileName: "codebuddy-sessions.vscdb",
                storageDirectory: base,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "CodeBuddy Session Store",
                isOrphaned: false,
                conversationCount: convs.count,
                conversations: convs
            ))
        }

        // Global storage
        let globalDb = (base as NSString).appendingPathComponent("User/globalStorage/state.vscdb")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: globalDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            results.append(AgentDatabaseEntry(
                id: globalDb,
                editor: .codeBuddy,
                scope: .global,
                filePath: globalDb,
                fileName: "state.vscdb",
                storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "CodeBuddy Global Storage",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }

        let wsRoot = (base as NSString).appendingPathComponent("User/workspaceStorage")
        results += scanWorkspaceStorage(root: wsRoot, editor: .codeBuddy)

        return results
    }

    // MARK: - Kiro
    public static func scanKiro(home: String) -> [AgentDatabaseEntry] {
        let base = (home as NSString).appendingPathComponent("Library/Application Support/Kiro/User")
        var results: [AgentDatabaseEntry] = []

        let globalDb = (base as NSString).appendingPathComponent("globalStorage/state.vscdb")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: globalDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            results.append(AgentDatabaseEntry(
                id: globalDb,
                editor: .kiro,
                scope: .global,
                filePath: globalDb,
                fileName: "state.vscdb",
                storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "Kiro Global Storage",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }

        let wsRoot = (base as NSString).appendingPathComponent("workspaceStorage")
        results += scanWorkspaceStorage(root: wsRoot, editor: .kiro)

        return results
    }

    // MARK: - Claude Code
    public static func scanClaudeCode(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let historyPath = (home as NSString).appendingPathComponent(".claude/history.jsonl")

        if let attrs = try? FileManager.default.attributesOfItem(atPath: historyPath),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            let conversations = parseClaudeHistory(path: historyPath)
            results.append(AgentDatabaseEntry(
                id: historyPath,
                editor: .claudeCode,
                scope: .global,
                filePath: historyPath,
                fileName: "history.jsonl",
                storageDirectory: (historyPath as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "Claude Code CLI History",
                isOrphaned: false,
                conversationCount: conversations.count,
                conversations: conversations
            ))
        }

        return results
    }

    // MARK: - OpenCode
    public static func scanOpenCode(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. Primary conversation database in ~/.local/share/opencode/opencode.db (~5.5 GB)
        let mainDb = (home as NSString).appendingPathComponent(".local/share/opencode/opencode.db")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: mainDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            var totalSize = size
            let wal = mainDb + "-wal"
            if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
               let walSize = walAttrs[.size] as? UInt64 {
                totalSize += walSize
            }
            let sessions = AgentSQLiteReader.readOpenCodeSessions(dbPath: mainDb)
            results.append(AgentDatabaseEntry(
                id: mainDb,
                editor: .openCode,
                scope: .global,
                filePath: mainDb,
                fileName: "opencode.db",
                storageDirectory: (mainDb as NSString).deletingLastPathComponent,
                fileSizeBytes: totalSize,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "OpenCode 核心会话数据库",
                isOrphaned: false,
                conversationCount: sessions.count,
                conversations: sessions
            ))
        }

        // 2. Auxiliary drafts database in Library/Application Support/ai.opencode.desktop
        let base = (home as NSString).appendingPathComponent("Library/Application Support/ai.opencode.desktop")
        let draftsDb = (base as NSString).appendingPathComponent("drafts.sqlite")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: draftsDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            results.append(AgentDatabaseEntry(
                id: draftsDb,
                editor: .openCode,
                scope: .global,
                filePath: draftsDb,
                fileName: "drafts.sqlite",
                storageDirectory: base,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "OpenCode 草稿与临时存储",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }

        return results
    }

    // MARK: - Zed
    public static func scanZed(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let dbDir = (home as NSString).appendingPathComponent("Library/Application Support/Zed/db")
        if let enumerator = FileManager.default.enumerator(atPath: dbDir) {
            while let file = enumerator.nextObject() as? String {
                if file.hasSuffix(".sqlite") || file.hasSuffix(".db") {
                    let fullPath = (dbDir as NSString).appendingPathComponent(file)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? UInt64,
                       let mtime = attrs[.modificationDate] as? Date {
                        results.append(AgentDatabaseEntry(
                            id: fullPath,
                            editor: .zed,
                            scope: .global,
                            filePath: fullPath,
                            fileName: (file as NSString).lastPathComponent,
                            storageDirectory: (fullPath as NSString).deletingLastPathComponent,
                            fileSizeBytes: size,
                            lastModified: mtime,
                            workspacePath: nil,
                            workspaceName: "Zed Database (\((file as NSString).lastPathComponent))",
                            isOrphaned: false,
                            conversationCount: 0,
                            conversations: []
                        ))
                    }
                }
            }
        }
        return results
    }

    // MARK: - WorkBuddy
    public static func scanWorkBuddy(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. ~/.workbuddy and ~/.workbuddy-ai
        let homeDirs = [
            (home as NSString).appendingPathComponent(".workbuddy"),
            (home as NSString).appendingPathComponent(".workbuddy-ai")
        ]
        for dir in homeDirs {
            let isAI = dir.contains("-ai")
            let prefix = isAI ? "WorkBuddy AI" : "WorkBuddy"

            // Main workbuddy.db
            let mainDb = (dir as NSString).appendingPathComponent("workbuddy.db")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: mainDb),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                var total = size
                let wal = mainDb + "-wal"
                if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                   let walSize = walAttrs[.size] as? UInt64 {
                    total += walSize
                }
                results.append(AgentDatabaseEntry(
                    id: mainDb,
                    editor: .workBuddy,
                    scope: .global,
                    filePath: mainDb,
                    fileName: "workbuddy.db",
                    storageDirectory: dir,
                    fileSizeBytes: total,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "\(prefix) 核心数据库",
                    isOrphaned: false,
                    conversationCount: 0,
                    conversations: []
                ))
            }

            // Threat database
            let threatDir = (dir as NSString).appendingPathComponent("security/threat-database")
            if let files = try? FileManager.default.contentsOfDirectory(atPath: threatDir) {
                for file in files where file.hasSuffix(".db") {
                    let fullPath = (threatDir as NSString).appendingPathComponent(file)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? UInt64,
                       let mtime = attrs[.modificationDate] as? Date {
                        var total = size
                        let wal = fullPath + "-wal"
                        if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                           let walSize = walAttrs[.size] as? UInt64 {
                            total += walSize
                        }
                        results.append(AgentDatabaseEntry(
                            id: fullPath,
                            editor: .workBuddy,
                            scope: .global,
                            filePath: fullPath,
                            fileName: file,
                            storageDirectory: threatDir,
                            fileSizeBytes: total,
                            lastModified: mtime,
                            workspacePath: nil,
                            workspaceName: "\(prefix) 安全与威胁数据库",
                            isOrphaned: false,
                            conversationCount: 0,
                            conversations: []
                        ))
                    }
                }
            }
        }

        // 2. Library/Application Support dirs
        let dirs = [
            "Library/Application Support/com.tencent.workbuddy.mac",
            "Library/Application Support/WorkBuddy AI",
            "Library/Application Support/WorkBuddy"
        ]
        for rel in dirs {
            let fullDir = (home as NSString).appendingPathComponent(rel)
            if let files = try? FileManager.default.contentsOfDirectory(atPath: fullDir) {
                for file in files where file.hasSuffix(".db") || file.hasSuffix(".sqlite") || file.hasSuffix(".vscdb") {
                    let filePath = (fullDir as NSString).appendingPathComponent(file)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                       let size = attrs[.size] as? UInt64,
                       let mtime = attrs[.modificationDate] as? Date {
                        results.append(AgentDatabaseEntry(
                            id: filePath,
                            editor: .workBuddy,
                            scope: .global,
                            filePath: filePath,
                            fileName: file,
                            storageDirectory: fullDir,
                            fileSizeBytes: size,
                            lastModified: mtime,
                            workspacePath: nil,
                            workspaceName: "WorkBuddy Data (\(file))",
                            isOrphaned: false,
                            conversationCount: 0,
                            conversations: []
                        ))
                    }
                }
            }
        }
        return results
    }

    // MARK: - MiniMax
    public static func scanMiniMax(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. MiniMax Code runtime opencode.db (~3.7 GB)
        let hiloDb = (home as NSString).appendingPathComponent("Library/Application Support/@hilo/MiniMax Hub Global/ai-runtime/data-home/opencode/opencode.db")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: hiloDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            var totalSize = size
            let wal = hiloDb + "-wal"
            if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
               let walSize = walAttrs[.size] as? UInt64 {
                totalSize += walSize
            }
            let sessions = AgentSQLiteReader.readOpenCodeSessions(dbPath: hiloDb)
            results.append(AgentDatabaseEntry(
                id: hiloDb,
                editor: .miniMax,
                scope: .global,
                filePath: hiloDb,
                fileName: "opencode.db (MiniMax Runtime)",
                storageDirectory: (hiloDb as NSString).deletingLastPathComponent,
                fileSizeBytes: totalSize,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "MiniMax Code 核心对话数据库",
                isOrphaned: false,
                conversationCount: sessions.count,
                conversations: sessions
            ))
        }

        // 2. ~/.minimax/v2/sqlite/runtime-state.sqlite (+ WAL ~5.5 MB)
        let minimaxSqliteDir = (home as NSString).appendingPathComponent(".minimax/v2/sqlite")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: minimaxSqliteDir) {
            for file in files where file.hasSuffix(".sqlite") || file.hasSuffix(".db") {
                let fullPath = (minimaxSqliteDir as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? UInt64,
                   let mtime = attrs[.modificationDate] as? Date {
                    var total = size
                    let wal = fullPath + "-wal"
                    if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                       let walSize = walAttrs[.size] as? UInt64 {
                        total += walSize
                    }
                    results.append(AgentDatabaseEntry(
                        id: fullPath,
                        editor: .miniMax,
                        scope: .global,
                        filePath: fullPath,
                        fileName: file,
                        storageDirectory: minimaxSqliteDir,
                        fileSizeBytes: total,
                        lastModified: mtime,
                        workspacePath: nil,
                        workspaceName: "MiniMax 运行时状态数据库",
                        isOrphaned: false,
                        conversationCount: 0,
                        conversations: []
                    ))
                }
            }
        }

        // 3. MiniMax Agent / Support dirs
        let dirs = [
            "Library/Application Support/MiniMax Agent",
            "Library/Application Support/MiniMax"
        ]
        for rel in dirs {
            let fullDir = (home as NSString).appendingPathComponent(rel)
            let sharedDb = (fullDir as NSString).appendingPathComponent("Shared Dictionary/db")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: sharedDb),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                results.append(AgentDatabaseEntry(
                    id: sharedDb,
                    editor: .miniMax,
                    scope: .global,
                    filePath: sharedDb,
                    fileName: "Shared Dictionary db",
                    storageDirectory: (sharedDb as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "\((rel as NSString).lastPathComponent) 缓存数据库",
                    isOrphaned: false,
                    conversationCount: 0,
                    conversations: []
                ))
            }
        }
        return results
    }

    // MARK: - ZCode
    public static func scanZCode(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. ~/.zcode/cli/db/db.sqlite (4.8 MB)
        let cliDb = (home as NSString).appendingPathComponent(".zcode/cli/db/db.sqlite")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: cliDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            var total = size
            let wal = cliDb + "-wal"
            if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
               let walSize = walAttrs[.size] as? UInt64 {
                total += walSize
            }
            results.append(AgentDatabaseEntry(
                id: cliDb,
                editor: .zCode,
                scope: .global,
                filePath: cliDb,
                fileName: "db.sqlite",
                storageDirectory: (cliDb as NSString).deletingLastPathComponent,
                fileSizeBytes: total,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "ZCode CLI 核心数据库",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }

        // 2. ~/.zcode/v2/tasks-index.sqlite (296 KB)
        let taskDb = (home as NSString).appendingPathComponent(".zcode/v2/tasks-index.sqlite")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: taskDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            results.append(AgentDatabaseEntry(
                id: taskDb,
                editor: .zCode,
                scope: .global,
                filePath: taskDb,
                fileName: "tasks-index.sqlite",
                storageDirectory: (taskDb as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "ZCode 任务索引库",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }

        // 3. Library/Application Support/ZCode/session
        let base = (home as NSString).appendingPathComponent("Library/Application Support/ZCode/session")
        if let enumerator = FileManager.default.enumerator(atPath: base) {
            while let file = enumerator.nextObject() as? String {
                if file.hasSuffix(".db") || file.hasSuffix(".sqlite") || file == "SharedStorage" {
                    let fullPath = (base as NSString).appendingPathComponent(file)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? UInt64,
                       let mtime = attrs[.modificationDate] as? Date {
                        results.append(AgentDatabaseEntry(
                            id: fullPath,
                            editor: .zCode,
                            scope: .global,
                            filePath: fullPath,
                            fileName: (file as NSString).lastPathComponent,
                            storageDirectory: (fullPath as NSString).deletingLastPathComponent,
                            fileSizeBytes: size,
                            lastModified: mtime,
                            workspacePath: nil,
                            workspaceName: "ZCode Session Storage",
                            isOrphaned: false,
                            conversationCount: 0,
                            conversations: []
                        ))
                    }
                }
            }
        }
        return results
    }

    // MARK: - Continue
    public static func scanContinue(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let idxPath = (home as NSString).appendingPathComponent(".continue/index/index.sqlite")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: idxPath),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            results.append(AgentDatabaseEntry(
                id: idxPath,
                editor: .continueExt,
                scope: .global,
                filePath: idxPath,
                fileName: "index.sqlite",
                storageDirectory: (idxPath as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "Continue Index Database",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }
        return results
    }

    // MARK: - Aider
    public static func scanAider(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let histPath = (home as NSString).appendingPathComponent(".aider.chat.history.md")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: histPath),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            results.append(AgentDatabaseEntry(
                id: histPath,
                editor: .aider,
                scope: .global,
                filePath: histPath,
                fileName: ".aider.chat.history.md",
                storageDirectory: home,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "Aider Conversation History",
                isOrphaned: false,
                conversationCount: 1,
                conversations: [
                    AgentConversationSummary(
                        id: histPath,
                        title: "Aider CLI Chat History",
                        createdAt: mtime,
                        mode: "aider"
                    )
                ]
            ))
        }
        return results
    }

    // MARK: - Doubao
    public static func scanDoubao(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let base = (home as NSString).appendingPathComponent("Library/Application Support/Doubao")
        let sessionsDir = (base as NSString).appendingPathComponent("Default/.doubao/agent_mode/workspace/.sessions")
        if let sessionIds = try? FileManager.default.contentsOfDirectory(atPath: sessionsDir) {
            var convSummaries: [AgentConversationSummary] = []
            var totalSessionBytes: UInt64 = 0
            var latestDate = Date.distantPast

            for sid in sessionIds where !sid.hasPrefix(".") {
                let sPath = (sessionsDir as NSString).appendingPathComponent(sid)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: sPath, isDirectory: &isDir), isDir.boolValue {
                    let attrs = (try? FileManager.default.attributesOfItem(atPath: sPath)) ?? [:]
                    let mtime = (attrs[.modificationDate] as? Date) ?? Date()
                    if mtime > latestDate { latestDate = mtime }

                    var sessionSize: UInt64 = 0
                    if let enumr = FileManager.default.enumerator(atPath: sPath) {
                        while let item = enumr.nextObject() as? String {
                            let p = (sPath as NSString).appendingPathComponent(item)
                            if let a = try? FileManager.default.attributesOfItem(atPath: p), let s = a[.size] as? UInt64 {
                                sessionSize += s
                            }
                        }
                    }
                    totalSessionBytes += sessionSize

                    var title = "豆包 Agent 会话 \(sid.prefix(8))"
                    let boardPath = (sPath as NSString).appendingPathComponent("board.md")
                    if let boardContent = try? String(contentsOfFile: boardPath, encoding: .utf8) {
                        let lines = boardContent.components(separatedBy: .newlines)
                        if let first = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                            title = String(first.prefix(60)).replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                        }
                    }

                    convSummaries.append(AgentConversationSummary(
                        id: sid,
                        title: title,
                        createdAt: mtime,
                        updatedAt: mtime,
                        mode: "agent_mode"
                    ))
                }
            }

            if !convSummaries.isEmpty {
                results.append(AgentDatabaseEntry(
                    id: sessionsDir,
                    editor: .doubao,
                    scope: .workspace,
                    filePath: sessionsDir,
                    fileName: ".sessions",
                    storageDirectory: (sessionsDir as NSString).deletingLastPathComponent,
                    fileSizeBytes: max(totalSessionBytes, 1024),
                    lastModified: latestDate == Date.distantPast ? Date() : latestDate,
                    workspacePath: nil,
                    workspaceName: "豆包智能体 会话工作区",
                    isOrphaned: false,
                    conversationCount: convSummaries.count,
                    conversations: convSummaries
                ))
            }
        }

        let dbPaths = [
            (base as NSString).appendingPathComponent("gecko_cache/gecko2.db"),
            (base as NSString).appendingPathComponent("first_party_sets.db")
        ]
        for p in dbPaths {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: p),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                results.append(AgentDatabaseEntry(
                    id: p,
                    editor: .doubao,
                    scope: .global,
                    filePath: p,
                    fileName: (p as NSString).lastPathComponent,
                    storageDirectory: (p as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "豆包缓存 (\((p as NSString).lastPathComponent))",
                    isOrphaned: false,
                    conversationCount: 0,
                    conversations: []
                ))
            }
        }
        return results
    }

    // MARK: - ChatGPT & Codex
    public static func scanChatGPT(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. Scan ~/.codex and ~/.codex/sqlite for large databases
        let codexDirs = [
            (home as NSString).appendingPathComponent(".codex"),
            (home as NSString).appendingPathComponent(".codex/sqlite")
        ]
        for dir in codexDirs {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for file in files where file.hasSuffix(".sqlite") || file.hasSuffix(".db") {
                    let fullPath = (dir as NSString).appendingPathComponent(file)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? UInt64,
                       let mtime = attrs[.modificationDate] as? Date {
                        var totalSize = size
                        let wal = fullPath + "-wal"
                        if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                           let walSize = walAttrs[.size] as? UInt64 {
                            totalSize += walSize
                        }
                        let label: String
                        if file.contains("thread_history") {
                            label = "Codex 线程历史数据库"
                        } else if file.contains("logs") {
                            label = "Codex 会话与调用日志库"
                        } else if file.contains("state") {
                            label = "Codex 运行时状态库"
                        } else {
                            label = "Codex 数据库 (\(file))"
                        }
                        results.append(AgentDatabaseEntry(
                            id: fullPath,
                            editor: .chatgpt,
                            scope: .global,
                            filePath: fullPath,
                            fileName: file,
                            storageDirectory: dir,
                            fileSizeBytes: totalSize,
                            lastModified: mtime,
                            workspacePath: nil,
                            workspaceName: label,
                            isOrphaned: false,
                            conversationCount: 0,
                            conversations: []
                        ))
                    }
                }
            }
        }

        // 2. Fallbacks for Analytics.db and Codex support dirs
        let candidatePaths = [
            (home as NSString).appendingPathComponent("Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Application Support/Software/Analytics.db")
        ]
        for path in candidatePaths {
            var st = stat()
            if path.withCString({ stat($0, &st) }) == 0 {
                let size = UInt64(st.st_size)
                let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
                results.append(AgentDatabaseEntry(
                    id: path,
                    editor: .chatgpt,
                    scope: .global,
                    filePath: path,
                    fileName: (path as NSString).lastPathComponent,
                    storageDirectory: (path as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "ChatGPT/Codex 服务数据库",
                    isOrphaned: false,
                    conversationCount: 0,
                    conversations: []
                ))
            }
        }
        return results
    }

    // MARK: - Tencent Marvis
    public static func scanMarvis(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. ~/.marvis/database/*.db
        let dotMarvis = (home as NSString).appendingPathComponent(".marvis/database")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: dotMarvis) {
            for file in files where file.hasSuffix(".db") {
                let full = (dotMarvis as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: full),
                   let size = attrs[.size] as? UInt64,
                   let mtime = attrs[.modificationDate] as? Date {
                    var total = size
                    let wal = full + "-wal"
                    if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
                       let walSize = walAttrs[.size] as? UInt64 {
                        total += walSize
                    }
                    let isVector = file.contains("vector")
                    results.append(AgentDatabaseEntry(
                        id: full,
                        editor: .marvis,
                        scope: isVector ? .vectorCache : .global,
                        filePath: full,
                        fileName: file,
                        storageDirectory: dotMarvis,
                        fileSizeBytes: total,
                        lastModified: mtime,
                        workspacePath: nil,
                        workspaceName: "Marvis 数据库 (\(file))",
                        isOrphaned: false,
                        conversationCount: 0,
                        conversations: []
                    ))
                }
            }
        }

        // 2. Library/Application Support/com.tencent.mac.marvis
        let base = (home as NSString).appendingPathComponent("Library/Application Support/com.tencent.mac.marvis")

        // 1. User conversation database (data.db) & vector databases
        let userBase = (base as NSString).appendingPathComponent("MarvisData/User")
        if let userDirs = try? FileManager.default.contentsOfDirectory(atPath: userBase) {
            for u in userDirs where !u.hasPrefix(".") {
                let dbDir = (userBase as NSString).appendingPathComponent("\(u)/database")
                let dataDb = (dbDir as NSString).appendingPathComponent("data.db")
                if let attrs = try? FileManager.default.attributesOfItem(atPath: dataDb),
                   let size = attrs[.size] as? UInt64,
                   let mtime = attrs[.modificationDate] as? Date {
                    let convs = AgentSQLiteReader.readMarvisConversations(dbPath: dataDb)
                    results.append(AgentDatabaseEntry(
                        id: dataDb,
                        editor: .marvis,
                        scope: .global,
                        filePath: dataDb,
                        fileName: "data.db",
                        storageDirectory: dbDir,
                        fileSizeBytes: size,
                        lastModified: mtime,
                        workspacePath: nil,
                        workspaceName: "腾讯云 Marvis 会话库 (\(u.prefix(8)))",
                        isOrphaned: false,
                        conversationCount: convs.count,
                        conversations: convs
                    ))
                }

                // Check vector index DBs
                let vectorDbs = ["tool_index_vector.db", "memory_vector.db", "memory.db", "business.db"]
                for v in vectorDbs {
                    let vPath = (dbDir as NSString).appendingPathComponent(v)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: vPath),
                       let size = attrs[.size] as? UInt64,
                       let mtime = attrs[.modificationDate] as? Date {
                        results.append(AgentDatabaseEntry(
                            id: vPath,
                            editor: .marvis,
                            scope: .vectorCache,
                            filePath: vPath,
                            fileName: v,
                            storageDirectory: dbDir,
                            fileSizeBytes: size,
                            lastModified: mtime,
                            workspacePath: nil,
                            workspaceName: "腾讯云 Marvis (\(v))",
                            isOrphaned: false,
                            conversationCount: 0,
                            conversations: []
                        ))
                    }
                }
            }
        }

        // 2. Knowledgebase DBs
        let kbDir = (base as NSString).appendingPathComponent("Knowledgebase/storage/database")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: kbDir) {
            for file in files where file.hasSuffix(".db") {
                let full = (kbDir as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: full),
                   let size = attrs[.size] as? UInt64,
                   let mtime = attrs[.modificationDate] as? Date {
                    results.append(AgentDatabaseEntry(
                        id: full,
                        editor: .marvis,
                        scope: .vectorCache,
                        filePath: full,
                        fileName: file,
                        storageDirectory: kbDir,
                        fileSizeBytes: size,
                        lastModified: mtime,
                        workspacePath: nil,
                        workspaceName: "腾讯云 Marvis 知识库 (\(file))",
                        isOrphaned: false,
                        conversationCount: 0,
                        conversations: []
                    ))
                }
            }
        }

        // 3. Local app info
        let legacyDbDir = (base as NSString).appendingPathComponent("db")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: legacyDbDir) {
            for file in files where file.hasSuffix(".db") || file.hasSuffix(".sqlite") {
                let full = (legacyDbDir as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: full),
                   let size = attrs[.size] as? UInt64,
                   let mtime = attrs[.modificationDate] as? Date {
                    results.append(AgentDatabaseEntry(
                        id: full,
                        editor: .marvis,
                        scope: .global,
                        filePath: full,
                        fileName: file,
                        storageDirectory: legacyDbDir,
                        fileSizeBytes: size,
                        lastModified: mtime,
                        workspacePath: nil,
                        workspaceName: "腾讯云 Marvis (\(file))",
                        isOrphaned: false,
                        conversationCount: 0,
                        conversations: []
                    ))
                }
            }
        }
        return results
    }

    // MARK: - WeChat DevTools
    public static func scanWeChatDevTools(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let base = (home as NSString).appendingPathComponent("Library/Application Support/微信开发者工具")
        guard let subdirs = try? FileManager.default.contentsOfDirectory(atPath: base) else { return [] }
        for sub in subdirs {
            let userDir = (base as NSString).appendingPathComponent("\(sub)/Default/Editor/1.78/user-data/User")
            let globalDb = (userDir as NSString).appendingPathComponent("globalStorage/state.vscdb")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: globalDb),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
                results.append(AgentDatabaseEntry(
                    id: globalDb,
                    editor: .wechatDevTools,
                    scope: .global,
                    filePath: globalDb,
                    fileName: "state.vscdb",
                    storageDirectory: (globalDb as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "微信开发者工具 全局状态",
                    isOrphaned: false,
                    conversationCount: 0,
                    conversations: []
                ))
            }

            let wsRoot = (userDir as NSString).appendingPathComponent("workspaceStorage")
            results += scanWorkspaceStorage(root: wsRoot, editor: .wechatDevTools)
        }
        return results
    }

    // MARK: - HBuilder X
    public static func scanHBuilder(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let base = (home as NSString).appendingPathComponent("Library/Application Support/HBuilder X")
        let idxDir = (base as NSString).appendingPathComponent("newIndexDb")
        if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: idxDir) {
            for sub in subdirs where !sub.hasPrefix(".") {
                let subPath = (idxDir as NSString).appendingPathComponent(sub)
                var totalSize: UInt64 = 0
                var latestDate = Date.distantPast
                if let files = try? FileManager.default.contentsOfDirectory(atPath: subPath) {
                    for file in files {
                        let fp = (subPath as NSString).appendingPathComponent(file)
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: fp),
                           let size = attrs[.size] as? UInt64,
                           let mtime = attrs[.modificationDate] as? Date {
                            totalSize += size
                            if mtime > latestDate { latestDate = mtime }
                        }
                    }
                }
                if totalSize > 0 {
                    results.append(AgentDatabaseEntry(
                        id: subPath,
                        editor: .hbuilder,
                        scope: .workspace,
                        filePath: subPath,
                        fileName: sub,
                        storageDirectory: idxDir,
                        fileSizeBytes: totalSize,
                        lastModified: latestDate == Date.distantPast ? Date() : latestDate,
                        workspacePath: nil,
                        workspaceName: "HBuilder X 索引库 (\(sub.prefix(8)))",
                        isOrphaned: false,
                        conversationCount: 0,
                        conversations: []
                    ))
                }
            }
        }
        return results
    }

    // MARK: - DeepSeek
    public static func scanDeepSeek(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let dbPath = (home as NSString).appendingPathComponent("Library/Application Support/@deepseek-ai/dsh-desktop/declarative_performance_observer.db")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            results.append(AgentDatabaseEntry(
                id: dbPath,
                editor: .deepseek,
                scope: .global,
                filePath: dbPath,
                fileName: "declarative_performance_observer.db",
                storageDirectory: (dbPath as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "DeepSeek 桌面端持久化库",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }
        return results
    }

    // MARK: - AutoClaw
    public static func scanAutoClaw(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. ~/.openclaw-autoclaw/state/openclaw.sqlite (~936 KB)
        let mainDb = (home as NSString).appendingPathComponent(".openclaw-autoclaw/state/openclaw.sqlite")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: mainDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            var total = size
            let wal = mainDb + "-wal"
            if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
               let walSize = walAttrs[.size] as? UInt64 {
                total += walSize
            }
            results.append(AgentDatabaseEntry(
                id: mainDb,
                editor: .autoClaw,
                scope: .global,
                filePath: mainDb,
                fileName: "openclaw.sqlite",
                storageDirectory: (mainDb as NSString).deletingLastPathComponent,
                fileSizeBytes: total,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "AutoClaw 核心状态数据库",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }

        // 2. Library/Application Support/autoclaw/log_sdk_v2.db
        let logDb = (home as NSString).appendingPathComponent("Library/Application Support/autoclaw/log_sdk_v2.db")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            results.append(AgentDatabaseEntry(
                id: logDb,
                editor: .autoClaw,
                scope: .global,
                filePath: logDb,
                fileName: "log_sdk_v2.db",
                storageDirectory: (logDb as NSString).deletingLastPathComponent,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "AutoClaw SDK 日志库",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }
        return results
    }

    // MARK: - CC Switch
    public static func scanCCSwitch(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []

        // 1. ~/.cc-switch/cc-switch.db (17.75 MB)
        let mainDb = (home as NSString).appendingPathComponent(".cc-switch/cc-switch.db")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: mainDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            var total = size
            let wal = mainDb + "-wal"
            if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
               let walSize = walAttrs[.size] as? UInt64 {
                total += walSize
            }
            results.append(AgentDatabaseEntry(
                id: mainDb,
                editor: .ccSwitch,
                scope: .global,
                filePath: mainDb,
                fileName: "cc-switch.db",
                storageDirectory: (mainDb as NSString).deletingLastPathComponent,
                fileSizeBytes: total,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "CC Switch 核心配置数据库",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }

        // 2. ~/.cc-switch/backups/*.db (backups ~17.5 MB each)
        let backupDir = (home as NSString).appendingPathComponent(".cc-switch/backups")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: backupDir) {
            for file in files where file.hasSuffix(".db") {
                let full = (backupDir as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: full),
                   let size = attrs[.size] as? UInt64,
                   let mtime = attrs[.modificationDate] as? Date {
                    results.append(AgentDatabaseEntry(
                        id: full,
                        editor: .ccSwitch,
                        scope: .global,
                        filePath: full,
                        fileName: file,
                        storageDirectory: backupDir,
                        fileSizeBytes: size,
                        lastModified: mtime,
                        workspacePath: nil,
                        workspaceName: "CC Switch 历史备份 (\(file))",
                        isOrphaned: false,
                        conversationCount: 0,
                        conversations: []
                    ))
                }
            }
        }
        return results
    }

    // MARK: - YDevSphere
    public static func scanYDevSphere(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let mainDb = (home as NSString).appendingPathComponent(".ydevsphere/database.sqlite")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: mainDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            var total = size
            let wal = mainDb + "-wal"
            if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
               let walSize = walAttrs[.size] as? UInt64 {
                total += walSize
            }
            results.append(AgentDatabaseEntry(
                id: mainDb,
                editor: .yDevSphere,
                scope: .global,
                filePath: mainDb,
                fileName: "database.sqlite",
                storageDirectory: (mainDb as NSString).deletingLastPathComponent,
                fileSizeBytes: total,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "YDevSphere 核心数据库",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }
        return results
    }

    // MARK: - Devin
    public static func scanDevin(home: String) -> [AgentDatabaseEntry] {
        var results: [AgentDatabaseEntry] = []
        let stateDb = (home as NSString).appendingPathComponent(".devin-shared/sharedStorage/state.vscdb")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: stateDb),
           let size = attrs[.size] as? UInt64,
           let mtime = attrs[.modificationDate] as? Date {
            var total = size
            let wal = stateDb + "-wal"
            if let walAttrs = try? FileManager.default.attributesOfItem(atPath: wal),
               let walSize = walAttrs[.size] as? UInt64 {
                total += walSize
            }
            results.append(AgentDatabaseEntry(
                id: stateDb,
                editor: .devin,
                scope: .global,
                filePath: stateDb,
                fileName: "state.vscdb",
                storageDirectory: (stateDb as NSString).deletingLastPathComponent,
                fileSizeBytes: total,
                lastModified: mtime,
                workspacePath: nil,
                workspaceName: "Devin 全局共享状态数据库",
                isOrphaned: false,
                conversationCount: 0,
                conversations: []
            ))
        }
        return results
    }

    // MARK: - Helper: WorkspaceStorage Scanner
    private static func scanWorkspaceStorage(root: String, editor: AgentEditorKind) -> [AgentDatabaseEntry] {
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }
        var list: [AgentDatabaseEntry] = []

        for dir in dirs {
            let dirPath = (root as NSString).appendingPathComponent(dir)
            let dbPath = (dirPath as NSString).appendingPathComponent("state.vscdb")

            guard let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
                  let size = attrs[.size] as? UInt64,
                  let mtime = attrs[.modificationDate] as? Date else {
                continue
            }

            let wsInfo = parseWorkspaceJson(dirPath: dirPath)
            var conversations: [AgentConversationSummary] = []
            if editor == .trae {
                conversations = AgentSQLiteReader.readTraeSessions(dbPath: dbPath)
            } else if editor == .cursor {
                conversations = AgentSQLiteReader.readCursorConversations(dbPath: dbPath)
            } else if editor == .codeBuddy {
                conversations = AgentSQLiteReader.readCodeBuddyConversations(dbPath: dbPath)
            } else if editor == .qoder {
                conversations = AgentSQLiteReader.readTraeSessions(dbPath: dbPath)
            } else if editor == .kiro {
                conversations = AgentSQLiteReader.readTraeSessions(dbPath: dbPath)
            } else {
                conversations = AgentSQLiteReader.readGenericConversations(dbPath: dbPath)
            }

            list.append(AgentDatabaseEntry(
                id: dbPath,
                editor: editor,
                scope: .workspace,
                filePath: dbPath,
                fileName: "state.vscdb",
                storageDirectory: dirPath,
                fileSizeBytes: size,
                lastModified: mtime,
                workspacePath: wsInfo.path,
                workspaceName: wsInfo.name,
                isOrphaned: wsInfo.isOrphaned,
                conversationCount: conversations.count,
                conversations: conversations
            ))
        }

        return list
    }

    // MARK: - Helper: Parse workspace.json
    public static func parseWorkspaceJson(dirPath: String) -> (path: String?, name: String, isOrphaned: Bool) {
        let jsonPath = (dirPath as NSString).appendingPathComponent("workspace.json")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, (dirPath as NSString).lastPathComponent, false)
        }

        let rawUri = (json["folder"] as? String) ?? (json["workspace"] as? String) ?? (json["configuration"] as? String)
        guard let rawUri else {
            return (nil, (dirPath as NSString).lastPathComponent, false)
        }

        var decodedPath: String?
        if let url = URL(string: rawUri), url.scheme == "file" {
            decodedPath = url.path
        } else if let unescaped = rawUri.removingPercentEncoding {
            decodedPath = unescaped.replacingOccurrences(of: "file://", with: "")
        }

        guard let path = decodedPath, !path.isEmpty else {
            return (nil, (dirPath as NSString).lastPathComponent, false)
        }

        let isOrphaned = !FileManager.default.fileExists(atPath: path)
        let name = (path as NSString).lastPathComponent
        return (path, name.isEmpty ? (dirPath as NSString).lastPathComponent : name, isOrphaned)
    }

    // MARK: - Helper: Parse Claude history
    private static func parseClaudeHistory(path: String) -> [AgentConversationSummary] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        var list: [AgentConversationSummary] = []
        var seenSessions: Set<String> = []

        let lines = content.components(separatedBy: .newlines)
        for line in lines.reversed() {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let sId = (json["sessionId"] as? String) ?? UUID().uuidString
            if seenSessions.contains(sId) { continue }
            seenSessions.insert(sId)

            let prompt = (json["display"] as? String) ?? "Prompt"
            let project = json["project"] as? String
            let ts = (json["timestamp"] as? NSNumber)?.int64Value ?? 0
            let date = ts > 0 ? Date(timeIntervalSince1970: Double(ts) / 1000.0) : nil

            list.append(AgentConversationSummary(
                id: sId,
                title: String(prompt.prefix(60)).replacingOccurrences(of: "\n", with: " "),
                createdAt: date,
                mode: "claude",
                snippet: project
            ))

            if list.count >= 50 { break }
        }

        return list
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
