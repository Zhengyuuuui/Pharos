# Pharos AI Agent 会话管理与数据库深度瘦身规格书
# (AI Agent Session Management & Storage Optimization Specification)

> **文档版本**：v1.0.0  
> **适用系统**：macOS 14.0+ (Sonoma / Sequoia / Tahoe)  
> **核心原则**：纯 Apple 原生 Swift 栈（零第三方依赖）、严格遵守 ARC 内存安全与 `AGENTS.md` 规范、支持商业化闭环设计。  
> **制定背景**：基于对 6 款行业领先产品（Devbroom、Caprock、AgentPeek、agentic-session-explorer、AllSessions、agent-sweep）的深度调研与解构，结合真实生产环境下 OpenCode、Cursor 等 AI 编程助手数据库暴增到 7GB+ 的极端痛点，制定本工程技术规格书。

---

## 一、需求背景与产品定位

### 1.1 痛点：AI 编码时代的“存储风暴”
随着 Claude Code、Cursor、OpenCode、Trae、Codex 等 AI 编程助手的重度使用，开发者本地存储正在面临前所未有的暴增危机：
1. **单库体积失控**：用户的 `~/.local/share/opencode/opencode.db` 在仅有 270 多个会话的情况下，物理体积飙升至 **6.5 GB**；Cursor 的 `state.vscdb` 动辄超过 **10 GB ~ 20 GB**。
2. **编辑器严重卡死**：巨型 SQLite 数据库导致编辑器启动耗时数十秒、Composer 频繁转圈死锁、内存与磁盘 I/O 长期处于高压写风暴（Write Amplification）。
3. **传统工具全面失效**：
   - CleanMyMac / 腾讯柠檬：仅能清理常规缓存文件夹，对单一 `.db` 数据库文件完全不敢动、也不会动。
   - 开发者只能在论坛四处寻找散落的 Python 脚本或手动使用 `sqlite3` 命令行敲风险极高的 `DELETE` 语句。

### 1.2 产品定位与价值主张
将 Pharos 现有的「AI 助手会话管理」板块从单纯的**元数据浏览器**，全面升级为**全球首个懂 AI Agent 数据生命周期的智能治理与无损瘦身中心**：
- **看得清**：单库表级与会话级深度剖析，一键找出占用了 80% 空间的“罪魁祸首”（流式事件表或超大快照）。
- **剪得准（独家杀手级）**：**无损事件剥离**——保留完整的会话问答文本与代码结果，仅剥离百万条中间打字渲染事件（`event`），瞬间让 6.5GB 降至 300MB。
- **能释放**：原子级前置备份 + 进程互斥保护 + 原生 `VACUUM`，实打实将物理硬盘空间归还给 macOS。
- **好迁移**：支持失效项目孤儿数据清理与工程迁移重定位。

---

## 二、六款竞品全面解构与借鉴点对照表

