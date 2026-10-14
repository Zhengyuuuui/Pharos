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
        case .miniMax: return ["MiniMax Code.app", "MiniMax Code 2.app"]
        case .zCode: return ["ZCode.app"]
        case .continueExt: return ["Visual Studio Code.app", "Code.app"]
        case .aider: return []
        case .doubao: return ["Doubao.app"]
        case .chatgpt: return ["ChatGPT.app", "Codex.app"]
        case .marvis: return ["Marvis.app"]
        case .wechatDevTools: return ["wechatwebdevtools.app"]
        case .hbuilder: return ["HBuilderX.app"]
        case .deepseek: return ["DeepSeek Harness.app"]
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
        case .miniMax: return ["com.minimax.agent", "com.minimax.agent.cn"]
        case .zCode: return ["dev.zcode.app"]
        case .continueExt: return ["com.microsoft.VSCode"]
        case .aider: return []
        case .doubao: return ["com.bytedance.doubao", "com.bytedance.coze"]
        case .chatgpt: return ["com.openai.chat", "com.openai.codex"]
        case .marvis: return ["com.tencent.mac.marvis"]
        case .wechatDevTools: return ["com.tencent.wechat.devtools"]
        case .hbuilder: return ["com.dcloud.HBuilderX"]
        case .deepseek: return ["com.deepseek.harness"]
        }
    }

    public var installedAppPath: String? {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        for name in appNames {
            let p1 = "/Applications/\(name)"
            if fm.fileExists(atPath: p1) { return p1 }
            let p2 = "\(home)/Applications/\(name)"
            if fm.fileExists(atPath: p2) { return p2 }
            let p3 = "/System/Applications/\(name)"
            if fm.fileExists(atPath: p3) { return p3 }
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
                AgentKnownPath(label: "智能体对话汇总数据库", fullPath: "\(home)/.gemini/antigravity/conversation_summaries.db", scope: .global),
                AgentKnownPath(label: "Antigravity 数据根目录", fullPath: "\(home)/.gemini/antigravity", scope: .global, isDirectory: true)
            ]
        case .qoder:
            return [
                AgentKnownPath(label: "Qoder CN 对话本地数据库", fullPath: "\(home)/Library/Application Support/QoderCN/SharedClientCache/cache/db/local.db", scope: .global),
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
                AgentKnownPath(label: "WorkBuddy 应用主目录", fullPath: "\(home)/Library/Application Support/com.tencent.workbuddy.mac", scope: .global, isDirectory: true),
                AgentKnownPath(label: "WorkBuddy AI 存储目录", fullPath: "\(home)/Library/Application Support/WorkBuddy AI", scope: .global, isDirectory: true)
            ]
        case .miniMax:
            return [
                AgentKnownPath(label: "MiniMax Code 核心对话数据库", fullPath: "\(home)/Library/Application Support/@hilo/MiniMax Hub Global/ai-runtime/data-home/opencode/opencode.db", scope: .global),
                AgentKnownPath(label: "MiniMax Code 运行时数据目录", fullPath: "\(home)/Library/Application Support/@hilo/MiniMax Hub Global/ai-runtime/data-home/opencode", scope: .global, isDirectory: true),
                AgentKnownPath(label: "MiniMax Agent 配置目录", fullPath: "\(home)/Library/Application Support/MiniMax Agent", scope: .global, isDirectory: true)
            ]
        case .zCode:
            return [
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
                AgentKnownPath(label: "ChatGPT/Codex 服务数据库", fullPath: "\(home)/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Application Support/Software/Analytics.db", scope: .global),
                AgentKnownPath(label: "OpenAI Codex 支持目录", fullPath: "\(home)/Library/Application Support/com.openai.codex", scope: .global, isDirectory: true),
                AgentKnownPath(label: "OpenAI 主配置目录", fullPath: "\(home)/Library/Application Support/OpenAI", scope: .global, isDirectory: true)
            ]
        case .marvis:
            return [
                AgentKnownPath(label: "腾讯云 Marvis 用户会话数据库", fullPath: "\(home)/Library/Application Support/com.tencent.mac.marvis/MarvisData/User", scope: .global, isDirectory: true),
                AgentKnownPath(label: "腾讯云 Marvis 本地应用数据库", fullPath: "\(home)/Library/Application Support/com.tencent.mac.marvis/db/local_app_info.db", scope: .global),
                AgentKnownPath(label: "腾讯云 Marvis 状态持久化库", fullPath: "\(home)/Library/Application Support/com.tencent.mac.marvis/db/persist.db", scope: .global),
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
        conversations: [AgentConversationSummary] = []
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
    }
}

