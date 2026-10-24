# Pharos 伴随式右侧微岛 (Ambient Context Rail) 规格说明书

> **文档定位**：本文档旨在指导 Pharos macOS 客户端在宽屏/全屏状态下的右侧空白区域利用方案。采用「低存在感 · 伴随式无声智能（Ambient Insights & Actions）」替代繁重的聊天框，为全屏工作流提供轻量、即时、高价值的上下文辅助。

---

## 一、 设计哲学与系统交互原则

### 1.1 核心设计理念
- **低存在感（Ambient & Non-intrusive）**：
  默认不主动抢夺视觉焦点。不使用跳动的打字动画、无弹窗气泡、无高饱和度大面积色块。
- **即看即得（Glanceable）**：
  将“对话询问”转变为“启发式结论”，省去用户的提问和打字成本，一眼扫过即可获取当前页面关键上下文。
- **纯本地极速与隐私合规（Zero-Telemetry & 100% Native）**：
  所有诊断基于本地系统扫描数据（`sysctl`、`libproc`、`IOKit` 等）通过纯 Swift 启发式逻辑推导得出。**零外部网络请求、零 API 成本、零延迟**，严格遵守项目 `AGENTS.md` 规范。

### 1.2 响应式显隐规则（Responsive Breakpoints）
- **紧凑窗口（宽度 < 1180px，如默认 1024×720）**：
  - 右侧伴随岛**完全收起（隐藏）**，不占渲染与布局资源。
  - 主内容区域（`PharosPage`）自适应占据除左侧导航岛外的全部空间。
- **宽屏/全屏（宽度 ≥ 1180px）**：
  - 右侧伴随岛以平滑过渡动画滑出，固定宽度为 **260pt**。
  - 与左侧导航岛（236pt）形成协调平衡的「双岛护航（Dual Islands）」布局。
- **用户自由控制**：
  - 顶部右上角提供微型折叠按钮（`sidebar.trailing`），用户可随时手动折叠/展开。
  - 状态持久化至 `@AppStorage("pharos.showInspector")`。

---

## 二、 视觉组件与技术架构规范

### 2.1 基础容器：`PharosInspectorIsland`
- **外形尺寸**：固定宽度 `260pt`，高度填充至窗口底部，与左侧 `sidebarIsland` 保持同等的内边距与圆角（`cornerRadius: 16`）。
- **材质背景**：使用 `PharosColor.surface`，搭配微弱描边 `PharosColor.separator.opacity(0.35)` 和柔和层叠阴影，浮岛感与系统一致。
- **内部版式结构**：
  1. **标题栏（Header）**：极简标题 + 伴随折叠按钮。
  2. **一句话状态脉搏（Ambient Pulse）**：12pt 微型字体，总结当前子页面的宏观健康状态。
  3. **洞察微卡片组（Insight Cards）**：2~3 个紧凑小块，提炼当前页面的高价值维度。
  4. **快捷行动胶囊（Action Pills）**：1~2 个上下文直达操作（如复制、定位、清理），点触即达。

### 2.2 视觉微组件规范（Design Tokens）
- **小药丸按钮（Action Pill）**：高度 `24pt`，圆角 `12pt`，淡色填充，微型图标 + 11pt 文字。
- **微型指标（Micro Metric）**：数值与单位单行排布，字体使用等宽数字 `.monospacedDigit()`。
- **状态提示点（Status Dot）**：直径 `6pt` 的呼吸光感圆点（正常为绿/蓝，提示为琥珀色，危险为珊瑚红）。

---

## 三、 11 个子页面右侧微岛详细规划

---

### 1. 仪表盘 / 端口总览 (`portsOverview`)
- **核心定位**：本地开发网络拓扑与安全防线。
- **一句话脉搏（Ambient Pulse）**：
  > “所有本地服务运行稳定；检测到 1 个服务已暴露于局域网。”