| 竞品 / 仓库 | 形态与技术栈 | 核心优势与我们借鉴的点 | 致命痛点与 Pharos 的超越突破 |
| :--- | :--- | :--- | :--- |
| **AgentPeek**<br>(agentpeek.app) | 闭源 Mac 原生<br>(Notch 刘海 + 菜单栏) | **轻量感知与实时审批**：利用刘海展示 Agent 状态与 Token 消耗，免切终端弹窗审批权限。借鉴其**健康状态预警**哲学。 | **完全不涉及存储与清理**。Pharos 补齐其缺失的“后端存储治理”能力。 |
| **Caprock**<br>(caprock.dev) | 桌面端 + 本地 Go 后台<br>(跨平台 + 移动端配对) | **多 Agent 统一聚合与成本感知**：并排管理 Claude Code/Codex 等会话，核算 API 成本。借鉴其**跨工具统一数据抽象**。 | **只存不消，加剧膨胀**。Caprock 强制长期保留所有原始日志，缺少针对巨型数据库的高效瘦身。Pharos 提供主动减负。 |
| **Devbroom**<br>(devbroom.com) | 闭源 Mac 独立软件<br>(原生 Swift + CLI) | **开发者安全分级体系**：将待清理目标划分为 *Ready* (安全清)、*Review* (待审查)、*Blocked* (正在占用中)。Pharos **全量吸纳该三态安全模型**。 | **停留在文件外围**。无法进入 SQLite 数据库内部做表级与字段级裁剪。Pharos 具备事务级 SQL 裁剪引擎。 |
| **`agentic-session-explorer` (`sx`)**<br>(junxit/agentic-session-explorer) | 开源终端 TUI<br>(Go / Rust) | **工程重定位与多工具漫游**：独创 Project Relocation（移动本地仓库后自动修复 Agent 关联），支持转 Markdown 导出。Pharos **吸收其项目重定位与 Markdown 归档能力**。 | **纯终端 TUI，清理只做整条会话全删**。无法做到“保留问答与代码、仅剥离流式事件”。Pharos 提供无损精简。 |
| **`AllSessions`**<br>(yuluod/AllSessions) | 开源桌面端<br>(Local-first) | **会话聚合检索**：跨工具全文检索历史会话与 Prompt 组织。借鉴其**会话卡片与搜索体验**。 | **纯阅读器**。无数据库诊断、无空间分析、无碎片整理。Pharos 具备全套空间治理链路。 |
| **`agent-sweep`**<br>(zjl1985/agent-sweep) | 开源桌面端<br>(Tauri 2 + Rust + Preact) | **安全回收至废纸篓**：会话删除时安全放入 `~/.Trash`，防止不可逆损失。Pharos **沿用操作安全防线机制**。 | **覆盖过窄**。仅支持 ChatGPT 和 Codex，不支持 OpenCode 和 Cursor 的复杂表；只做文件级删除，无 VACUUM。Pharos 补全 VACUUM 闭环。 |

---

## 三、四大核心架构与技术实现方案

```
┌────────────────────────────────────────────────────────────────────────┐
│               Pharos AI Agent Storage & Session Center                 │
│                                                                        │
│   ┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────┐  │
│   │ 1. 深度体检与剖析器  │   │ 2. 智能分级瘦身引擎  │   │3. 物理回收器│  │
│   │ (Storage Profiler)  │   │ (Lossless Compactor)│   │ (Safe Vacuum│  │
│   │ • 单库表级空间分布  │   │ • 剥离百万中间事件  │   │ • 进程互斥锁│  │
│   │ • 巨型会话排行榜    │   │ • 孤立项目清理      │   │ • 自动预备份│  │
│   │ • 空洞碎片比率检测  │   │ • 导出 Markdown 归档│   │ • 磁盘缩容  │  │
│   └─────────────────────┘   └─────────────────────┘   └─────────────┘  │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ 纯原生 Swift 驱动 (libproc / SQLite C API)
                                     ▼
        ┌─────────────────────────────────────────────────────────┐
        │  本地 AI 助手生态数据库 (23+ 款)                         │
        │  • OpenCode / MiniMax Code (~/.local/share/opencode.db) │
        │  • Cursor (~/Library/.../Cursor/globalStorage/state.vscdb│
        │  • Trae / Windsurf / VS Code / Claude Code              │
        └─────────────────────────────────────────────────────────┘
```

### 3.1 架构 1：数据库深度剖析器 (Storage Profiler)
突破传统清理工具“只看文件大小”的局限，提供**数据库内部表级与记录级透视**：
1. **表级空间拆解**：
   - OpenCode：计算 `event`（流式中间事件）、`part`（消息块）、`message`（问答元数据）、`session`（会话元数据）的实际字节大小。
   - Cursor：统计 `cursorDiskKV` 表中不同 Key 前缀（`agentKv:%`、`checkpointId:%`、`bubbleId:%`、`composerData:%`）的占比。
