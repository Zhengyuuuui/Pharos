# AGENTS.md — Pharos 二次开发守则

> 本文件是所有 AI Agent / 人类贡献者在本仓库写代码前必须遵守的规则。
> 违反本守则的改动不予合并。

## 1. 语言与依赖约束（硬性）

- **只允许使用 Apple 原生 Swift 语言**编写全部代码（含 SwiftUI、AppKit、Foundation、
  Security 等 Apple SDK）。
- **禁止**引入任何第三方依赖：不得向 `Package.swift` 添加第三方 package，
  不得引入 C / C++ / Objective-C 源码或桥接头，不得使用 Rust/Python/JS 等
  其他语言写的插件或脚本作为运行时组成部分。
- 构建体系只使用 Swift Package Manager（`Package.swift` + `Makefile`），
  不引入 Xcode 工程文件以外的构建系统。
- 唯一例外：App 图标允许在 `Makefile` 中调用 Apple 工具链自带的 `iconutil` 与 `actool`
  （Xcode 命令行工具）编译图标资源；不得因此引入 `.xcodeproj` / `.xcworkspace`。
  `actool` 不可用时必须自动退回只打包 `.icns`，`make app` 不得因此失败。
- 原因：本项目是轻量菜单栏工具，保持纯 Swift 栈可确保：
  可审计、无供应链风险、与系统 API（ARC、Swift Concurrency）行为一致。

## 2. 内存管理守则（重点！！）

Swift 通过 **ARC（自动引用计数）** 管理内存：编译器自动插入 retain/release，
**不需要也不允许**手动 `malloc` / `free` / `dealloc` 业务逻辑。
但 ARC **无法回收循环强引用**，泄漏往往比 C/C++ 的野指针更隐蔽。写代码时必须：

### 2.1 闭包与循环引用

- 实例方法以闭包形式被长期持有（Timer、URLSession 回调、NotificationCenter、
  Combine sink、`DispatchQueue.async`）时，捕获列表**必须**写
  `[weak self]`（或生命周期可证明时 `[unowned self]`）。
  ```swift
  // ✅
  timer = Timer.scheduledTimer(withTimeInterval: s, repeats: true) { [weak self] _ in
      Task { @MainActor in await self?.refreshAll() }
  }
  // ❌ 强捕获 self → timer 持有 closure 持有 self → self 持有 timer，环
  timer = Timer.scheduledTimer(withTimeInterval: s, repeats: true) { _ in
      Task { await self.refreshAll() }
  }
  ```
- **类属性**若存储「会回调持有者」的闭包 / delegate，持有端与被持有端之间
  至少一端用 `weak`。delegate 属性一律 `weak`（遵循 Cocoa 约定）。
- `Timer` 用完必须 `invalidate()`；block-based Timer 会强捕获 target，
  失效前形成的环不会自动断开。

### 2.2 值类型优先

- **优先用 `struct` / `enum`**（值类型，无引用计数开销，天然无泄漏）。
  数据模型（如 `ProcessSnapshot`、`Project`、`ListeningPort`）一律 struct。
- `class` 仅用于需要引用语义 / 身份的场景：`ObservableObject`、
  `AppDelegate`、需要共享可变状态的单例。新建类型前先问：
  「我真的需要引用语义吗？」
- 能用 `let` 就不用 `var`；能用 `some View` / 泛型就避免类型擦除。

### 2.3 并发与生命周期

- UI 必须在 `MainActor` 上更新；后台解析用 `async/await`，不用嵌套 completion。
- `deinit` 中**禁止**触发异步等待或访问 `self` 的异步方法（对象正在销毁）。
- actor / `@MainActor` 隔离边界清晰，不滥用 `nonisolated(unsafe)` 全局可变量。
- 不持有不必要的长生命周期对象：视图用 `@State`/`@ObservedObject`，
  不为「方便」把大对象挂到单例上。

### 2.4 自检清单（提交前）

- [ ] 所有长期闭包都有 `[weak self]`（或可证明无环）
- [ ] delegate 均为 `weak`
- [ ] Timer / 通知观察者在适当生命周期移除
- [ ] 无手动 `malloc`/`free`/`UnsafeMutablePointer` 业务用法
  （例外：`PharosCore/ProcessScanner.swift` 调用 libproc/sysctl 系统接口、`PharosCore/SMC.swift` 调用 IOKit，
  以及 `pharos-fand` / `FanStore` 的 Unix socket 系统调用，
  只允许 `withUnsafe…` 作用域内借用 Swift 数组/结构体的缓冲区，不得手动分配）
