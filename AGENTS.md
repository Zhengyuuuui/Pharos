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
  （例外：`PharosCore/ProcessScanner.swift` 调用 libproc/sysctl 系统接口，
  只允许 `withUnsafe…` 作用域内借用 Swift 数组/结构体的缓冲区，不得手动分配）
- [ ] 新类型默认考虑 struct，确需 class 时无属性↔闭包强引用环
- [ ] `swift build` 通过，`make test` 全绿

## 3. 项目结构约定

- 进程/端口/内存采集只在 `Sources/PharosCore/ProcessScanner.swift`
  （libproc + sysctl，与 `lsof`/活动监视器同源），项目归组逻辑在
  `ProjectGrouper.swift`；二者纯逻辑、可单测。
- 缓存目录扫描/清理只在 `Sources/PharosCore/DiskCleaner.swift`
  （固定目标列表，按分组展示；逐文件判定，按 mtime 保留期跳过新文件，目标目录本身保留）。
- 磁盘用量（卷容量）只在 `Sources/PharosCore/DiskVolumes.swift`
  （`URLResourceValues` + DiskArbitration 只读描述，口径与 Finder 一致，十进制单位 `ByteFormat.disk`）；
  分类逻辑 `classify` 纯函数可单测。只读：不写入、不推出、不卸载任何卷。
- 纯逻辑放 `Sources/PharosCore/`，保持可被 `pharos-tests` 单测；
  Core 不得 import SwiftUI/AppKit。
- App 状态在 `Sources/Pharos/ProjectStore.swift`（窗口可见时按设置间隔轮询，不可见时 30s 低频采样以保留 1 小时内存历史）；
  磁盘清理状态在 `Sources/Pharos/CleanupStore.swift`（懒扫描：仅清理页可见时扫描）；
  UI 组件放 `Sources/Pharos/UI/`。
- **国际化**：所有 UI 文案必须走 `L10n`（`UI/L10n.swift`），同时提供
  `en` 与 `zh-Hans` 两种语言；禁止在 View 里硬编码用户可见字符串。
  视图用 `@ObservedObject private var l10n = L10n.shared` 观察以便即时切换。

## 4. 行为与安全约定

- **只读原则**：只读取当前用户自己的进程信息，不发起网络请求，不上传任何数据。
- 写操作仅限以下两类（另有「常用项目」的终端启动和「浏览器实例」的启动/退出，见下），都必须用户显式点击并二次确认：
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
- 本地通知（`Notifier.swift`，判定逻辑 `PharosCore/Alerts.swift` 可单测）：默认全部关闭，用户逐项开启；
  只用 `UNUserNotificationCenter` 本地通知；每种情况触发一次，恢复后才重新触发，不刷屏。
- 全局快捷键（`MenuBarSettings.swift`）：默认关闭，只能从固定的几个组合中选；用 Carbon
  `RegisterEventHotKey`，不需要辅助功能权限，不监听其他按键。
- 备份（`PharosCore/Backup.swift` + `BackupActions.swift`）：只读写用户在保存/打开面板中选的那个文件；
  导入只添加新条目，已有的跳过，不覆盖、不删除。
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
