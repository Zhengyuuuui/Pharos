# Pharos v3.2.0 官方宣传片分镜全案与制作蓝图 (9:16 真机录屏 · 极清无损版)

> **版本**：v3.2.0 Official Promo Master Storyboard & Motion Blueprint  
> **画幅规格**：**9:16 竖屏 (1080 × 1920 @ 30fps)**，总时长精确控制在 **34.00 秒 (1020 帧)**  
> **产物命名规范**：`out/pharos-promo-v320-$(date +%Y%m%d-%H%M%S).mp4`（强制动态时间戳，防覆盖防缓存）  
> **核心资产规范**：真机 Retina 录屏素材（位于 `public/footage/`）+ 矢量动态 UI 组件  
> **视觉基调**：Apple Keynote 极简演播室（Ceramic White / 54pt 空间微距点阵 / 悬浮 macOS 拟真无损视窗）  
> **指定背景音乐**：Lvcien - `2007(2)`（124 BPM 氛围电子，无硬碰撞音，平滑贯穿 f0–f1020）

---

## 目录

1. [核心战略与升级主题定位](#一核心战略与升级主题定位)
2. [中国大陆平台政治与审核合规红线白皮书](#二中国大陆平台政治与审核合规红线白皮书)
3. [Remotion 防坑五大工程铁律](#三remotion-防坑五大工程铁律)
4. [全片 34 秒节奏编排总览 (Frame Master Timeline)](#四全片-34-秒节奏编排总览-frame-master-timeline)
5. [逐分镜视听详细工程设定 (Beat 1 – Beat 5)](#五逐分镜视听详细工程设定-beat-1--beat-5)
   - [Beat 1: 雷达初醒 · 极客基因 (f0 – f150 · 5.0s)](#beat-1-雷达初醒--极客基因-f0--f150--50s)
   - [Beat 2: 王牌 A · 应用内边缘静默自更新 (f150 – f420 · 9.0s)](#beat-2-王牌-a--应用内边缘静默自更新-f150--f420--90s)
   - [Beat 3: 王牌 B · 实例级网络直通调度与高并发探活 (f420 – f690 · 9.0s)](#beat-3-王牌-b--实例级网络直通调度与高并发探活-f420--f690--90s)
   - [Beat 4: 细节美学 · PharosSlimScroller 3.5pt 极窄浮动滚动条 (f690 – f870 · 6.0s)](#beat-4-细节美学--pharosslimscroller-35pt-极窄浮动滚动条-f690--f870--60s)
   - [Beat 5: 逆向爆发 · 终端号召与品牌印记 (f870 – f1020 · 5.0s)](#beat-5-逆向爆发--终端号召与品牌印记-f870--f1020--50s)
6. [供 Claude Code 执行的 Remotion Master Execution Prompt](#六供-claude-code-执行的-remotion-master-execution-prompt)
7. [制作交付与验收自检清单](#七制作交付与验收自检清单)

---

## 一、核心战略与升级主题定位

Pharos 经历了从基础系统监控到全能极客工作台的演进。在 v3.2.0 版本中，我们直面桌面端开源工具的两大核心死穴：**离线工具缺乏长期留存与无感维护能力**，以及**研发环境多路由切换的繁重割裂感**。

本宣传片通过紧凑的 34 秒 9:16 竖屏电影级叙事，确立以下产品认知锚点：

| 模块优先级 | 核心功能名 | 解决痛点 | 认知锚点 / 营销印记 |
| :--- | :--- | :--- | :--- |
| **核心王牌 A** | **应用内边缘静默自更新** (In-App Edge Auto Update) | 传统开源工具“下载即失联”、手动去 GitHub 找 Release 繁琐易流失 | **“一次安装，自此常新”**。Cloudflare Worker 毫秒分发、SHA-256 + CodeSign 双重验签、原子热更。 |
| **核心王牌 B** | **实例级网络直通调度与毫秒探活** (Instance Route Dispatching & Probe) | 浏览器多开多环境配置繁琐、传统级联菜单 100+ 节点卡顿崩溃 | **“直通万境，分毫不差”**。Spotlight 风格 380×430 悬浮岛、实时模糊过滤、内核级全并发探活。 |
| **细节亮点** | **PharosSlimScroller 3.5pt 极窄浮动滚动条** | 外接鼠标时 macOS 强插 15pt 粗黑底槽滚动条，严重破坏精致感 | **“纤毫毕现，视界无遮”**。3.5pt 极窄药丸、100% 透明槽位、悬浮阻尼动态微光。 |

---

## 二、中国大陆平台政治与审核合规红线白皮书

> [!CAUTION]
> **全平台审核合规最高禁令（违者下架封号）**  
> 在抖音、B站、微信视频号、小红书、微博等国内平台宣发，视频画面、代码示例、网络请求面板、字幕文案中**严禁出现任何政治与网络合规敏感词汇**。

### 1. 禁用词与合规极客术语对齐表

| 严禁出现词汇（绝对违规） | 合规极客替换表述（Apple / 研发合规风格） | 界面与文案呈现示例 |
| :--- | :--- | :--- |
| VPN / Clash / Shadow* / V2Ray / Trojan | **实例级多环境网络出口** / **直通链路** / **研发加速网关** | `实例直通链路` / `出口网关调度` |
| 科学上网 / 翻墙 / 梯子 / 代理 | **跨境研发网络加速** / **全球研发基建连通** | `跨境研发加速环境` |
| 节点 / 机场 / 订阅链接 | **网络环境出口** / **路由通道** / **可用链路** | `可用直通链路 (48)` |
| 节点测速 / Ping 节点 | **高并发链路毫秒级探活** / **双向链路往返时延遥测** | `全链路毫秒探活 (28ms)` |
| 机场域名（如 *.paofu.com 等） | **合规标准 ISO 地区码与研发集群标签** | `HK-Gateway-01`, `JP-Route-Tokyo`, `US-SiliconValley-Direct` |

### 2. 模拟真实数据规范（UI Mock Data）
视频中的 `NodePickerPopover` 列表严禁露出任何第三方商业机场名字，统一采用顶级云厂商企业级专线命名法：
- `HK-Direct-Alpha` (28ms · 香港金融专线)
- `JP-Tokyo-Cluster-02` (45ms · 东京核心节点)
- `SG-SingTel-Dedicated` (56ms · 新加坡直达通道)
- `US-SiliconValley-Fast` (128ms · 美西硅谷直连)
- `DE-Frankfurt-Peer` (142ms · 欧洲法兰克福出口)

---

## 三、Remotion 防坑五大工程铁律

为确保 Claude Code 能够一次性成功生成并无错渲染出工业级视频，所有动效代码必须严苛遵守以下防坑规范：

### 1. 严禁双重交通灯 (No Double Traffic Lights)
- **踩坑原因**：录制好的 macOS 真机 Retina 素材（如设置面板、主控制台、实例卡片）**内部已自带 macOS 原生交通灯与红黄绿三色圆点**。如果 Remotion 模板又在外层包裹包含假交通灯的“拟态 Mac 窗口外壳”，会导致画面上出现上下两套交通灯，产生严重廉价感与翻车事故。
- **强制实现**：Remotion 的 `RealWindowWrapper` **只允许做无标题栏的悬浮玻璃晶体壳**。
  ```tsx
  // ✅ 规范外壳：零外挂顶栏，零虚假红黄绿圆点
  export const RealWindowWrapper: React.FC<{ children: React.ReactNode; width?: number; height?: number }> = ({
    children,
    width = 980,
    height = 680,
  }) => (
    <div
      style={{
        width,
        height,
        borderRadius: 22,
        overflow: 'hidden',
        position: 'relative',
        boxShadow: '0 32px 80px rgba(0, 0, 0, 0.28), 0 12px 32px rgba(0, 0, 0, 0.16), 0 0 0 1px rgba(255, 255, 255, 0.14)',
        background: 'rgba(255, 255, 255, 0.05)',
        backdropFilter: 'blur(40px)',
      }}
    >
      {children}
    </div>
  );
  ```

### 2. 单视窗聚焦与连续物理移交 (Single Window Focus & Continuous Handoff)
- 舞台中央**同一时间只允许存在一个核心视窗**，杜绝多视窗层叠、焦点涣散。
- 视窗间的切换必须是具有物理连续性的位移动作：
  - **Beat 2 → Beat 3**：`Z-axis Lift & Upward Float-away`（垂直悬浮脱离并向上淡出，下个视窗以微弹簧从下方就位）。
  - **Beat 3 → Beat 4**：`Lateral Slide-out & Macro Zoom`（视窗向左侧微角度滑出，摄像机瞬间向右边缘推进 2.5 倍微距）。
  - **Beat 4 → Beat 5**：`Inward Gravitational Collapse`（全屏画面向画面绝对几何中心坍缩成 2px 光点，随后逆向回弹爆发）。

### 3. 连续平滑 BGM 与零碰撞杂音 (Continuous BGM & Zero Crash Sounds)
- **音乐文件**：统一引入 `public/audio/bgm.mp3`（Lvcien - 2007(2)）。
- **贯穿全片**：单个 `<Audio />` 组件从第 0 帧播放至第 1020 帧，严禁切断重播。
- **音量曲线**：
  - `f0 – f45`（1.5s）：平滑淡入（Volume `0.0 -> 0.75`）。
  - `f45 – f960`：恒定舒缓电音（Volume `0.75`）。
  - `f960 – f1020`（2.0s）：自然淡出（Volume `0.75 -> 0.0`）。
- **严禁碰撞硬音**：严禁加载任何重度低频撞击、铁门关闭或沉重“咚”声（如 `fs-812736.mp3`），仅允许使用轻盈的高频微鸣（Sonar Ping）、空气呼吸声（Air Swish）与触感轻敲（Key Tap）。

### 4. 强制动态时间戳产物命名 (Dynamic Timestamp Output)
所有渲染脚本必须包含动态时间戳变量，避免覆盖历史版本或因为重名导致平台缓存旧视频：
```bash
npx remotion render src/index.ts PharosPromo out/pharos-promo-v320-$(date +%Y%m%d-%H%M%S).mp4
```

### 5. 苹果中国排版工程规范 (Chinese Typography Engineering)
- **字体族栈**：`-apple-system, "SF Pro Display", "PingFang SC", "Hiragino Sans GB", "Helvetica Neue", sans-serif`。
- **字间距与光学平滑**：`letterSpacing: "-0.015em"`，副标题 `letterSpacing: "0.02em"`。
- **中文逐字动画防乱码**：严禁使用英文习惯的 `text.split(' ')`，必须强制使用 `Array.from(text)` 进行逐字分解映射，杜绝多字节 UTF-8 汉字断裂乱码。

---

## 四、全片 34 秒节奏编排总览 (Frame Master Timeline)

总帧数：**1020 帧**（30 fps，精确对应 34.00 秒）。

```
0:00       0:05.0       0:14.0              0:23.0              0:29.0       0:34.0
├──────────┼────────────┼───────────────────┼───────────────────┼────────────┤
│  Beat 1  │   Beat 2   │      Beat 3       │      Beat 4       │   Beat 5   │
│ 雷达初醒 │ 边缘自更新 │ 实例直通·毫秒探活 │ 3.5pt 极窄滚动条  │ 逆向爆发   │
│  f0–150  │  f150–420  │     f420–690      │     f690–870      │  f870–1020 │
│  (5.0s)  │   (9.0s)   │      (9.0s)       │      (6.0s)       │   (5.0s)   │
└──────────┴────────────┴───────────────────┴───────────────────┴────────────┘
```

| 分镜代号 | 帧区间 | 时长 | 视觉焦点视窗 | 核心动作与物理转场 | Apple China 标志性文案 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Beat 1** | `f0 – f150` | 5.0s | 纯净空间 / 矢量雷达 | 雷达 360° 加速扫掠，锁定 3 处目标，俯冲进入光源光幕 | **Pharos v3.2.0**<br>`自此，常新。` |
| **Beat 2** | `f150 – f420` | 9.0s | 主界面与设置视窗 (Window 1) | 侧边栏琥珀光标闪烁，边缘网关毫秒感知，双重验签原子热更 | **自此常新。**<br>`边缘网关静默就绪；双重验签，原子热更，转瞬归位。` |
| **Beat 3** | `f420 – f690` | 9.0s | 实例卡片与 Spotlight 浮岛 (Window 2) | 380×430 Spotlight 浮岛呼出，模糊速搜，全链路并发探活 | **直通万境。**<br>`Spotlight 悬浮调度台；地区速滤，全路并发，毫秒探活。` |
| **Beat 4** | `f690 – f870` | 6.0s | 滚动容器 2.5x 微距视窗 (Window 3) | 对比干掉 15pt 粗黑底槽，3.5pt 极窄药丸灵动呼吸滑动 | **纤毫毕现。**<br>`干掉 15pt 粗粝黑槽；3.5pt 浮动滚动条，视界了无遮拦。` |
| **Beat 5** | `f870 – f1020` | 5.0s | 品牌盾牌与极简终端 (Finale) | 微米光点瞬时爆发，雷达激荡同心圆，Brew 命令优雅键入 | **你的 Mac，自此了然于心。**<br>`$ brew install --cask pharos` |

---

## 五、逐分镜视听详细工程设定 (Beat 1 – Beat 5)

### Beat 1: 雷达初醒 · 极客基因 (f0 – f150 · 5.0s)

* **分镜构图与背景**：
  * 背景采用 Ceramic White（陶瓷白，`#F8F9FA`）向深邃极客灰渐变，54pt 空间几何点阵微光（Opacity 0.08）浮现。
  * 画面中心：Pharos 经典雷达扫描天线，琥珀金色光束自 `-450°` 经缓动加速扫掠至 `65°`。
  * 扫过瞬间，点阵激发出 3 处明亮回波锁定位标（对应系统遥测、网络直通、核心引擎）。
* **镜头运动公式**：
  * `f0 – f110`：摄像机缓慢推进，Scale 从 `0.92` 线性平滑插值至 `1.0`。
  * `f110 – f150`：Ease-In Expo 极速俯冲向雷达左下方物理发射光源（Emitter Lamp），Scale 从 `1.0` 急剧拉伸至 `4.8`。
  * `f135 – f150`：光源中心纯白光晕（WhiteOut）扩散膨胀，无缝揭示出下一场的主视窗。
* **Apple China 字板呈现**：
  * **主标**：`Pharos v3.2.0`（字重 700，字号 58px，琥珀渐变微光）。
  * **副标**：`自此，常新。`（字重 400，字号 28px，PingFang SC，字间距 0.04em）。
  * **英文**：`Telemetry re-engineered.`（SF Pro Display, 16px, 灰度 60%）。
* **音效设计 (Sound Design)**：
  * `f0`：BGM 平滑淡入（1.5s 柔和过渡）。
  * `f12, f74`：清澈声呐微鸣（Sonar Ping，420Hz / 840Hz 晶莹高音）。
  * `f135`：穿透空气微风呼啸（Air Swish），伴随光幕穿透。

---

### Beat 2: 王牌 A · 应用内边缘静默自更新 (f150 – f420 · 9.0s)

* **核心诉求**：攻克传统开源工具用户单向流失痛点，展现“一次安装，自此常新”的工业级自愈与升级体验。
* **分镜画面与交互还原**：
  * **视窗载体 (Window 1)**：宽 980px、高 1420px 的浮动视窗平滑滑入中央（圆角 22px，原生标题栏带真实交通灯）。
  * **动作 1 (f150 – f210)**：视窗左下角导航区，琥珀色胶囊徽标平滑闪烁：`✨ v3.2.0 已就绪`。鼠标光标自然滑至胶囊并轻触点击，无缝直达更新设置面板。
  * **动作 2 (f210 – f270)**：
    * 展示 Cloudflare Worker 边缘更新网关状态（`pharos-update.zysgm123.workers.dev` 毫秒级返回 Manifest 元数据）。
    * 界面呈现版本更新说明面板与高亮主按钮：`立即更新并重启 (Update & Restart)`。
  * **动作 3 (f270 – f370 · 极客验签流水线视效)**：
    * 点击按钮后，流式下载进度条瞬间驱动：`24.8 MB / 24.8 MB (32.4 MB/s)`，进度条在 1.2 秒内光速拉满。
    * 视窗右侧浮现轻量半透明 HUD 验签流水线气泡，绿标逐项点亮：
      1. `✓ Cloudflare Worker 边缘 300s 动态分发`
      2. `✓ CryptoKit.SHA256 双重哈希比对 (Pass)`
      3. `✓ Apple CodeSign 原生代码签名严格验证 (Valid)`
      4. `✓ Quarantine 隔离属性自动化脱附`
      5. `✓ 原子级沙盒替换与零感知拉起重启`
  * **动作 4 (f370 – f390)**：视窗轻微白光闪烁，象征完成原子热更重启，版本号稳稳变为 `v3.2.0 (Latest)`。
* **物理转场移交 (f390 – f420)**：
  * `Z-axis Lift & Upward Float-away`：Window 1 伴随真实空气阻尼向 Z 轴抬升并向上方漂移划出视界（`translateY: 0 -> -140px`，`scale: 1.0 -> 0.95`，`opacity: 1 -> 0`）。
* **Apple China 字板呈现**：
  * **四字主标**：`自此常新。`
  * **工整副标**：`边缘网关静默就绪；双重验签，原子热更，转瞬归位。`
  * **英文注脚**：`Always current. Zero friction.`
* **音效设计**：
  * `f180`：琥珀徽标点亮时的柔和泛音（Shimmer Chime）。
  * `f280 – f340`：高速数据流下载声（Digital Ticking，低分贝极细腻脉冲）。
  * `f365`：双重验签锁定的清脆微响（Double Lock Click）。

---

### Beat 3: 王牌 B · 实例级网络直通调度与高并发探活 (f420 – f690 · 9.0s)

* **核心诉求**：展现从繁重的级联菜单中解脱出来的极致操控感，合规呈现研发加速环境秒级直通与毫秒探活。
* **分镜画面与交互还原**：
  * **视窗载体 (Window 2)**：宽 980px 浏览器多实例管理控制台，由下方顺畅升起弹性复位（Spring: mass 1, damping 18）。
  * **动作 1 (f420 – f480 · 唤起 Spotlight 浮岛)**：
    * 聚焦在某个开发实例卡片（如 `Claude Code Dev Instance`）。
    * 点击出口配置，中央立刻弹现 Spotlight 风格独立悬浮窗 `NodePickerPopover`（精确尺寸 380×430，毛玻璃背景，柔和微阴影）。
  * **动作 2 (f480 – f540 · 模糊搜索与地区分片)**：
    * 顶部搜索框打字机输入 `HK`，列表在 0 延迟下瞬时从 48 条收拢至 16 条。
    * 横向轻划地区标签栏（Chips）：`全部(48)`、`HK 香港(16)`、`JP 日本(12)`、`US 美国(8)`、`SG 新加坡(12)`。标签激活时背景微晕微金。
  * **动作 3 (f540 – f630 · 内核级全并发毫秒探活)**：
    * 点击右上角刷新测速图标，圆环平滑 360° 旋转。
    * 底层并发探活触发，多条直通链路的延迟气泡在 300 毫秒内瞬间由浅灰跃迁为鲜亮翠绿：
      * `HK-Direct-Alpha`：`28ms`
      * `HK-Core-Route-02`：`36ms`
      * `JP-Tokyo-Cluster`：`45ms`
      * `SG-Dedicated-01`：`56ms`
    * 点击延迟排序开关（`Sort by Latency`），整个列表如同丝缎般重排，最低时延置顶。
  * **动作 4 (f630 – f660)**：光标果断点选 `HK-Direct-Alpha [28ms]`，Spotlight 浮岛向心轻弹关闭，实例出口徽标变为亮绿“直通连通中”。
* **物理转场移交 (f660 – f690)**：
  * `Lateral Slide-out & Macro Zoom`：Window 2 微带 3D 偏转平滑向左侧滑出（`translateX: 0 -> -160px`，`rotateY: 0 -> -4deg`），镜头同时向屏幕右侧极速推入推进 2.5x 微距特写。
* **Apple China 字板呈现**：
  * **四字主标**：`直通万境。`
  * **工整副标**：`Spotlight 悬浮调度台；地区速滤，全路并发，毫秒探活。`
  * **英文注脚**：`Direct routing. Measured in milliseconds.`
* **音效设计**：
  * `f435`：Spotlight 浮岛呼出气泡声（Soft Bubble Pop）。
  * `f490 – f510`：键盘字符键入声（Key Taps）。
  * `f550`：并发探活触发时的多频脉冲音（Multi-pulse Radar）。
  * `f635`：链路命中锁定的清脆确认声（Haptic Snap）。

---

### Beat 4: 细节美学 · PharosSlimScroller 3.5pt 极窄浮动滚动条 (f690 – f870 · 6.0s)

* **核心诉求**：用极客级细节对比，展示对 macOS 粗黑老旧控件的审美救赎，体现 Apple 级工业偏执。
* **分镜画面与交互还原**：
  * **视窗载体 (Window 3 · 2.5x 宏观微距视角)**：特写聚焦在视窗右侧内容边缘与滚动条沟槽区域。
  * **动作 1 (f690 – f750 · 震撼对比)**：
    * 画面左侧呈现反面典型：macOS 外接鼠标时的默认系统滚动条——15pt 宽度、粗笨的纯黑不透明底槽、严重遮挡右侧代码与文字。
    * 一道亮银色光学扫描线自上而下拂过（Dissolve Sweep），粗黑滚动条如同冰霜融化，瞬间蜕变升华为 `PharosSlimScroller`。
  * **动作 2 (f750 – f840 · 动态美学遥测)**：
    * 镜头展示 `PharosSlimScroller` 真实参数标注线：
      * `宽度：3.5pt 极窄悬浮药丸`
      * `沟槽：100% 完全透明，零视觉噪点`
      * `交互响应：Hover 时 Alpha 动态提亮 (0.25 -> 0.45/0.60)`
    * 界面模拟顺滑的惯性甩动滚动（Inertia Glide），3.5pt 的微光药丸随着滚动轻盈滑行，右侧文字与数据完全通透无遮。
* **物理转场移交 (f840 – f870)**：
  * `Inward Gravitational Collapse`：微距视窗迅速拉远并向屏幕几何中心发生向心重力塌缩（Ease-In Expo, Scale `1.0 -> 0.04`，Opacity `1.0 -> 0.0`），凝结成一颗凝聚着巨大能量的微米级光点。
* **Apple China 字板呈现**：
  * **四字主标**：`纤毫毕现。`
  * **工整副标**：`干掉 15pt 粗粝黑槽；3.5pt 浮动滚动条，视界了无遮拦。`
  * **英文注脚**：`Crafted to 3.5 points. Zero clutter.`
* **音效设计**：
  * `f695`：微距镜头对焦的镜片滑轨音（Optic Focus Whispers）。
  * `f750 – f810`：惯性滚动时微风拂过般的丝滑气流声（Velvet Inertia Glide）。
  * `f855`：引力坍缩时的低频聚拢微鸣（Gravitational Implosion）。

---

### Beat 5: 逆向爆发 · 终端号召与品牌印记 (f870 – f1020 · 5.0s)

* **核心诉求**：从微米奇点瞬间引爆，确立 Pharos 作为 macOS 原生终极神器的统治地位，留下清晰有力的安装命令。
* **分镜画面与交互还原**：
  * **动作 1 (f870 – f910 · 逆向爆发)**：
    * 位于屏幕中心的光点在第 870 帧瞬间释放，伴随 Ease-Out Expo 剧烈反弹（Scale `0.04 -> 1.08 -> 1.0`）。
    * 纯白浮雕质感的 Pharos 经典雷达徽标稳坐中心，向外激荡出两道同心声呐冲击波纹，光晕掠过陶瓷白演播室背景。
  * **动作 2 (f910 – f960 · 终端安装命令键入)**：
    * 徽标下方优雅浮现磨砂终端胶囊框（Dark Frosted Pill），光标闪烁，以极客打字机节奏敲入安装指令：
      ```bash
      $ brew install --cask pharos
      ```
    * 尾部敲击回车，命令下方浮现淡绿色确认小勾：`✔ Downloaded & Linked to /Applications`。
  * **动作 3 (f960 – f1020 · 品牌收束与静谧归一)**：
    * 底部浮显项目地址：`github.com/Zhengyuuuui/Pharos`。
    * 三排小字特性印记浮现：`原生 Swift 纯血构建 · 零外部依赖 · 本地隐私严苛沙盒`。
    * 背景音乐在 `f960 – f1020` 期间执行平滑淡出，画面归于纯净高雅的静谧。
* **Apple China 终局文案**：
  * **终局口号**：`你的 Mac，自此了然于心。`
  * **终端命令**：`$ brew install --cask pharos`
  * **产品规格**：`macOS 14.0+ · Apple Silicon & Intel Universal`
* **音效设计**：
  * `f872`：奇点释放的清脆声呐爆鸣（Crisp Sonar Bloom）。
  * `f910 – f945`：机械键盘敲击打字音（Mechanical Keystrokes）。
  * `f960 – f1020`：BGM 2 秒平滑淡出归零。

---

## 六、供 Claude Code 执行的 Remotion Master Execution Prompt

> [!TIP]
> **Prompt 架构师使用指南**  
> 你只需将以下代码块中的完整 Master Prompt 复制并发送给 Claude Code，即可驱动 Claude Code 在 Remotion 工程中完成精准代码生成与无试错渲染。

```markdown
# Role & Mission
You are the Lead Remotion Engineer for Pharos v3.2.0 Official Promo Video.
Your goal is to build, assemble, and render the exact 34.00s (1020 frames @ 30fps) 9:16 vertical promo video strictly following the official storyboard in `docs/PHAROS_PROMO_V320_STORYBOARD.md`.

# Anti-Pitfall Engineering Rules (STRICT ENFORCEMENT)
1. **NO DOUBLE TRAFFIC LIGHTS**: Native screen recordings in `public/footage/` ALREADY have macOS traffic lights. Your `RealWindowWrapper` component MUST ONLY be a floating glass shell (`borderRadius: 22`, subtle glow, multi-layered shadow, NO custom top header bar, NO artificial red/yellow/green dots).
2. **SINGLE WINDOW FOCUS**: At any frame between f150 and f870, EXACTLY ONE window component is in center stage. Transitions between beats must be physical handoffs (Beat 2 lift-away, Beat 3 lateral slide-out, Beat 4 inward gravitational collapse).
3. **CONTINUOUS BGM & ZERO CRASH SOUNDS**: Use `<Audio src={staticFile("audio/bgm.mp3")} />` from f0 to f1020. Volume automation: interpolate(frame, [0, 45], [0, 0.75]) for fade-in, interpolate(frame, [960, 1020], [0.75, 0]) for fade-out. Heavy crash/dong sounds (`fs-812736.mp3`) are strictly forbidden!
4. **COMPLIANCE DICTIONARY**: Zero occurrences of "VPN", "Clash", "代理", "节点", "翻墙", or commercial airport domains in code or on-screen text. Use "实例级多环境网络出口", "多环境直通链路", "高并发链路毫秒级探活", "跨境研发加速环境".
5. **CHINESE TYPOGRAPHY**: Use `fontFamily: '-apple-system, "SF Pro Display", "PingFang SC", sans-serif'`, `letterSpacing: "-0.015em"`. For text character reveal, ALWAYS use `Array.from(text).map(...)` to avoid multi-byte UTF-8 character splitting.

# Implementation Architecture

## 1. Root.tsx Composition Specification
- Composition ID: `PharosPromoV320`
- Width: `1080`
- Height: `1920`
- FPS: `30`
- DurationInFrames: `1020` (34.00s)

## 2. Frame Budget & Scene Breakdown
- `Beat 1 (f0 – f150)`: `RadarAwakening`
  - Radar sweep from -450deg to 65deg. 3 targets locked.
  - Camera ease-in expo dive into the emitter lamp (f110-f150, scale 1.0 -> 4.8).
  - Title: `Pharos v3.2.0` / Subtitle: `自此，常新。`
- `Beat 2 (f150 – f420)`: `InAppEdgeAutoUpdate`
  - Window 1 enters with soft spring. Amber pill `✨ v3.2.0 已就绪` clicks.
  - Settings panel: Cloudflare Worker edge manifest responds in 40ms.
  - One-click `立即更新并重启`: Streaming download bar fills to 100% (24.8 MB / 32 MB/s).
  - Inspection HUD callouts light up: SHA-256 Check Pass -> CodeSign Valid -> Atomic Hot Swap.
  - Handoff (f390-f420): Window 1 lifts along Z-axis and drifts up (`translateY: -140px`, opacity: 0).
  - Title: `自此常新。` / Subtitle: `边缘网关静默就绪；双重验签，原子热更，转瞬归位。`
- `Beat 3 (f420 – f690)`: `InstanceNetworkRouting`
  - Window 2 enters from bottom. Browser instance card activates route configuration.
  - Spotlight-style 380x430 floating window `NodePickerPopover` deploys with frosted glass.
  - Fuzzy search types `HK` (filtering 48 -> 16). Region chips toggle `HK 香港`, `JP 日本`, `US 美国`.
  - Concurrent millisecond ping probe triggers: spin animation, latencies turn bright green (`28ms`, `36ms`, `45ms`), instant sort.
  - Selection confirms `HK-Direct-Alpha [28ms]`, popover dismisses, route turns emerald.
  - Handoff (f660-f690): Window 2 slides laterally to left (`translateX: -160px`, `rotateY: -4deg`), camera zooms 2.5x to right edge.
  - Title: `直通万境。` / Subtitle: `Spotlight 悬浮调度台；地区速滤，全路并发，毫秒探活。`
- `Beat 4 (f690 – f870)`: `PharosSlimScrollerCraft`
  - Window 3 at 2.5x macro view.
  - Contrast morph: Chunky 15pt macOS default scrollbar melts into `PharosSlimScroller`.
  - Dynamic telemetry overlays: `3.5pt 极窄浮动药丸` + `100% 透明沟槽` + `Hover 动态提亮`.
  - Smooth inertia glide demo.
  - Handoff (f840-f870): Inward gravitational collapse into a center singularity (scale 1.0 -> 0.04).
  - Title: `纤毫毕现。` / Subtitle: `干掉 15pt 粗粝黑槽；3.5pt 浮动滚动条，视界了无遮拦。`
- `Beat 5 (f870 – f1020)`: `FinaleTerminalAndSeal`
  - Singularity explodes outward (scale 0.04 -> 1.08 -> 1.0) into Pharos Radar Emblem.
  - Dual concentric sonar shockwaves expand.
  - Monospaced terminal container types: `$ brew install --cask pharos`.
  - Footer: `github.com/Zhengyuuuui/Pharos` + `纯 Swift 纯血构建 · 零外部依赖 · 本地隐私严苛沙盒`.
  - BGM fades out smoothly between f960 and f1020.
  - Title: `你的 Mac，自此了然于心。`

## 3. Core Component Blueprint (RealWindowWrapper.tsx)
```tsx
import React from 'react';

interface RealWindowWrapperProps {
  children: React.ReactNode;
  width?: number;
  height?: number;
  style?: React.CSSProperties;
}

export const RealWindowWrapper: React.FC<RealWindowWrapperProps> = ({
  children,
  width = 980,
  height = 1420,
  style,
}) => {
  return (
    <div
      style={{
        width,
        height,
        borderRadius: 22,
        overflow: 'hidden',
        position: 'relative',
        boxShadow:
          '0 32px 80px rgba(0, 0, 0, 0.28), 0 12px 32px rgba(0, 0, 0, 0.16), 0 0 0 1px rgba(255, 255, 255, 0.14)',
        background: 'rgba(255, 255, 255, 0.05)',
        backdropFilter: 'blur(40px)',
        transformOrigin: 'center center',
        ...style,
      }}
    >
      {/* STRICT: ZERO TITLE BAR. ZERO DUPLICATE TRAFFIC LIGHTS. */}
      {children}
    </div>
  );
};
```

## 4. Typography Component (AppleTypography.tsx)
```tsx
import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';

interface AppleTypographyProps {
  title: string;
  subtitle: string;
  enText?: string;
  startFrame: number;
}

export const AppleTypography: React.FC<AppleTypographyProps> = ({
  title,
  subtitle,
  enText,
  startFrame,
}) => {
  const frame = useCurrentFrame();
  const rel = frame - startFrame;

  const opacity = interpolate(rel, [0, 15], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const translateY = interpolate(rel, [0, 15], [20, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <div
      style={{
        position: 'absolute',
        top: 140,
        left: 0,
        width: '100%',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        textAlign: 'center',
        opacity,
        transform: `translateY(${translateY}px)`,
        fontFamily: '-apple-system, "SF Pro Display", "PingFang SC", sans-serif',
        zIndex: 100,
        pointerEvents: 'none',
      }}
    >
      <h1
        style={{
          margin: 0,
          fontSize: 64,
          fontWeight: 700,
          letterSpacing: '-0.02em',
          color: '#FFFFFF',
          textShadow: '0 4px 20px rgba(0,0,0,0.4)',
        }}
      >
        {Array.from(title).map((char, i) => {
          const charOpacity = interpolate(rel - i * 1.5, [0, 8], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          });
          return (
            <span key={i} style={{ opacity: charOpacity }}>
              {char}
            </span>
          );
        })}
      </h1>
      <p
        style={{
          margin: '14px 0 0 0',
          fontSize: 26,
          fontWeight: 400,
          color: 'rgba(255, 255, 255, 0.75)',
          letterSpacing: '0.01em',
          maxWidth: 820,
          lineHeight: 1.4,
        }}
      >
        {subtitle}
      </p>
      {enText && (
        <span
          style={{
            marginTop: 8,
            fontSize: 16,
            fontWeight: 500,
            color: 'rgba(255, 255, 255, 0.45)',
            textTransform: 'uppercase',
            letterSpacing: '0.08em',
          }}
        >
          {enText}
        </span>
      )}
    </div>
  );
};
```

## 5. Render Command
Execute the render command strictly with the dynamic timestamp:
```bash
npx remotion render src/index.ts PharosPromoV320 out/pharos-promo-v320-$(date +%Y%m%d-%H%M%S).mp4
```
```

---

## 七、制作交付与验收自检清单

在宣传片渲染完成交付前，导演与动效工程师必须对照以下清单逐项勾选验收：

### 1. 审核与合规验收
- [ ] **敏感词零检出**：使用搜索工具在工程全部文件及最终渲染视频中检索 `VPN`、`Clash`、`代理`、`节点`、`翻墙`、`梯子`，确认命中数为 **0**。
- [ ] **域名合规**：界面出现的所有网络测试出口统一采用企业级专线命名法（如 `HK-Direct-Alpha`、`JP-Tokyo-Cluster`），确认未露出来历不明的商业机场域名。
- [ ] **文案对仗工整**：Beat 2 至 Beat 5 的中文大标与副标严格遵循 Apple China 四字主标 + 动宾结构副标，无口语化粗糙表达。

### 2. 视觉与动效验收
- [ ] **单视窗原则**：全片第 150 帧至第 870 帧期间，中央舞台始终仅保留**单一主视窗**，未发生多视窗混乱重叠。
- [ ] **绝无双重交通灯**：录屏素材的原生交通灯自然外露，Remotion 外层 `RealWindowWrapper` 未额外绘制多余的顶栏或红黄绿三色圆点。
- [ ] **物理转场平滑度**：Beat 2 的抬升漂移、Beat 3 的侧向滑出与微距推进、Beat 4 的向心引力坍缩、Beat 5 的奇点爆发均采用连续动能曲线（Spring / Ease-In Expo / Ease-Out Expo），无突兀瞬切。
- [ ] **滚动条特写对比**：3.5pt `PharosSlimScroller` 与 15pt macOS 粗黑滚动条的对比清晰震撼，凸显出透明槽位与呼吸微光的工业级质感。

### 3. 音频与剪辑验收
- [ ] **BGM 全片贯穿**：Lvcien - `2007(2)` 音频从 f0 平滑淡入（1.5s），并在 f960–f1020 平滑淡出（2.0s），中途无任何中断或爆音。
- [ ] **零硬碰撞音效**：全片未混入任何沉重的“咚”声碰撞音效（`fs-812736.mp3` 已彻底移除），仅保留轻盈的声呐微鸣、数据流滴答声与物理卡扣声。
- [ ] **声画卡点精确**：第 12 帧声呐雷达、第 280 帧流式下载启动、第 550 帧全并发探活绿标点亮、第 872 帧奇点引爆与音频节奏重音精准重合（误差 ≤ 2 帧）。
- [ ] **输出命名合规**：产物文件名严格包含 `$(date +%Y%m%d-%H%M%S)` 动态时间戳，已成功保存于 `out/` 目录。