- [ ] 新类型默认考虑 struct，确需 class 时无属性↔闭包强引用环
- [ ] `swift build` 通过，`make test` 全绿

## 3. 项目结构约定

- 进程/端口/内存采集只在 `Sources/PharosCore/ProcessScanner.swift`
  （libproc + sysctl，与 `lsof`/活动监视器同源），项目归组逻辑在
  `ProjectGrouper.swift`；二者纯逻辑、可单测。
- 缓存目录扫描/清理只在 `Sources/PharosCore/DiskCleaner.swift`
  （固定目标列表，按分组展示；逐文件判定，按 mtime 保留期跳过新文件，目标目录本身保留）。
- 风扇/温度读取只在 `Sources/PharosCore/SMC.swift` + `Thermals.swift`（IOKit 读 SMC，普通用户可读，非 Apple 公开接口，
  键名参考 agoodkind/macos-smc-fan 与 ThermalForge，均 MIT）；风扇安全规则 `FanPolicy.swift` 纯函数可单测。
- 磁盘用量（卷容量）只在 `Sources/PharosCore/DiskVolumes.swift`
  （`URLResourceValues` + DiskArbitration 只读描述，口径与 Finder 一致，十进制单位 `ByteFormat.disk`）；
  分类逻辑 `classify` 纯函数可单测。只读：不写入、不推出、不卸载任何卷。
- 纯逻辑放 `Sources/PharosCore/`，保持可被 `pharos-tests` 单测；
  Core 不得 import SwiftUI/AppKit。
- App 状态在 `Sources/Pharos/ProjectStore.swift`（窗口可见时按设置间隔轮询，不可见时 30s 低频采样以保留 1 小时内存历史）；
  磁盘清理状态在 `Sources/Pharos/CleanupStore.swift`（懒扫描：仅清理页可见时扫描）；
  UI 组件放 `Sources/Pharos/UI/`。
- 菜单栏下拉框由 `PopoverLayout`（Core，纯逻辑可单测）描述：每个块（`PopoverBlock`）最多出现一次，
  视图在 `UI/PopoverBlocks.swift`；「自定义」页的预览必须复用同一组块视图（保证所见即所得），且预览中块不可点击。
  新增块时：加 `PopoverBlock` case、`PopoverBlockView` 分支和 `L10n.blockName/blockDescription`。
- **国际化**：所有 UI 文案必须走 `L10n`（`UI/L10n.swift`），同时提供
  `en` 与 `zh-Hans` 两种语言；禁止在 View 里硬编码用户可见字符串。
  视图用 `@ObservedObject private var l10n = L10n.shared` 观察以便即时切换。
- **App 图标（浅色 / 深色）**：
  - 唯一来源是 `Scripts/make-icon.swift`（纯 Swift + CoreGraphics，固定随机种子，每次生成结果一致）；
    同一构图（雷达光束扫过点阵、三个捕获目标、左下光源）用两套配色输出，不手绘、不引入外部图片。
  - **深色版** = 现有图标：深海军蓝底，琥珀色光束，点阵被照亮后变暖白、发光。
  - **浅色版**：**只用白 / 灰 / 黑，不使用琥珀色或任何彩色**（每个像素 R=G=B）。背景为白 / 近白；
    点阵与扫描光点为**黑色 / 近黑**，被光束扫过的点变大、变深（用加深代替发光）；光束为半透明中灰，
    前缘为近黑细线；三个捕获目标为黑环黑芯；不使用白色光晕、白色颗粒等只在暗底上可见的效果。
    16 / 32 px 小尺寸须减少细节，保证白底上仍清晰可辨。
  - 退役的图标草稿（如带琥珀色的浅色初版）存放在 `docs/icon-archive/`，仅供参考，不参与构建。
  - 浅色为默认外观，深色为 Dark 变体。`Resources/Pharos.icns` 打包浅色版，`Resources/PharosDark.icns` 打包深色版（运行时 `AppDelegate` 监听系统深浅色切换并按需设置 `NSApp.applicationIconImage`，使 macOS 14 / 15 的 Dock 与运行态图标也能随外观切换）；深浅两版同时以 Icon Composer
    格式 `Resources/AppIcon.icon`（`icon.json` 必须仅用 `image-name-specializations` 而不写顶层 `image-name` + 浅/深两张 1024 px 全出血图层，系统自加圆角与阴影）提交，
    `make app` 用 `actool` 编译成 `Assets.car`（含 Any / Dark 两个外观）放进 `Contents/Resources`，
    `Info.plist` 同时声明 `CFBundleIconFile` 与 `CFBundleIconName`，系统按外观选择图标。
    （传统 `.appiconset` 在 macOS 上不支持 Dark 外观，actool 会丢弃深色图，不要用。）
  - 生成的 `.icns` / 图标资源提交到仓库；改图标只改 `make-icon.swift` 后执行 `make icon` 重新生成，不手改产物。
  - 不在运行时修改 `/Applications/Pharos.app` 包内任何文件（会破坏代码签名）。