- **洞察微卡片（Insight Cards）**：
  1. **局域网连调卡（LAN Debug Station）**：
     - 自动解析本机网卡当前内网 IP（如 `192.168.1.5`）。
     - 聚合当前监听在 Web 常见端口（3000, 5173, 8080 等）的完整 URL（如 `http://192.168.1.5:3000`）。
  2. **暴露状态审计（Exposure Radar）**：
     - 区分并计数：`仅本机访问 (127.0.0.1)` vs `全网卡开放 (0.0.0.0)`。
     - 若有 `0.0.0.0` 开放，微弱琥珀色标记警示。
  3. **常用后台服务状态（Background Daemons）**：
     - 探测数据库与中间件端口（Postgres 5432, Redis 6379, MySQL 3306），显示简明常驻小绿点。
- **快捷动作胶囊（Action Pills）**：
  - `[ 复制移动端联调 URL ]`：一键复制 `http://<LAN_IP>:<Port>` 到剪贴板。

---

### 2. 系统内存 (`systemMemory`)
- **核心定位**：内存压力归因与颠簸防护。
- **一句话脉搏（Ambient Pulse）**：
  > “内存压力处于正常绿区；Swap 换页极低，系统无颠簸风险。”
- **洞察微卡片（Insight Cards）**：
  1. **领域占用归因（Domain Breakdown）**：
     - 将总用量拆解为三大领域横向进度条：`开发工具与运行时`、`浏览器生态`、`系统其他应用`。
  2. **换页与 SSD 磨损监测（Paging Activity）**：
     - 统计当前 Page-in / Page-out 活跃程度，明确提示“SSD 处于静止/轻载”或“高频换页中”。
  3. **内存单调增长观察（Trend Watch）**：
     - 标出过去 15 分钟内内存单调递增最多的 1~2 个进程，辅助排查内存泄漏。
- **快捷动作胶囊（Action Pills）**：
  - `[ 在活动监视器中查看 ]`：直达系统原生 Activity Monitor。

---

### 3. 磁盘用量 (`diskUsage`)
- **核心定位**：空间余量预测与重点目录直达。
- **一句话脉搏（Ambient Pulse）**：
  > “系统盘空间充足；外接 APFS 卷已安全挂载 3 小时。”
- **洞察微卡片（Insight Cards）**：
  1. **空间余量健康度（Runway Health）**：
     - 动态计算当前可用容量百分比，按梯队标示：充裕（>20%）、注意（10%~20%）、紧急（<10%）。
  2. **大容量集水区跳转（Quick Jumpers）**：
     - 列出本机最易膨胀的系统目录：`~/Downloads`、`~/Library/Caches`、`~/Library/Developer/Xcode`。
  3. **外接设备安全快照（External Storage）**：
     - 外接盘的格式（APFS/exFAT）、挂载路径与只读/可写属性。
- **快捷动作胶囊（Action Pills）**：
  - `[ 快速清理建议 ]`：一键跳转至「磁盘清理」页面对应项。

---

### 4. 电池与温度/风扇 (`batteryAndThermals`)
- **核心定位**：硬件能效负荷与温控裕度。
- **一句话脉搏（Ambient Pulse）**：
  > “整机功耗 9.4W，散热裕度极高；风扇目前处于静音转速。”
- **洞察微卡片（Insight Cards）**：
  1. **散热节流裕度（Thermal Headroom）**：
     - 提取最高温传感器（如 CPU MTR Temp），计算距离 100°C 保护阈值的剩余温差刻度（如 `+42°C 安全裕度`）。
  2. **实时充放电能效（Power Draw）**：
     - 实时显示电池放电功率（瓦特 W），并折算当前负载下的预计可用续航。
  3. **热节流状态（Throttling Status）**：
     - 明确指示：`未受限 (None)`，让开发者确信重负载编译未受降频影响。
- **快捷动作胶囊（Action Pills）**：
  - `[ 切换至静音/系统模式 ]`：一键微调风扇策略。

---

### 5. 包管理与依赖缓存 (`packages`)
- **核心定位**：开发依赖卫生学与磁盘膨胀预警。
- **一句话脉搏（Ambient Pulse）**：
  > “Node 生态占依赖总量 65%；发现约 1.2GB 孤儿全局包。”