2. **碎片率与物理空洞探测**：
   - 通过 SQLite 原生指令 `PRAGMA freelist_count;` 和 `PRAGMA page_count;` 计算空洞率：
     $$\text{Fragmentation Ratio} = \frac{\text{freelist\_count}}{\text{page\_count}} \times 100\%$$
   - 明确告知用户：“数据库包含 4.8GB 可立即回收的物理碎片”。
3. **巨型会话排行榜 (Top Heavy Sessions)**：
   - 统计产生消息最多、引用的代码快照体积最大的 Top 10 会话，供用户单独审阅。

### 3.2 架构 2：智能分级无损瘦身引擎 (Lossless Compactor)
结合 Devbroom 的安全分级思想，设计三级可量化的瘦身梯次：

#### Level 1：无损流式事件剥离 (Lossless Stream Compaction) —— **独家核心杀手级**
- **适用对象**：OpenCode、MiniMax Code、基于 Drizzle ORM 的 Agent。
- **业务原理**：
  OpenCode 的真实对话展示只需要 `session`、`message` 和 `part` 表。而 `event` 表中 95% 以上的内容是前端打字机效果、token streaming 增量以及 sub-agent 内部中间状态（共计 90 多万行，5.25GB）。
- **裁剪逻辑**：
  ```sql
  -- 保留核心会话元数据，清空或截断历史流式事件
  DELETE FROM event WHERE type LIKE 'message.part.updated%' OR type LIKE 'session.updated%';
  ```
- **用户收益**：**所有历史会话在 OpenCode 界面中完全正常打开、代码完好如初，但数据库文件从 6.5GB 瞬间瘦身至 200MB~300MB！**

#### Level 2：影子快照与临时检查点清理 (Shadow & Checkpoints Pruning)
- **适用对象**：Cursor、Trae、VS Code 系列。
- **裁剪逻辑**：
  ```sql
  -- 清理已废弃的影子代码 Diff 与自衍生快照，保留核心聊天文本
  DELETE FROM cursorDiskKV WHERE key LIKE 'agentKv:%' OR key LIKE 'checkpointId:%';
  ```

#### Level 3：孤立工作区与超期归档 (Orphaned Workspace & Archive)
- **适用对象**：全矩阵 Agent。
- **裁剪逻辑**：
  - 检查关联的项目物理路径是否存在。若项目已从磁盘物理删除（如早前删掉的实验性 demo），判定为“幽灵会话”；
  - 归档前支持**一键导出为标准 Markdown 文档**（参考 `sx` 与 `AllSessions`），随后安全清理关联数据。

### 3.3 架构 3：安全事务闭环与物理磁盘收缩 (Safe Vacuum Engine)
为了绝对保障开发者的代码对话资产安全，瘦身流程必须执行严格的**安全防线四部曲**：

1. **步骤一：宿主进程互斥检测 (Process Exclusivity Check)**
   - 调用 PharosCore 的 `ProcessScanner` 检查目标编辑器（OpenCode / Cursor / Trae 等）是否处于运行状态。
   - 若进程存活，状态标记为 `Blocked` 并提示：“检测到 OpenCode 正在运行，请先完全退出客户端以避免数据库锁死”。
2. **步骤二：自动创建轻量安全快照 (Pre-flight Backup)**
   - 在执行任何写操作前，自动在原库同级目录建立 `.pharos_bak_<timestamp>` 备份副本（或连同 `-wal` 归档）。
   - 界面提供明显的 **「一键恢复上一次瘦身」** 入口，万无一失。
3. **步骤三：WAL 归档与事务裁剪 (WAL Checkpoint & Transactional Delete)**
   - 执行 `PRAGMA wal_checkpoint(TRUNCATE);` 将 WAL 日志合并入主库。
   - 在事务 `BEGIN IMMEDIATE; ... COMMIT;` 内执行裁剪，中途若出错自动原子回滚。