## 4. 行为与安全约定

- **只读原则**：只读取当前用户自己的进程信息，不发起网络请求，不上传任何数据。
- 写操作仅限以下两类（另有「常用项目」的终端启动、「浏览器实例」的启动/退出、「AI 对话管理」的删除/备份和「风扇控制」，见下），都必须用户显式点击并二次确认：
  1. 「结束进程」：先 SIGTERM，仍存活才提供 SIGKILL；不得结束其他用户或
     PID ≤ 1 的进程，不得结束自身。
  2. 「磁盘清理」（`DiskCleaner`）：只在固定目标列表的目录内，按**单个文件**
     判断——当前用户拥有、超过保留期（mtime）、所在目录可写的**普通文件**才删；
     socket/FIFO/符号链接一律不动；删空的子目录用 `rmdir` 回收，目标目录本身保留。
     扫描与清理必须共用同一条判定（`forEachEligibleFile`），保证显示的体积就是能删的体积。
     删除失败只计数并在结果横幅中显示。不得把任意路径加入清理列表。
- 「常用项目」（`Workspaces.swift` + `WorkspaceStore.swift`）：
  - 识别启动命令只读项目文件夹内固定的几个文件（package.json、deno.json、Makefile、
    manage.py、bin/dev、compose、Cargo.toml、go.mod、Package.swift 等），不执行任何东西。
  - 从运行中进程取命令时，**不得保存内联代码**（`-e`/`-c`/`--eval` 等）、多行参数或超长命令行
    ——它们常含 token/请求头。
  - 「在终端中启动」是唯一的启动方式：只能由用户点击触发；把一个 `.command` 脚本写到
    `~/Library/Application Support/Pharos/launch/`（权限 0700）后交给用户在设置中选的终端
    （Terminal.app 默认，另支持 iTerm2 / Ghostty / Warp；打不开时回退到 Terminal.app 并提示）打开，
    进程归终端窗口所有，Pharos 不托管、不后台运行任何命令。路径和命令必须经 `ShellQuote` 转义。
  - 自动填入只用「声明式」或「入口文件」候选；`start.sh` 等 shell 脚本只列出、不自动填入；
    含 `git reset --hard`、`rm -rf`、`sudo` 等的脚本标记为危险，不提供一键设为启动命令。
- 「浏览器实例」（`ChromeInstances.swift` + `ChromeStore.swift`，历史原因沿用 Chrome 命名）：
  - 支持 `ChromiumBrowser` 中列出的 Chromium 系浏览器（Chrome / Beta / Canary、Chromium、Edge、Brave），
    只认 `/Applications/<名称>.app/Contents/MacOS/<名称>` 主程序；各浏览器有自己的默认配置文件夹；实例身份 = 浏览器 + 配置文件夹。
  - 「设置 → 浏览器」只控制显示（隐藏的浏览器不在列表中出现，预设保留）和「新建实例」默认浏览器，不改动任何浏览器。
  - 实例以 `--user-data-dir` 区分（每个文件夹只允许一个浏览器进程）；参数从进程命令行只读解析。
  - 启动：用户点击后执行 `/usr/bin/open -na "/Applications/<浏览器>.app" --args …`，参数逐个传入
    （不经过 shell）；启动前检查同一文件夹是否已在运行、调试端口是否被占用。
  - 退出：只向浏览器主进程发 SIGTERM（Chrome 正常关闭）；3 秒后仍存活才提供强制结束（SIGKILL 整个进程树）。
  - 不连接调试端口（不发 CDP 请求）；「调试列表」只是用默认浏览器打开 `http://127.0.0.1:<port>`。
