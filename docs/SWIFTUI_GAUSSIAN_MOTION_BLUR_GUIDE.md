# SwiftUI 动态高斯运动模糊与转场模糊全模块复用手册
> **Pharos 团队专属指南 · 纯原生 Swift / SwiftUI 零外部依赖**

---

## 目录
1. [视觉原理与数学模型](#1-视觉原理与数学模型)
2. [全模块可复用组件库（直接复制即用）](#2-全模块可复用组件库)
   - [模板 A：数值变化驱动的动态高斯运动模糊 (`.velocityMotionBlur`)](#模板-a数值变化驱动的动态高斯运动模糊)
   - [模板 B：视图切换 / 模式平滑模糊混合 (`.blurCrossfade`)](#模板-b视图切换--模式平滑模糊混合)
   - [模板 C：高速旋转与向心残影拖尾 (`GhostTrailModifier`)](#模板-c高速旋转与向心残影拖尾)
   - [模板 D：节能与防刷降级护栏 (`EnergyMotionGuard`)](#模板-d节能与防刷降级护栏)
3. [各业务模块实战落地指南](#3-各业务模块实战落地指南)
   - [场景 1：折线图表动态更新 (`SystemTrendChart`)](#场景-1折线图表动态更新)
   - [场景 2：数据 HUD 数字跳变 (`RollingChronoText`)](#场景-2数据-hud-数字跳变)
   - [场景 3：卡片 / 面板展收与切换](#场景-3卡片--面板展收与切换)
4. [Metal / CoreAnimation 渲染性能军规](#4-metal--coreanimation-渲染性能军规)

---

## 1. 视觉原理与数学模型

### 为什么静态高斯模糊不好看，而动态运动模糊极具高级感？
- **静态模糊（Static Blur）**：仅作为背景蒙版（如毛玻璃效果），物体静止时也是糊的，缺乏生命力。
- **物理运动模糊（Velocity-Driven Motion Blur）**：模拟人眼视觉暂留（Persistence of Vision）与高速摄影机的快门曝光。
  - **加速阶段（Spool-Up）**：速度突变时，模糊半径迅速拉高；
  - **巡航阶段（Cruising）**：速度稳定时模糊适中；
  - **减速对齐（Arrival / Settle）**：逼近目标时，模糊半径严格收敛归零，恢复锐利像素。

### 动态运动模糊数学模型：二次贝塞尔 / 钟形曲线衰减
在时间归一化进程 $t \in [0.0, 1.0]$ 下，动态模糊半径 $B(t)$ 的最佳物理模型为：

$$B(t) = B_{\text{peak}} \cdot 4t(1 - t)$$

- 当 $t = 0$（起始）：$B(0) = 0$（静止清晰）
- 当 $t = 0.5$（中途峰值速度）：$B(0.5) = B_{\text{peak}}$（运动残影最强）
- 当 $t = 1.0$（终点锁定）：$B(1) = 0$（完全清晰无模糊）

其中峰值模糊半径由数据突变量 $\Delta v = |v_{\text{target}} - v_{\text{current}}|$ 动态决定：

$$B_{\text{peak}} = \text{clamp}\left(1.2, \; 4.8, \; \frac{\Delta v}{K}\right)$$

---

## 2. 全模块可复用组件库

以下代码均为**纯原生 Swift / SwiftUI 实现**，无任何第三方包依赖，符合 `AGENTS.md` 规范。建议放置在 `Sources/Pharos/UI/MotionBlurKit.swift` 中共享。

### 模板 A：数值变化驱动的动态高斯运动模糊

适用于：**仪表盘指针、实时网速吞吐、内存/CPU 用量百分比跳变**。

```swift
import SwiftUI

/// 监听任意可比较数值变化，在数值剧烈变动时激活动态高斯运动模糊，平滑衰减至清晰
public struct VelocityMotionBlurModifier<V: BinaryFloatingPoint>: ViewModifier {
    let value: V
    let sensitivity: CGFloat
    let maxBlur: CGFloat
    let isEnabled: Bool

    @State private var currentBlur: CGFloat = 0
    @State private var lastValue: V

    public init(value: V, sensitivity: CGFloat = 400.0, maxBlur: CGFloat = 4.5, isEnabled: Bool = true) {
        self.value = value
        self.sensitivity = sensitivity
        self.maxBlur = maxBlur
        self.isEnabled = isEnabled
        self._lastValue = State(initialValue: value)
    }

    public func body(content: Content) -> some View {
        content
            .blur(radius: isEnabled ? currentBlur : 0)
            .onChange(of: value) { _, newValue in
                guard isEnabled else { return }
                let delta = CGFloat(abs(newValue - lastValue))
                lastValue = newValue

                // 变化微小时不触发模糊，避免低频刷新浪费 GPU
                guard delta > 1.0 else { return }

                let peakBlur = min(maxBlur, max(1.0, delta / sensitivity))
                
                // 1. 瞬时拉起模糊
                withAnimation(.easeOut(duration: 0.10)) {
                    currentBlur = peakBlur
                }
                
                // 2. 平滑过渡回清晰
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeOut(duration: 0.32)) {
                        currentBlur = 0
                    }
                }
            }
    }
}

public extension View {
    /// 快速为视图附加数值驱动的高斯运动模糊
    func velocityMotionBlur<V: BinaryFloatingPoint>(
        for value: V,
        sensitivity: CGFloat = 400.0,
        maxBlur: CGFloat = 4.5,
        isEnabled: Bool = true
    ) -> some View {
        modifier(VelocityMotionBlurModifier(
            value: value,
            sensitivity: sensitivity,
            maxBlur: maxBlur,
            isEnabled: isEnabled
        ))
    }
}
```

---

### 模板 B：视图切换 / 模式平滑模糊混合

适用于：**标签页切换（Tabs）、模式切换（如仪表盘 ↔ 传统列表）、窗口弹窗展现**。

```swift
import SwiftUI

public struct BlurCrossfadeModifier: ViewModifier {
    let isTransitioning: Bool
    let blurRadius: CGFloat
    let scaleEffect: CGFloat

    public init(isTransitioning: Bool, blurRadius: CGFloat = 6.5, scaleEffect: CGFloat = 0.985) {
        self.isTransitioning = isTransitioning
        self.blurRadius = blurRadius
        self.scaleEffect = scaleEffect
    }

    public func body(content: Content) -> some View {
        content
            .blur(radius: isTransitioning ? blurRadius : 0)
            .scaleEffect(isTransitioning ? scaleEffect : 1.0)
            .animation(.easeInOut(duration: 0.20), value: isTransitioning)
    }
}

public extension View {
    /// 在视图重组或模式切换时提供平滑的高斯模糊缩放混合转场
    func blurCrossfade(isTransitioning: Bool, blurRadius: CGFloat = 6.5, scaleEffect: CGFloat = 0.985) -> some View {
        modifier(BlurCrossfadeModifier(
            isTransitioning: isTransitioning,
            blurRadius: blurRadius,
            scaleEffect: scaleEffect
        ))
    }
}
```

---

### 模板 C：高速旋转与向心残影拖尾

适用于：**风扇叶片旋转、雷达扫描光束、转速表指针、加载环**。

```swift
import SwiftUI

/// 空气动力学运动残影拖尾组合
public struct GhostTrailAssembly<Content: View>: View {
    let angle: Double
    let motionBlur: CGFloat
    let is3DEnabled: Bool
    let content: Content

    public init(
        angle: Double,
        motionBlur: CGFloat,
        is3DEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.angle = angle
        self.motionBlur = motionBlur
        self.is3DEnabled = is3DEnabled
        self.content = content()
    }

    public var body: some View {
        ZStack {
            // 1. 运动拖尾残影 (仅在高速运动且启用 3D 时渲染)
            if is3DEnabled && motionBlur > 0.8 {
                content
                    .opacity(0.35)
                    .blur(radius: motionBlur * 1.3)
                    .rotationEffect(.degrees(angle - (angle > 360 ? 3.5 : -3.5)), anchor: .center)
            }

            // 2. 主体视图
            content
                .blur(radius: is3DEnabled ? motionBlur * 0.7 : 0)
                .rotationEffect(.degrees(angle), anchor: .center)
        }
    }
}
```

---

### 模板 D：节能与防刷降级护栏

必须配合 macOS 系统的“减弱动态效果”以及 Pharos 的 `@AppStorage("pharos.gauge3DAcceleration")` 节能开关，保证不会无谓消耗电池能耗。

```swift
import SwiftUI
import AppKit

public struct EnergyMotionGuard {
    /// 检查系统当前是否开启了“减弱动态效果”或是否处于低能耗状态
    public static var shouldReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// 根据用户设置与系统偏好综合决定的 3D / 动态高斯模糊生效判定
    public static func isDynamicMotionEnabled(userSetting: Bool) -> Bool {
        userSetting && !shouldReduceMotion
    }
}
```

---

## 3. 各业务模块实战落地指南

### 场景 1：折线图表动态更新 (`SystemTrendChart`)

在 CPU / 内存趋势折线图插入新采样点时，让折线有极微弱的流动模糊感：
```swift
Canvas { ctx, size in
    // 绘制趋势图路径...
}
.velocityMotionBlur(
    for: Double(store.currentMemoryFraction),
    sensitivity: 0.15,
    maxBlur: 2.2,
    isEnabled: gauge3DAcceleration
)
```

### 场景 2：数据 HUD 数字跳变 (`RollingChronoText`)

避免高频刷新导致数字糊成一团，使用半强度的局部模糊增强胶片感：
```swift
Text("\(rpm)")
    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
    .blur(radius: gauge3DAcceleration ? motionBlur * 0.45 : 0)
```

### 场景 3：卡片 / 面板展收与切换

在点击展开更多参数详情时：
```swift
DisclosureGroup(isExpanded: $isExpanded) {
    DetailsView()
        .blurCrossfade(isTransitioning: isExpandingAnim)
}
```

---

## 4. Metal / CoreAnimation 渲染性能军规

> [!CAUTION] 高斯模糊的性能陷阱
> 高斯模糊属于 **多采样离屏卷积着色器计算（Multi-pass Gaussian Convolution Pass）**。如果用法不当，会造成每秒上百次 GPU 离屏渲染（Offscreen Render Passes），导致风扇起飞、电量激增。

在 Pharos 中使用高斯模糊，必须遵守以下 **5 条铁律**：

1. **绝对禁止在全屏父容器上挂模糊**
   - ❌ `WindowGroup { PopoverView().blur(...) }`（会导致整个下拉窗口重新合成）。
   - ✅ 仅对发生移动的**具体几何元素**（指针、文字、圆弧、卡片主体）添加 `.blur`。
2. **运动结束时半径必须绝对归零**
   - 模糊参数必须精准归零（`radius = 0`）。当 `radius == 0` 时，CoreGraphics / Metal 会自动绕过离屏卷积阶段，直通渲染，开销为 0。
3. **低电量与减弱动态效果自动降级**
   - 必须提供类似 `pharos.gauge3DAcceleration` 的用户显式开关，关掉时执行标准 `.spring()` 或直接跳变，零 Task / 零 Timer 开销。
4. **控制峰值模糊半径阈值**
   - 在 Retina 屏（@2x）上，`radius: 4.5` 已有极强的拖尾感，不要盲目设置到 `20` 以上，否则会导致像素采样半径成平方倍暴增。
5. **谨慎使用 `.drawingGroup()`**
   - `.drawingGroup()` 会将视图扁平化为 Metal 纹理。如果视图内包含矢量文字，可能会导致文字模糊发虚；对复杂图形（路径、Canvas）可以使用，普通 Text 视图直接使用 `.blur` 即可。
