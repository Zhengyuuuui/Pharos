# Pharos Demo App 交互式拟真维护规格 (Demo Interactive Spec)

> **目标**：全面维护 `/Applications/Pharos Demo.app` 的可交互性，确保录制时每一个点击、关闭、开启、切换动作均有真实且可闭环的反馈，绝不报错或卡死。  
> **适用环境**：录屏环境（录制前完全退出生产版 `Pharos.app`，仅运行 `Pharos Demo.app`）。

---

## 一、 录屏准备与独占运行保障

为防止生产版与 Demo 版在 macOS 状态栏产生双图标冲突，录屏启动前采用独占切换：
```bash
# 1. 彻底退出正在运行的生产版 Pharos
killall Pharos 2>/dev/null
# 2. 编译并安装最新可交互 Demo 版
make demo-install
# 3. 启动 Pharos Demo
open -a "/Applications/Pharos Demo.app"
```

---

## 二、 核心模块交互可闭环规格

### 2.1 端口与项目模块（解决“关闭端口后无法重新打开”的核心 Bug）
* **现状分析**：
  * 点击停止（Stop）时，`ProjectStore` 从运行列表中移除了该项目；
  * 但当用户在「常用项目（Favorites）」中点击绿色启动按键（Play）试图重新打开时，`WorkspaceStore.openInTerminal` 会检查目录 `FileManager.default.fileExists(atPath: fav.directory)`。由于 Demo 数据使用的是虚拟路径 `/Users/developer/Projects/...`，系统判定路径不存在，弹红框报错 `Folder missing`，导致无法重新打开。
* **拟真交互规范**：
  1. **关闭项目 (Stop)**：
     * 点击 Stop 按钮后，立即在本地将该 Mock 项目从 `store.state.projects` 移除；
     * 对应常用项目表格中的状态绿点立刻变为灰色（Not Running），同时呈现绿色的「启动 (Play)」按钮；
     * 顶部端口指标 `:3000` 动态减少。
  2. **重启项目 (Start / Play)**：
     * 在 DemoMode 下，拦截 `openInTerminal(fav)`，**跳过物理目录检查与终端脚本创建**；
     * 立即将对应的 Mock `Project`（如 `nextjs-frontend`, PID 3001, 端口 3000, 内存 184MB）重新注入 `ProjectStore.shared.state.projects`；
     * 常用项目表格状态绿点瞬间点亮为绿色，右侧重新展示 `:3000` 端口标签；
     * 顶部指标与端口柱状图平滑恢复！
  3. **效果**：支持用户反复点击【关闭】→【启动】→【关闭】→【启动】，实现完美的录屏交互循环。

---

### 2.2 状态栏与下拉 Popover 模块（MenuBar in DemoMode）
* **状态栏图标 (MenuBar Label)**：
  * 在 DemoMode 下，状态栏统一呈现真实的 `DynamicMenuBarIcon`：
    * 外径 18x18pt 仪表环（灰色底轨 + 80% 绿色进度弧）；
    * 中心翡翠绿健康指示点（`#22C55E`）；
    * 伴随文字 `80%`。
* **下拉 Popover 弹窗**：
  * 点击状态栏图标时，流畅弹出 `PopoverView`；
  * Popover 内部数据完整挂载：
    * 常用项目列表包含 `nextjs-frontend` (:3000)、`vite-react-admin` (:5173)；
    * 电池卡片显示 80% 供电旁路状态；
    * 风扇卡片显示双风扇 5,400 RPM；
    * 底部拥有设置与主界面导航按钮。

---

### 2.3 电池与 80% 充电旁路控制模块（Battery & Bypass）
* **交互规范**：
  * 用户进入「电池与温控」或在 Popover 中点击「80% 充电限制 / 旁路模式」开关：
  * **在 DemoMode 下无需提权守护进程 (`pharos-battd`)**：
    * 当用户点击开关从开启切至关闭：
      * 模式变为 `.system`；
      * 电池状态变为正在充电（`isCharging = true`），电流从 `0 mA` 变为 `+2,140 mA`；
      * 旁路高亮绿色标签优雅隐去；
    * 当用户点击开关从关闭切至开启：
      * 模式变为 `.limit(maxPercent: 80)`；
      * 电池状态变为已停止充电（`isCharging = false`），电流瞬间跳至 `0 mA`（电源直供主板，电池休眠保护）；
      * 界面弹出醒目的绿色「供电旁路已激活 (0 mA)」高亮胶囊徽章！

---

### 2.4 磁盘清理与一键回收模块（Disk Cleaner）
* **拟真清理交互规范**：
  * 打开「磁盘清理」页面，默认呈现 Pristine 扫描结果（5 项系统/开发缓存，合计 `18.6 GB` 可清理）；
  * **点击「清理 (Clean Now)」**：
    * 不触碰用户真实磁盘文件；
    * 触发优雅的模拟清理进度条（耗时约 1.2 秒平滑扫过 0% -> 100%）；
    * 18.6 GB 每一项按次序渐变缩减为 `0 B`；
    * 清理完成后弹性绽开绿色成功对勾，显示 `18.6 GB 已安全释放`；
  * **点击「重新扫描 (Rescan)」**：
    * 立即重新填充 18.6 GB 模拟数据，方便重新录制下一遍！

---

### 2.5 进程医生与高发热降温（Memory & Thermal Doctor）
* 在「系统内存」或「风扇温度」页面：
  * 点击高占用进程（如 QuickLook 守护进程 398 MB）的「结束进程 / 恢复」；
  * 列表立即执行平滑收起动画，释放内存数字实时递减。