4. **步骤四：原生磁盘收缩 (Physical Disk Reclamation / VACUUM)**
   - 执行 `VACUUM;` 指令。
   - SQLite 重建整个 B-Tree，将内部几十万个 Freelist 空洞页彻底交还给 macOS APFS 文件系统。
   - 界面实时汇报：“已成功为您夺回 5.9 GB 物理磁盘空间！”

### 3.4 架构 4：项目重定位与会话迁移 (Project Relocation / Move)
- **借鉴来源**：`agentic-session-explorer` (`sx`) 的 Project Relocation。
- **解决痛点**：开发者经常将项目重命名或从 `~/Desktop` 移动到 `~/Projects`，导致 Cursor 或 OpenCode 以为是全新项目，历史对话全部丢失。
- **实现机制**：
  在 Pharos 界面中选择旧项目与新路径，一键更新 SQLite 中的 `project_directory` / `workspace` 映射表，让原本“丢失”的历史对话立刻在新路径下复活。

---

## 四、支持的主流 AI Agent 数据库特征矩阵

| AI 编程助手 | 数据库存储路径 | 典型膨胀表 / 字段 | 典型膨胀体积 | Pharos 优化手段 |
| :--- | :--- | :--- | :--- | :--- |
| **OpenCode** | `~/.local/share/opencode/opencode.db` | `event` 表 (百万行流式事件), `part` 表 | **5 GB ~ 10 GB+** | 剥离 `event` 过程事件，保留最终问答，执行 VACUUM |
| **MiniMax Code / Hub** | `~/Library/Application Support/@hilo/.../opencode.db` | `event` 表, `session_diff` 目录 | **3 GB ~ 7 GB** | 剥离事件溯源表 + 清理过时 diff 缓存 |
| **Cursor** | `~/Library/Application Support/Cursor/.../state.vscdb` | `cursorDiskKV` (`agentKv`, `checkpointId`) | **4 GB ~ 15 GB** | 精准清除影子快照与 KV 检查点，执行 VACUUM |
| **Trae** | `~/Library/Application Support/Trae/.../database.db` | `chats`, `messages`, 向量缓存 | **500 MB ~ 2 GB** | 清理失效工作区对话，精简嵌入向量缓存 |
| **Claude Code** | `~/.claude/` | `transcripts/*.jsonl`, telemetry 历史 | **1 GB ~ 4 GB** | 归档过时 JSONL 会话至压缩包，清理无用遥测 |
| **Codex CLI / App** | `~/.codex/` | 会话 SQLite 与调用日志库 | **500 MB ~ 3 GB** | 清理旧会话日志，提供废纸篓恢复保护 |

---

## 五、UI 与交互设计规范

### 5.1 界面模块布局（`AgentChatView.swift` 增强）
在现有的「AI 助手会话管理」页面中，针对单个应用卡片和详情页引入**全新的治理维度**：

1. **应用总览卡片增加健康度徽章**：
   - 正常状态：显示数据库大小（如 `32 MB`）
   - **严重膨胀状态（红色高亮）**：如检测到 `opencode.db (6.5 GB)`，显示 `[ ⚠️ 可无损瘦身 5.9 GB ]`，点击直达体检弹窗。
2. **全新「AI 数据库健康与深度瘦身」抽屉 (Storage Optimization Drawer)**：
   - **顶部健康评分与空间看板**：
     - 当前总占用：`6.5 GB`
     - 核心对话占用：`260 MB`（纯文字与代码）
     - 冗余流式事件与空洞：`6.24 GB`（可释放）
   - **一键无损瘦身主按钮 (Primary Action)**：
     - 标注文案：`一键无损精简并释放空间 (推荐)`
     - 悬停提示：*“保留所有历史问答与代码结果，仅剥离中间流式渲染事件，自动备份并释放硬盘空间。”*
   - **高级精细化清理选项 (Advanced Options)**：
     - `[✓] 自动在操作前生成安全还原点`
     - `[ ] 清理超过 30 天未打开的历史上下文`
     - `[ ] 清除已被物理删除项目的幽灵会话 (可先导出 Markdown)`
   - **瘦身完成庆祝横幅 (Success Banner)**：
     - 动态展示：`"瘦身完成！文件体积由 6.5 GB 降至 264 MB，已为您成功夺回 6.2 GB 硬盘空间！"`