- **洞察微卡片（Insight Cards）**：
  1. **包生态体积分布（Ecosystem Proportions）**：
     - 对比 `npm/pnpm/yarn`、`Homebrew`、`Cargo`、`Pip`、`CocoaPods` 的占用分布。
  2. **休眠/孤儿工具提示（Stale CLI Watch）**：
     - 提示近 90 天未使用的全局 CLI 工具数量与估算体积。
  3. **官方维护清理命令（CLI Quick Snippets）**：
     - 列出对应工具的最佳清理实践命令（如 `pnpm store prune`）。
- **快捷动作胶囊（Action Pills）**：
  - `[ 复制推荐清理指令 ]`：一键复制适用当前工具链的清理命令。

---

### 6. 浏览器多开实例 (`chrome`)
- **核心定位**：前端调试沙箱与端口隔离。
- **一句话脉搏（Ambient Pulse）**：
  > “2 个独立实例运行中，CDP 远程调试端点均已就绪。”
- **洞察微卡片（Insight Cards）**：
  1. **活跃调试端点（Active DevTools Ports）**：
     - 列出当前实例绑定的 `--remote-debugging-port`（如 `9222`, `9223`）。
  2. **沙箱隔离健康度（Sandbox Isolation）**：
     - 检查实例间 `--user-data-dir` 是否严格独立，防止多账号环境串扰。
  3. **内存占用比率（Browser Footprint）**：
     - 统计各浏览器实例包含其子渲染进程的总内存消耗。
- **快捷动作胶囊（Action Pills）**：
  - `[ 打开 DevTools 调试页 ]`：在默认浏览器一键打开 `http://127.0.0.1:<port>`。

---

### 7. AI 对话管理 (`agentChats`)
- **核心定位**：AI 辅助工程资产与上下文轻量化。
- **一句话脉搏（Ambient Pulse）**：
  > “所有编辑器数据库已验证，未发现损坏；建议备份近一周成果。”
- **洞察微卡片（Insight Cards）**：
  1. **超长会话膨胀预警（Context Bloat Watch）**：
     - 标记会话体积大于 15MB 的异常大记录（往往容易导致编辑器卡顿或 Token 消耗激增）。
  2. **各编辑器使用比重（Editor Distribution）**：
     - 展示 Cursor、Windsurf、Claude、VS Code 的会话占比微型柱条。
  3. **备份健康指标（Snapshot Freshness）**：
     - 显示上一次手动导出备份的间隔天数，提示风险级别。
- **快捷动作胶囊（Action Pills）**：
  - `[ 快速导出当前数据库 ]`：触发原生文件选择器保存 `.sqlite`。

---

### 8. 磁盘深度清理 (`diskCleanup`)
- **核心定位**：空间释放效益与清理安全感。
- **一句话脉搏（Ambient Pulse）**：
  > “清理可立即腾出 3.8GB；当前策略已开启‘安全保留期’。”
- **洞察微卡片（Insight Cards）**：
  1. **释放前后对比预演（Before & After）**：
     - 动态预览：清理后主盘占用率将从 `74.8%` 下降至 `73.5%`。
  2. **累计瘦身成就（Lifetime Space Saved）**：
     - 统计 Pharos 自安装以来累计为本机回收的 GB 空间总量。
  3. **安全准则背书（Safety Principles）**：
     - 微型文字卡片声明：只删超时文件、不删锁定句柄、不删配置与源码。
- **快捷动作胶囊（Action Pills）**：
  - `[ 一键仅清理 AI 临时文件 ]`：快速执行最高频的临时文件清理。

---

### 9. 常用项目与运行中项目详情 (`favorite(id)` / `project(id)`)
- **核心定位**：单项目运行时透视与联调跳板。
- **一句话脉搏（Ambient Pulse）**：
  > “前端服务运行良好；子进程树共消耗 380MB 内存。”
