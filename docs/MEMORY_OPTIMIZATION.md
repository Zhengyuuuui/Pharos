# Pharos 无损内存架构优化报告与记录 (v2.6)

**记录时间**：2026-10-17 14:25:00 +08:00  
**作者**：zys  
**优化范围**：P0–P3 无损内存优化体系（零视觉改动、零交互差异、全功能保持）

---

## 一、优化前后实测指标比对 (Apple Silicon, macOS 15.6.1)

在发布构建（Release Build）下，通过 `vmmap --summary` 与 `ps -eo pid,rss,vsz,comm` 进行物理内存实测比对：

| 关键指标 | 优化前基准 (Baseline) | 优化后实测 (Optimized) | 改善幅度 |
|---|---|---|---|
| **物理内存 (Physical Footprint)** | **106.3 MB** | **55.4 MB** | **-50.9 MB (-47.9%)** |
| **峰值物理内存 (Peak Footprint)** | **227.0 MB** | **195.2 MB** | **-31.8 MB (-14.0%)** |
| **物理常驻集 (RSS)** | **157.9 MB** | **126.2 MB** | **-31.7 MB (-20.1%)** |
| **IOSurface 窗口图层缓冲** | **27.8 MB** (15 regions) | **0 KB dirty** (13 regions) | **彻底消除 (-100%)** |
| **MALLOC_SMALL (堆小对象)** | **30.9 MB** | **13.4 MB** | **-17.5 MB (-56.6%)** |
| **CoreAnimation 脏内存** | **3.3 MB** | **896 KB** | **-2.4 MB (-73%)** |
| **自动化测试 (`make test`)** | 628 passed | **628 passed** | **零功能回归** |

---

## 二、优化项详细落地清单

### 1. P2：零堆分配与临时作用域自动释放池
- **`Sources/PharosCore/ProcessScanner.swift`**：
  - `scan()` 循环为每个 PID 遍历添加 `autoreleasepool { ... }`，每轮迭代后立即释放 C 桥接临时对象。
  - `executablePath(_:)` 与 `arguments(_:)` 使用 Swift 原生标准库零堆分配函数 `withUnsafeTemporaryAllocation(of:capacity:)` 替代原有的固定 16KB 堆数组分配，实现零堆碎片。
- **`Sources/Pharos/ProjectStore.swift`**：
  - 在后台异步任务 `Task.detached(priority: .utility)` 内部包裹 `autoreleasepool { ... }`，确保扫描与分组完成时及时排水。

### 2. P3：图标 20pt @2x 降采样与菜单栏图标百分比缓存
- **`Sources/Pharos/UI/AgentChatView.swift`**：
  - `AgentEditorIconProvider` 引入基于 `CGContext` 与 `NSBitmapImageRep` 的 `downsample(_:targetSize:)`，将系统返回的 1024x1024 巨型 App 图标重采样为标准的 40x40 (20pt @2x Retina) 位图，原图立即被 ARC 销毁，避免数十兆高清位图常驻堆中。
- **`Sources/Pharos/PharosApp.swift`**：
  - `DynamicMenuBarIcon` 引入 `(percent: Int, pressure: MemoryPressure)` 缓存键字典。在绝大多数稳定运行期间直接复用已光栅化的静态 `NSImage` 实例，杜绝了每秒生成新 drawing handler 导致的 CoreAnimation 纹理重建与内存抖动。

### 3. P1：差分拦截广播与图表休眠
- **`Sources/Pharos/ProjectStore.swift`**：
  - 维护内部独立的 `internalHistory`。在后台无弹窗（`viewers == 0`）且项目/端口集合无变化、且内存变化 `< 1%`（`abs(newFraction - oldFraction) < 0.01`）时，静默将采样点追加到历史环形队列，跳过 `@Published state` 赋值，使整个 SwiftUI 视图树彻底休眠。
- **`Sources/Pharos/UI/PopoverBlocks.swift`**：
  - 当 `store.hasViewers == false` 时，阻断 `SystemTrendChart` 和 `DevTrendChart` 的样条曲线与网格计算，后台 0% CPU 0 开销。

### 4. P0：Store 懒加载与关闭窗口缓存释放
- **`Sources/Pharos/AgentChatStore.swift`** & **`Sources/Pharos/PackageStore.swift`**：
  - 移除了 `init()` 中主动扫描 307 个 AI 数据库和 581 个 CLI 包的激进逻辑；
  - 提供 `scanIfNeeded()`，仅在用户切入对应 Tab（`.onAppear`）时才触发按需扫描。
- **`Sources/Pharos/PharosApp.swift`**：
  - 在 `windowWillClose` 中触发 `AgentChatStore.shared.releaseHeavyCache()` 与 `PackageStore.shared.releaseHeavyCache()`。在释放巨量会话文本与依赖详情的同时，保留元数据摘要（包名、路径、大小、数量），确保用户关闭窗口后重开任何界面均零闪烁、秒开呈现。