---

## 六、工程代码分层与实现蓝图

遵照 `AGENTS.md` 规范，严格保证纯 Swift 栈、零第三方依赖、业务与 UI 分离：

```
Sources/
├── PharosCore/
│   ├── AgentStorageProfiler.swift    # 数据库内部表级/碎片率分析、会话排行探测 (纯逻辑、可单测)
│   ├── AgentCompactor.swift          # Level 1/2/3 裁剪逻辑，针对 OpenCode/Cursor 的 SQL 模板
│   ├── AgentVacuumEngine.swift       # 进程互斥锁、自动快照备份、事务提交与 VACUUM 释放
│   └── AgentRelocation.swift         # 项目路径移动后的会话重定向修复
│
├── Pharos/
│   ├── AgentChatStore.swift          # 扩展: @Published 属性管理各库体检结果、瘦身进行中状态与回滚
│   └── UI/
│       ├── AgentOptimizationView.swift # 深度瘦身抽屉、表级占用图表、安全备份列表
│       ├── AgentSessionExportView.swift # 类似 sx 的 Markdown 导出确认弹窗
│       └── L10n.swift                # 补充完整的中英双语本地化文案
│
└── pharos-tests/
    ├── AgentStorageProfilerTests.swift # 模拟 SQLite 数据库表分析与空洞率单测
    ├── AgentCompactorTests.swift       # 模拟 OpenCode/Cursor 裁剪与无损验证单测
    └── AgentVacuumEngineTests.swift    # 模拟自动备份与 VACUUM 流程单测
```

---

## 七、分阶段施工计划 (Roadmap)

### Phase 1：剖析器与进程互斥安全网 (核心基础)
- [ ] 在 `PharosCore` 实现 `AgentStorageProfiler`：分析 SQLite 各表字节占用、计算 `freelist` 碎片率。
- [ ] 实现 `ProcessExclusivityGuard`：利用 `ProcessScanner` 确保在动数据库前检测宿主进程，严防锁冲突。
- [ ] 编写模拟 SQLite 测试库，在 `pharos-tests` 跑通表结构分析与数据断言。

### Phase 2：OpenCode 专属无损剥离与 VACUUM 引擎 (核心破局点)
- [ ] 编写针对 OpenCode 的 `event` 表裁剪逻辑，保留 `message`/`part`/`session` 核心资产。
- [ ] 实现操作前自动创建 `.pharos_bak` 预备份机制与一键还原。
- [ ] 实现 `PRAGMA wal_checkpoint(TRUNCATE)` 与 `VACUUM` 物理释放闭环。
- [ ] 实机对 6.5GB `opencode.db` 进行端到端安全验证，确认 OpenCode 客户端打开无异常。

### Phase 3：Cursor / Trae 适配与多生态横向扩展
- [ ] 适配 Cursor `state.vscdb` 的 `cursorDiskKV` 键值裁剪（`agentKv` / `checkpointId`）。
- [ ] 适配 Claude Code `~/.claude/transcripts` 的历史 JSONL 归档。
- [ ] 引入 `sx` 风格的项目重定位 (Project Relocation) 与 Markdown 会话导出。

### Phase 4：UI 交互落地与全双语国际化
- [ ] 设计精美的健康度看板与无损瘦身抽屉视图。
- [ ] 在 `L10n.swift` 配置全套双语文案。
- [ ] 运行 `make test` 确保全量断言通过，编译 Release 版本并自检打包。

---

*（本文档归档于 `docs/AI_AGENT_STORAGE_AND_SESSION_SPEC.md`，作为 Pharos 打造全球首个“AI Agent 时代开发者数据生命周期管理中心”的技术基准。）*