- **洞察微卡片（Insight Cards）**：
  1. **技术栈自动识别徽章（Tech Stack Fingerprint）**：
     - 解析项目文件展示微徽章：`Next.js`、`TypeScript`、`Tailwind`、`Vite` 等。
  2. **快捷访问直达（Local Jumpers）**：
     - 提取项目关联端口，生成 `localhost:port` 及 `LAN:port` 直达按钮。
  3. **进程生命周期（Process Uptime & Threads）**：
     - 显示进程已稳定运行时长（如 `1h 42m`）以及当前子线程数。
- **快捷动作胶囊（Action Pills）**：
  - `[ 在终端中重启 ]` / `[ 在 Finder 中打开根目录 ]`。

---

### 10. 菜单栏自定义 (`customize`)
- **核心定位**：信息密度评估与屏幕适配指引。
- **一句话脉搏（Ambient Pulse）**：
  > “当前布局总高度约 480pt，完美契合 13~16 寸屏幕。”
- **洞察微卡片（Insight Cards）**：
  1. **高度仪表（Density & Height Meter）**：
     - 计算已启用小组件块在 Popover 中的总像素高度，避免溢出屏幕下边缘。
  2. **布局风格推荐（Recommended Presets）**：
     - 预设一键建议：极简极速版（硬件核心）、全能开发版（端口+项目）。
  3. **性能建议（Rendering Footprint）**：
     - 评估当前排版的能耗影响（如历史折线图采样率建议）。
- **快捷动作胶囊（Action Pills）**：
  - `[ 应用极简极速预设 ]`。

---

### 11. 设置与权限诊断 (`settings`)
- **核心定位**：环境健康自检与纯净度声明。
- **一句话脉搏（Ambient Pulse）**：
  > “所有特权守护进程连接正常；本地快捷键监听生效中。”
- **洞察微卡片（Insight Cards）**：
  1. **服务通信自检（Daemon Healthcheck）**：
     - 检查 `pharos-fand` 与 `pharos-battd` 的 Socket 通信正常状态。
  2. **快捷键总表速览（Cheatsheet）**：
     - 紧凑列出唤醒菜单栏、快速刷新等快捷键。
  3. **100% 纯本地运行认证（Zero-Telemetry Seal）**：
     - 显示纯 Swift、无第三方库、无网络外连的纯净标志。
- **快捷动作胶囊（Action Pills）**：
  - `[ 重新检查守护进程连接 ]`。

---

## 四、 国际化（L10n）多语言键值规划示例

需在 `Sources/Pharos/UI/L10n.swift` 中新增对应的词条映射（保证中英双语）：

```swift
// MARK: - Inspector & Ambient Rail
var inspectorTitle: String { isZh ? "实时伴随" : "Inspector" }
var toggleInspector: String { isZh ? "折叠/展开辅助栏" : "Toggle Inspector" }
var ambientPulseTitle: String { isZh ? "环境脉搏" : "Ambient Pulse" }
var lanDebugStation: String { isZh ? "局域网联调" : "LAN Debug Station" }
var copyLanUrl: String { isZh ? "复制联调链接" : "Copy LAN URL" }
var thermalHeadroom: String { isZh ? "散热安全裕度" : "Thermal Headroom" }
var memoryAttribution: String { isZh ? "内存归因分布" : "Memory Attribution" }
var safeHarborRule: String { isZh ? "纯本地安全准则" : "Local Safety Principles" }
```

---

## 五、 实施路线建议（分阶段落地）

1. **第一阶段：骨架搭建（Architecture Scaffold）**
   - 在 `MainWindowView.swift` 中引入 `GeometryReader` 监听宽度（≥ 1180pt 判断）。
   - 编写 `PharosInspectorIsland` 基础容器，加入平滑显示/隐藏转场动画与用户折叠偏好存储。
2. **第二阶段：先锋子页面验证（Pilot Pages）**
   - 优先实现开发者最常驻留的两个核心页面：
     - `portsOverview`（局域网联调直达、暴露端口审计）
     - `systemMemory`（三大领域占比、换页颠簸监测）
3. **第三阶段：全页面铺开与打磨（Full Rollout）**
   - 依次补齐其余 9 个子页面的微卡片与动作胶囊。
   - 微调动画曲线，确保伴随栏在窗口拉伸时毫无卡顿，内存无泄漏。