- 「AI 对话管理」（`AgentChats.swift` + `AgentSQLiteReader.swift` + `AgentChatCatalog.swift` + `AgentChatStore.swift`）：
  - 读取：SQLite 一律 `SQLITE_OPEN_READONLY`，先校验文件头；每库最多读 100 条会话，只取元数据
    （标题、时间、模式、消息数、摘要），界面不展示对话正文。
  - 删除：必须经 `AgentDeletePolicy`（纯函数可单测），且在 `AgentDatabaseManager.deleteEntry` 内再判一次：
    全局库（含编辑器设置与全部会话）不提供删除；目标必须严格位于该编辑器 `knownStoragePaths()` 内
    （已知文件或已知目录的子路径），之外的副本一律不动；失效工作区只删已知工作区根目录的**直接子目录**，
    根目录本身保留；非失效库在编辑器运行时拒绝删除。需二次确认；批量清理失效项时逐条判定，
    被拒/失败只计数并在横幅显示。
  - 备份：只写到用户在保存面板中选的文件（连同 `-wal`）。
- 本地通知（`Notifier.swift`，判定逻辑 `PharosCore/Alerts.swift` 可单测）：默认全部关闭，用户逐项开启；
  只用 `UNUserNotificationCenter` 本地通知；每种情况触发一次，恢复后才重新触发，不刷屏。
- 全局快捷键（`MenuBarSettings.swift`）：默认关闭，只能从固定的几个组合中选；用 Carbon
  `RegisterEventHotKey`，不需要辅助功能权限，不监听其他按键。
- 备份（`PharosCore/Backup.swift` + `BackupActions.swift`）：只读写用户在保存/打开面板中选的那个文件；
  导入只添加新条目，已有的跳过，不覆盖、不删除。
- 风扇控制（`pharos-fand` + `FanStore.swift` + `FanPolicy.swift`）——**唯一以 root 运行的部分**：
  - 默认不安装。只有用户在「风扇与温度」页点击「安装风扇控制」并在 macOS 自带的管理员密码框中确认后，
    才把 `pharos-fand` 复制到 `/Library/PrivilegedHelperTools/local.pharos.fand`、
    写入 `/Library/LaunchDaemons/local.pharos.fand.plist` 并由 launchd 启动；Pharos 不接触密码。卸载同样走密码框。
  - 只通过 `/var/run/pharos-fand.sock`（属主为安装用户、权限 0600，并校验对端 uid）接收 `FanProtocol`
    中的固定指令（status / ping / system / max / fixed <rpm>）；不得增加任意 SMC 读写或执行命令的接口。
  - 只写风扇相关 SMC 键（`Ftst`、`F%dMd`/`F%dmd`、`F%dTg`）；目标转速限制在各风扇额定范围内。
  - 安全规则由助手自己执行、不依赖 App：任一 CPU/GPU 传感器 ≥ 95°C 强制满速，< 88°C 才解除；
    15 秒没有心跳（Pharos 退出/崩溃）即交还系统；收到 SIGTERM（卸载、关机）先交还系统再退出；
    固件拒绝手动模式时保持系统控制并提示「不支持」。
  - 默认状态与一切失败路径都回到「系统控制」。
- 配置变更需持久化，重启后生效；错误态必须有可见文案，不静默失败。

## 5. 代码风格

- 跟随现有代码风格与命名；不大面积格式化无关代码。
- 注释只写「为什么」，不写「是什么」；默认不加多余注释。
- 保持 `Package.swift` 干净：新增 target 需有明确理由。
- 版权：本项目 MIT，修改版需保留原作者版权声明（见 `LICENSE`）。

## 6. 验收命令

```sh
swift build          # 编译通过
make test            # 全部 assertions 通过（含真实端口扫描测试）
.build/debug/Pharos --check   # 打印当前项目/端口/内存（--all 含后台应用）
```