public enum AgentScanner {
    /// Scans all supported local AI agent editors for conversation databases.
    public static func scan(homeDirectory: String = NSHomeDirectory()) -> [AgentDatabaseEntry] {
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

        // Sort by file size descending
        return entries.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
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
        let dbPath = (home as NSString).appendingPathComponent(".gemini/antigravity/conversation_summaries.db")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
              let size = attrs[.size] as? UInt64,
              let mtime = attrs[.modificationDate] as? Date else {
            return []
        }
        let convs = AgentSQLiteReader.readAntigravityConversations(dbPath: dbPath)
        return [AgentDatabaseEntry(
            id: dbPath,
            editor: .antigravity,
            scope: .global,
            filePath: dbPath,
            fileName: "conversation_summaries.db",
            storageDirectory: (dbPath as NSString).deletingLastPathComponent,
            fileSizeBytes: size,
            lastModified: mtime,
            workspacePath: nil,
            workspaceName: "Antigravity Agent Sessions",
            isOrphaned: false,
            conversationCount: convs.count,
            conversations: convs
        )]
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
                let convs = AgentSQLiteReader.readQoderConversations(dbPath: localDb)
                results.append(AgentDatabaseEntry(
                    id: localDb,
                    editor: .qoder,
                    scope: .global,
                    filePath: localDb,
                    fileName: "local.db",
                    storageDirectory: (localDb as NSString).deletingLastPathComponent,
                    fileSizeBytes: size,
                    lastModified: mtime,
                    workspacePath: nil,
                    workspaceName: "\(variant) Chat Sessions",
                    isOrphaned: false,
                    conversationCount: convs.count,
                    conversations: convs
                ))
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
        let candidatePaths = [
            (home as NSString).appendingPathComponent("Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Application Support/Software/Analytics.db"),
            (home as NSString).appendingPathComponent("Library/Application Support/com.openai.codex/production-appcast-bootstrap.json"),
            (home as NSString).appendingPathComponent("Library/Application Support/OpenAI/Codex/chrome-native-hosts.json")
        ]
        for path in candidatePaths {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? UInt64,
               let mtime = attrs[.modificationDate] as? Date {
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
                    workspaceName: "ChatGPT/Codex (\((path as NSString).lastPathComponent))",
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
    /// Safely deletes a database entry.
    /// If it is an orphaned workspace, removes the entire workspaceStorage directory.
    public static func deleteEntry(_ entry: AgentDatabaseEntry) throws {
        let fm = FileManager.default
        if entry.isOrphaned && entry.scope == .workspace {
            if fm.fileExists(atPath: entry.storageDirectory) {
                try fm.removeItem(atPath: entry.storageDirectory)
                return
            }
        }

        // Delete primary file
        if fm.fileExists(atPath: entry.filePath) {
            try fm.removeItem(atPath: entry.filePath)
        }

        // Delete associated SQLite WAL/SHM/journal files if they exist
        let wal = entry.filePath + "-wal"
        let shm = entry.filePath + "-shm"
        let journal = entry.filePath + "-journal"
        if fm.fileExists(atPath: wal) { try? fm.removeItem(atPath: wal) }
        if fm.fileExists(atPath: shm) { try? fm.removeItem(atPath: shm) }
        if fm.fileExists(atPath: journal) { try? fm.removeItem(atPath: journal) }
    }

    /// Cleans all orphaned workspace entries, returning the number of cleaned items and total bytes freed.
    public static func cleanOrphanedEntries(_ entries: [AgentDatabaseEntry]) throws -> (count: Int, bytesFreed: UInt64) {
        var count = 0
        var freed: UInt64 = 0

        for entry in entries where entry.isOrphaned {
            let size = entry.fileSizeBytes
            try deleteEntry(entry)
            count += 1
            freed += size
        }

        return (count, freed)
    }

    /// Creates a timestamped backup of the database in the target directory.
    public static func backupEntry(_ entry: AgentDatabaseEntry, toDirectory destDir: URL) throws -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: destDir.path) {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: Date())
        let safeName = entry.workspaceName.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
        let ext = (entry.fileName as NSString).pathExtension.isEmpty ? "db" : (entry.fileName as NSString).pathExtension
        let backupFileName = "\(entry.editor.rawValue)_\(safeName)_\(stamp).\(ext)"
        let targetURL = destDir.appendingPathComponent(backupFileName)

        try fm.copyItem(at: URL(fileURLWithPath: entry.filePath), to: targetURL)

        // Also copy wal / shm if they exist
        let walPath = entry.filePath + "-wal"
        if fm.fileExists(atPath: walPath) {
            let walDest = destDir.appendingPathComponent(backupFileName + "-wal")
            try? fm.copyItem(at: URL(fileURLWithPath: walPath), to: walDest)
        }

        return targetURL
    }
}
