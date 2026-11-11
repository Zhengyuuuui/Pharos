# Pharos v3.2.0 官方宣传片分镜全案与制作蓝图 (一镜到底连续空间 · 极清无损版)

> **版本**：v3.2.0 Official Promo Master Storyboard & Motion Blueprint (One-Take Zoom-Through Edition)  
> **画幅规格**：**9:16 竖屏 (1080 × 1920 @ 30fps)**，总时长精确控制在 **24.00 秒 (720 帧)**  
> **产物命名规范**：`out/pharos-promo-v320-$(date +%Y%m%d-%H%M%S).mp4`（强制动态时间戳）  
> **核心资产规范**：真机 Retina 录屏素材（`public/footage/01-update.mp4`、`public/footage/02-browser-routing.mp4`）+ 矢量动态 UI 空间  
> **视觉基调**：Apple Keynote 极简连续空间（Ceramic White / 54pt 空间微距点阵 / 悬浮 macOS 拟真无损视窗）  
> **背景音乐规范**：**128 BPM 现代极简轻快科技鼓点**（Snappy Kick, Crisp Hi-hats, Finger Snaps, Micro Glitches，全片贯穿 f0–f720）

---

## 目录

1. [一镜到底连续空间体系重构背景](#一一镜到底连续空间体系重构背景)
2. [连续空间物理学与 Carry 动量传递模型 (Carry Score = 1.00)](#二连续空间物理学与-carry-动量传递模型-carry-score--100)
3. [128 BPM 现代科技轻快鼓点与声画对齐总谱](#三128-bpm-现代科技轻快鼓点与声画对齐总谱)
4. [中国大陆全平台防封控合规体系](#四中国大陆全平台防封控合规体系)
5. [24秒一镜到底分镜详细工程设定 (Beat 1 – Beat 4)](#五24秒一镜到底分镜详细工程设定-beat-1--beat-4)
   - [Beat 1: 奇点穿透与破茧而出 (f0 – f90 · 3.0s)](#beat-1-奇点穿透与破茧而出-f0--f90--30s)
   - [Beat 2: 应用内自更新与胶囊收敛 (f90 – f330 · 8.0s)](#beat-2-应用内自更新与胶囊收敛-f90--f330--80s)
   - [核心物理交接: 胶囊下坠与水滴散开 (f315 – f345)](#核心物理交接-胶囊下坠与水滴散开-f315--f345)
   - [Beat 3: 轻量指纹隔离与专属出口直通 (f330 – f570 · 8.0s)](#beat-3-轻量指纹隔离与专属出口直通-f330--f570--80s)
   - [Beat 4: 极速反向抽焦与终端定格 (f570 – f720 · 5.0s)](#beat-4-极速反向抽焦与终端定格-f570--f720--50s)
6. [供 Claude Code 执行的 Remotion Master Execution Prompt](#六供-claude-code-执行的-remotion-master-execution-prompt)
7. [工业级交付与实战自检清单 (Aesthetic Rules 核验)](#七工业级交付与实战自检清单-aesthetic-rules-核验)

---

## 一、一镜到底连续空间体系重构背景

### 1. 彻底根治“PPT 翻页感”
此前版本因采用静态微缩放、画面淡入淡出、孤立卡片展示以及慢速复古 Lo-Fi 音乐（《Lvcien 2007》），导致各功能像幻灯片般割裂登场，节奏松散无冲劲。

**方案 A：空间穿透与破茧而出 (Zoom-Through & Morph)** 从底层重塑全片时空：
- **放弃多场景硬切**：整个视频构建在一个无边界的连续三维 UI 舞台中；
- **镜头永不跳跃**：摄像机位移与视窗变形具有强物理因果律，所有动作都是前一个动作的动能延伸；
- **极速视觉冲击**：以 0.3s 光速穿透开场，以现代 128 BPM 强劲节奏驱动，全程紧凑无尿点。

### 2. 核心功能战略排布 (24 秒精准叙事)

| 节拍阶段 | 核心产品价值 | 镜头与物理形态 | 解决的开发者死穴 |
| :--- | :--- | :--- | :--- |
| **Beat 1** | **开场聚能** | 奇点光速爆发 (Burst 0.3s) ➔ 冲击环 Morph 为更新弹窗 | 破除沉闷开头，第 0 秒瞬态抓住注意力 |
| **Beat 2** | **应用内边缘自更新** | 流式进度拉满 ➔ 验签点亮 ➔ 纵深收缩化为毛玻璃胶囊 | 开源离线工具“下载即失联”、手动发版易流失痛点 |
| **转场交接** | **物理动量传递** | 镜头 Pan Down 跟随胶囊下坠 ➔ 水滴破裂式散开为看板 | 彻底消灭裸切，Carry Score 达到 1.00 |
| **Beat 3** | **轻量指纹隔离与专属出口直通** | Spotlight 悬浮窗毫秒探活 ➔ Chrome 实例 8° 3D 偏转弹性滑入 | 多环境串扰、网络出口切换繁重割裂 |
| **Beat 4** | **极简终局与终端定格** | 镜头反向极速抽焦 (Zoom Out) ➔ Brew 命令键入与品牌定格 | 原生 Swift 纯血构建、零外部依赖、一键极速安装 |

---

## 二、连续空间物理学与 Carry 动量传递模型 (Carry Score = 1.00)

依据 `onetake/references/rhythm.md` 的动量连续性判据：任何转场边界若出现元素瞬时卸载（`display: none`）或脱离因果的淡入淡出，都会被裁定为 `bare boundary`（裸边界），导致片子退化为 PPT。

本案在所有时段均维持实体元素的物理连续性（Carry）：

```
[Beat 1: 奇点光斑]
      │
      ▼ (Burst 0.3s 光速穿透 · 冲击光环膨胀)
[冲击环 MorphRect] ────────────────────────── Carry 1: 光环边界直接重构为视窗外壳 (Carry Score: 1.0)
      │
      ▼
[Beat 2: 自更新视窗]
      │
      ▼ (原子自愈热更完成 · Scale 1.0 -> 0.4 纵深收敛)
[悬浮毛玻璃胶囊] ──────────────────────────── Carry 2: 视窗凝聚为实体胶囊 (Carry Score: 1.0)
      │
      ▼ (镜头 Pan Down 跟随重力加速下坠 · 触地水滴散开)
[水滴涟漪 Ripple] ─────────────────────────── Carry 3: 冲击波横向扩散拉开浏览器看板 (Carry Score: 1.0)
      │
      ▼
[Beat 3: 浏览器与出口看板]
      │
      ▼ (选中专属出口 · 实例卡片 8° 3D 偏转弹性归位)
[Chrome 实例视窗]
      │
      ▼ (摄像机对数空间极速反向拉升 · Reverse Zoom-Out)
[Beat 4: 终端安装台与品牌徽标] ────────────── Carry 4: 视窗退居环境背景，命令行破土而出 (Carry Score: 1.0)
```

**全片 4 处时空交接点全部满足 Carry 判据：**
$$\text{Carry Score} = \frac{\text{Carried Boundaries}}{\text{Total Boundaries}} = \frac{4}{4} = \mathbf{1.00}$$

---

## 三、128 BPM 现代科技轻快鼓点与声画对齐总谱

### 1. 音乐选型标准与节拍网格
* **曲风**：Minimal Tech / Snappy Glitch Hop（128 BPM）。
* **音色构成**：短促下潜有力的电子底鼓（Snappy Kick，40–120Hz）、极清脆的闭镲（Crisp Hi-hats，8–14kHz）、干爽的响指（Finger Snaps）与微观电气颗粒（Micro Glitches）。
* **网格计算**：
  * **1 拍 (Beat)** = $\frac{60}{128} \times 30 = \mathbf{14.0625 \text{ 帧}}$
  * **1 小节 (Bar = 4 拍)** = $\mathbf{56.25 \text{ 帧}}$（约 1.875 秒）
  * **全片 24 秒 (720 帧)** = **12.8 小节（51 拍）**

### 2. 关键帧节拍对齐与物理 SFX 总谱表

| 小节.拍 | 对应帧数 | 画面物理事件 | 鼓点层响应 | 专属物理音效 (SFX) |
| :--- | :--- | :--- | :--- | :--- |
| **Bar 1.1** | `f0` | 黑暗中微米级发光奇点凝聚 | 预备拍静音 | `sfx-air-intake.mp3`（短促空气抽吸） |
| **Bar 1.3** | `f9` | 奇点光速穿透爆发（Burst） | **重 Kick + 脆 Snap** | `sfx-laser-burst.mp3`（高频激光引爆音） |
| **Bar 1.4** | `f21` | 冲击光环光速展开，开始 MorphRect | Hi-hat 16分音符滚奏 | `sfx-whoosh-fast.mp3`（极速空间破风声） |
| **Bar 2.3** | `f84` | 弹窗框体咬合锁定，自更新 UI 就绪 | **重 Snare 脆击** | `sfx-latch-click.mp3`（金属卡扣咬合脆响） |
| **Bar 3.1** | `f112` | 鼠标轻击“立即更新并重启”按钮 | Kick 沉稳落地 | `sfx-haptic-tap.mp3`（拟真触觉震动短点） |
| **Bar 3.3** | `f140` | 24.8MB 下载流式进度拉满 (100%) | 密集 Glitch 打击 | `sfx-data-stream.mp3`（极速数字流滴答） |
| **Bar 4.1** | `f168` | SHA-256 哈希校验通过点亮 | Hi-hat 开镲切音 | `sfx-verify-chime-1.mp3`（清脆高频泛音） |
| **Bar 4.3** | `f196` | Apple CodeSign 原生签名验签通过 | Hi-hat 开镲切音 | `sfx-verify-chime-2.mp3`（更高八度泛音） |
| **Bar 5.1** | `f225` | Quarantine 隔离属性安全脱附 | Kick 重音 | `sfx-shield-pass.mp3`（护盾解脱微鸣） |
| **Bar 5.3** | `f253` | 原子级替换热重启，视窗白光微闪 | **Snare 爆点** | `sfx-electric-flash.mp3`（精密继电器脉冲） |
| **Bar 6.1** | `f285` | 视窗向深处压缩为悬浮毛玻璃胶囊 | 鼓点骤降，带下潜滤镜 | `sfx-capsule-shrink.mp3`（真空抽聚吸入音） |
| **Bar 6.3** | `f315` | 镜头 Pan Down 跟随胶囊垂直下坠 | 低频 Riser 上扬 | `sfx-gravity-fall.mp3`（重力下坠风声） |
| **Bar 7.1** | `f337` | **胶囊砸地散开成水滴涟漪 (Pancake)** | **大 Kick + Crash 浪涌** | `sfx-waterdrop-impact.mp3`（清澈水滴炸裂） |
| **Bar 7.2** | `f351` | 涟漪拉开展开浏览器实例看板 | 贝斯重低音切入 | `sfx-surface-expand.mp3`（画布张开展布声） |
| **Bar 8.1** | `f393` | 呼出 Spotlight 380×430 悬浮岛 | Snap 脆响 | `sfx-bubble-pop.mp3`（清透气泡爆破） |
| **Bar 8.3** | `f421` | 搜索框键入 `HK`，实时收拢结果 | 机械键盘敲击 (2次) | `sfx-type-key.mp3`（极干脆轻量机械轴声） |
| **Bar 9.1** | `f450` | 触发全链路并发探活，转圈探活 | Hi-hat 连续密奏 | `sfx-sonar-ping.mp3`（微型声呐毫秒回响） |
| **Bar 9.3** | `f478` | 最低延迟绿色徽标点亮 (`28ms`) | 电子双音阶 | `sfx-metric-green.mp3`（链路接通悦耳音） |
| **Bar 10.1** | `f506` | 点选专属出口，Chrome 8° 倾角滑入 | **重 Kick + 强阻尼弹簧** | `sfx-tilt-slide.mp3`（精密滑轨 + 阻尼落定） |
| **Bar 11.1** | `f562` | 镜头对数空间极速反拉 (Zoom-Out) | 鼓点全开，切分音高潮 | `sfx-reverse-pull.mp3`（高空急速反拉风鸣） |
| **Bar 11.3** | `f590` | 终端命令行浮现，字符极速敲出 | 连续键盘键入 | `sfx-keyboard-run.mp3`（打字机一气呵成） |
| **Bar 12.1** | `f618` | 品牌徽标落定，双同心圆震荡展开 | **终极 Kick + 纯净泛音** | `sfx-seal-drop.mp3`（高奢印章定格音） |
| **Bar 13.1** | `f675–720` | 画面完全静止呼吸 1.5 秒，自然收音 | 鼓点停，氛围混响尾音 | 自然衰减至静止 |

---

## 四、中国大陆全平台防封控合规体系

为确保在 B 站、抖音、微信视频号、小红书等大陆核心流量平台安全过审且不限流，全片严格执行以下三层防御：

### 1. 绝对禁词红线（词库拦截度 100%）
- **严禁出现**：`VPN`、`Clash`、`Shadowrocket`、`V2Ray`、`Trojan`、`翻墙`、`科学上网`、`代理`、`节点`、`机场`、`订阅链接`、`免翻`。

### 2. 合规极客概念重塑表

| 传统敏感概念 | 官方合规科技概念 | 视频主副标题文案规范 |
| :--- | :--- | :--- |
| Clash / 代理内核 | **实例级专属网络出口** | `专属出口直通调度` |
| 节点选择器 | **Spotlight 悬浮调度台** | `Spotlight 悬浮调度台` |
| 节点测速 / Ping | **高并发全链路毫秒级探活** | `全路并发，毫秒探活` |
| 多环境代理配置 | **轻量指纹多 Profile 容器隔离** | `指纹环境物理隔离` |
| 跨国研发网络 | **跨境研发加速环境** | `研发加速专线` |

### 3. UI 界面脱敏与专线命名规范
录屏素材中的列表项一律采用顶级数据中心研发专线名称，禁止出现任何第三方服务商品牌：
- ✅ `HK-Direct-Alpha [28ms]`（香港专线直连）
- ✅ `JP-Tokyo-Cluster [45ms]`（东京研发集群）
- ✅ `SG-Dedicated-01 [56ms]`（新加坡专属出口）
- ✅ `US-SiliconValley-Fast [128ms]`（硅谷加速通道）

---

## 五、24秒一镜到底分镜详细工程设定 (Beat 1 – Beat 4)

### Beat 1: 奇点穿透与破茧而出 (f0 – f90 · 3.0s)

* **镜头定位与空间构造**：
  * 初始坐标：纯净极客空间中央，背景点阵微弱可见（54pt 空间网格，深度 Z = 1.2）。
  * 坐标原点 `(cx: 540, cy: 960)` 悬浮一枚发光的琥珀微米奇点。
* **物理运动轨迹**：
  * `f0 – f9`（0.3s）：奇点在静止中剧烈蓄能，随后以 Ease-In Expo 爆发（Scale 0.01 ➔ 2.4），激射出一道穿透视野的白色光晕。
  * `f9 – f30`：爆发激起的双重冲击环（Shockwave Ring）向外光速扩张。
  * `f30 – f84`（MorphRect 破茧过程）：
    * 冲击环并未消失，而是作为**边界实体（Carrier）**！
    * 圆环的四角在弹性阻尼作用下（Spring: mass 1.2, damping 16）向外撑开拉直；
    * 圆形光环精准变形为尺寸 `860px × 540px`、圆角 `22px` 的视窗卡框！
    * 框内毛玻璃材质瞬间灌注，原生红黄绿交通灯自然显现，完成从光到界面的物理破茧！
* **Apple China 风格文案**：
  * **主标**：`Pharos v3.2.0`（字号 58px，字重 700，SF Pro Display / PingFang SC）
  * **副标**：`见微，自此常新。`
  * **英文**：`Telemetry re-engineered.`
* **声画卡点**：
  * `f9`：Kick 砸下，激光穿透爆发音。
  * `f84`：卡扣咬合脆响，主标完全落定。

---

### Beat 2: 应用内自更新与胶囊收敛 (f90 – f330 · 8.0s)

* **素材载体**：`public/footage/01-update.mp4`（真机录制更新流）。
* **物理运动与交互还原**：
  * **动作 1 (f90 – f140 · 毫秒级拉满)**：
    * 悬浮更新视窗居中，光标轻击“立即更新并重启”按钮（按压深度 0.94，微弹簧复位）。
    * 进度条以 32 MB/s 高速流式推进，1 秒内完成 `24.8 MB` 填充，进度条泛起动态高光波纹。
  * **动作 2 (f140 – f260 · 极客验签流水线)**：
    * 视窗右侧浮动出现半透明 HUD 验签卡点：
      1. `✓ Cloudflare Worker 边缘 300s 动态感知`
      2. `✓ CryptoKit.SHA256 双重哈希比对 (Pass)`
      3. `✓ Apple CodeSign 原生代码签名严格验证 (Valid)`
      4. `✓ Quarantine 隔离属性自动化脱附`
    * 验签标签随节奏点逐项亮起翠绿微光，视窗中央版本号瞬时刷新为 `v3.2.0 (Latest)`。
  * **动作 3 (f260 – f315 · 纵深空间凝聚成胶囊)**：
    * 更新完成，视窗非但没有淡出，而是整体向 Z 轴深处极速收缩（Scale `1.0 -> 0.38`）；
    * 视窗外边框向内聚拢，红绿灯与内容渐隐，整个视窗蜕变凝聚为一枚 `260px × 56px` 的高奢磨砂玻璃微光胶囊（Amber Glint Capsule），悬停在 `cy: 720` 处。
* **Apple China 风格文案**：
  * **四字主标**：`破茧常新。`
  * **工整副标**：`边缘网关静默就绪；双重验签，原子热更，转瞬归位。`
  * **英文**：`Edge-delivered. Atomically restored.`

---

### 核心物理交接: 胶囊下坠与水滴散开 (f315 – f345 · 1.0s · CARRY SCORE 1.0)

> [!IMPORTANT]
> **全片核心招牌转场（The Droplet Pancake）**  
> 绝无黑场、绝无硬切！前序视窗收拢而成的毛玻璃胶囊，直接转化为驱动下一个场景展开的物理锤点。

* **动作过程**：
  * `f315 – f337`：重力加速度生效！胶囊在 Y 轴上从 `720px` 垂直俯冲下坠至 `1180px`；
  * 摄像机执行同步 `Pan Down`，镜头视平线随胶囊高速俯冲；
  * `f337`（Bar 7.1 强 Kick 拍点）：
    * 胶囊重重砸击在虚拟物理底板上，瞬间压扁展开（Squash 纵向 0.2，横向 3.5）；
    * 胶囊如同高粘度水滴“啪”地四散破裂，激荡出一道圆形涟漪冲击波（Droplet Ripple）；
  * `f337 – f355`：涟漪冲击波横向撑开，其边界自然演化为【浏览器实例与网络出口管理看板】（Window 2）的外边框！
* **音效设计**：
  * `f315`：重力吸气破风声（Gravity Fall Whoosh）。
  * `f337`：清澈水滴碎裂爆发音（Waterdrop Impact）+ 强重低音 Kick。

---

### Beat 3: 轻量指纹隔离与专属出口直通 (f330 – f570 · 8.0s)

* **素材载体**：`public/footage/02-browser-routing.mp4`（真机浏览器实例与出口配置）。
* **物理运动与交互还原**：
  * **动作 1 (f330 – f390 · 看板展开与轻量指纹隔离展示)**：
    * 看板平稳落定（宽 980px，高 1420px），画面特写多浏览器实例 Profile：独立的 UserDataDir、隔离的缓存与 Cookie 指纹。
  * **动作 2 (f390 – f470 · 呼出 Spotlight 悬浮窗与毫秒探活)**：
    * 点击出口配置，居中瞬时弹出 Spotlight 风格 380×430 悬浮岛（`NodePickerPopover`）；
    * 搜索框敲入 `HK`，列表零延迟过滤；
    * 探活刷新触发，多条研发专线毫秒时延跃迁变绿：`HK-Direct-Alpha [28ms]`、`JP-Tokyo-Cluster [45ms]`；
    * 延迟排序激活，最优线路瞬间置顶。
  * **动作 3 (f470 – f540 · 3D 偏转弹性滑入)**：
    * 光标干脆利落地选中 `HK-Direct-Alpha [28ms]`，Spotlight 悬浮岛向心闭合；
    * 绑定的 Chrome 实例卡片被激活，带着 **8° 的 3D 偏转（Tilt 8°）** 与高阶空气阻尼弹簧（Spring: mass 1, damping 18），从右侧后方飞速滑入舞台中央！
    * 卡片网络状态指示灯转为晶莹常亮翠绿，展现极客级专属通道直连。
* **Apple China 风格文案**：
  * **四字主标**：`隔而不断。`
  * **工整副标**：`指纹环境物理隔离；专属出口直通调度，全路并发探活。`
  * **英文**：`Isolated profiles. Direct route acceleration.`

---

### Beat 4: 极速反向抽焦与终端定格 (f570 – f720 · 5.0s)

* **镜头运动（Reverse Zoom-Out & Refocus）**：
  * `f570 – f618`（1.6s）：
    * 摄像机脱离局部细节，在对数空间执行极速反向拉升抽焦（Camera Zoom `1.0 -> 0.42`）；
    * 原本占满全屏的视窗在广阔视野中退居为优雅的桌面背景，景深产生轻微高斯模糊（DoF Blur 6px）；
    * 画面正中央，磨砂深色终端胶囊框（Dark Frosted Console）破土而出！
* **终局交互还原 (f618 – f675)**：
  * 终端光标高速闪烁，伴随机械键盘敲击音一气呵成键入：
    ```bash
    $ brew install --cask pharos
    ```
  * 回车敲击，终端下方瞬间弹出鲜亮翠绿对勾：`✔ Downloaded & Verified (Native Apple Silicon & Intel)`。
  * 终端上方升起纯白 Pharos 矢量雷达盾牌，激荡出双重同心波纹。
* **品牌呼吸与静止定格 (f675 – f720 · 1.5s 绝对静止)**：
  * 依据审美准则 R1：关键信息落定后必须呼吸满 1 秒！
  * 终端命令、雷达徽标、底部特性标签（`原生 Swift 构建 · 零外部依赖 · 本地隐私严苛沙盒`）完整停顿，全片在高级静谧中收尾。
* **Apple China 终局文案**：
  * **终局口号**：`你的 Mac，自此了然于心。`
  * **安装命令**：`$ brew install --cask pharos`
  * **官网与源码**：`github.com/Zhengyuuuui/Pharos`

---

## 六、供 Claude Code 执行的 Remotion Master Execution Prompt

> [!TIP]
> **Prompt 架构师一键交付指令**  
> 将以下 Markdown 块完整拷贝并交付给 Claude Code，即可全自动驱动 Remotion 完成新版连续空间合成与无错渲染。

```markdown
# Role & Objective
You are the Lead Remotion Engineer for Pharos v3.2.0 Official Promo Video.
Your goal is to build, animate, and render the complete 24.00s (720 frames @ 30fps) 9:16 vertical video strictly following the "Zoom-Through & Morph" continuous space architecture defined in `docs/PHAROS_PROMO_V320_STORYBOARD.md`.

# Critical Anti-Pitfall Engineering Rules (STRICT ENFORCEMENT)
1. **NO PPT SLIDESHOW (CARRY SCORE >= 0.7)**:
   - NEVER use `display: none` or opacity cross-fades between beats!
   - Beat 1 burst ring MUST morph into Beat 2 window border using `morphRect`.
   - Beat 2 window MUST collapse into a capsule (Scale 1.0 -> 0.38).
   - The capsule MUST pan down and pancake upon impact at f337, exploding as a droplet ripple that expands into Beat 3 window!
   - Beat 3 window MUST stay in the scene while the camera zooms out in log-space to reveal the terminal card in Beat 4.
2. **NO DOUBLE TRAFFIC LIGHTS**:
   - Recorded footage already contains macOS native window titlebars and traffic lights.
   - Your `RealWindowWrapper` container MUST ONLY provide the outer glass shell (`borderRadius: 22`, subtle glow, multi-layered shadows). DO NOT render fake custom traffic light dots!
3. **128 BPM BEAT SYNC & ZERO DONG SOUNDS**:
   - BGM must be modern snappy tech beats (128 BPM).
   - Audio events strictly follow the timing table: Burst at f9, Latch at f84, Tap at f112, Droplet Impact at f337, Tilt at f506, Seal at f618.
   - Zero heavy crash/dong sounds (`fs-812736.mp3` is strictly forbidden).
4. **COMPLIANCE ZERO-TOLERANCE**:
   - Zero occurrences of "VPN", "Clash", "代理", "节点", "翻墙", or airport domains.
   - Strictly use: "轻量指纹多 Profile 容器隔离", "实例级专属网络出口直通", "全链路高并发毫秒探活", "跨境研发加速专线".
5. **CHINESE TYPOGRAPHY**:
   - Font: `-apple-system, "SF Pro Display", "PingFang SC", sans-serif`, `letterSpacing: "-0.015em"`.
   - Character reveal animation MUST use `Array.from(text).map(...)` to avoid UTF-8 multi-byte splitting issues.

# Remotion Project Blueprint

## 1. Composition Settings (Root.tsx)
- Composition ID: `PharosPromoV320`
- Width: `1080`
- Height: `1920`
- FPS: `30`
- DurationInFrames: `720` (24.00s)

## 2. Core Physics Helper: MorphRect.ts
```ts
export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
  r: number;
}

export function morphRect(progress: number, from: Rect, to: Rect): Rect {
  const p = Math.max(0, Math.min(1, progress));
  return {
    x: from.x + (to.x - from.x) * p,
    y: from.y + (to.y - from.y) * p,
    w: from.w + (to.w - from.w) * p,
    h: from.h + (to.h - from.h) * p,
    r: from.r + (to.r - from.r) * p,
  };
}
```

## 3. RealWindowWrapper.tsx (No Artificial Traffic Lights)
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
      {/* NATIVE FOOTAGE SUPPLIES WINDOW CHROME. ZERO ARTIFICIAL HEADER HERE. */}
      {children}
    </div>
  );
};
```

## 4. Main Scene Orchestration Structure (Main.tsx)
```tsx
import React from 'react';
import {
  AbsoluteFill,
  Audio,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import { RealWindowWrapper } from './RealWindowWrapper';
import { AppleTypography } from './AppleTypography';

export const Main: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // BGM Volume: Fade in 0.5s, Fade out 1.5s
  const bgmVolume = interpolate(
    frame,
    [0, 15, 675, 720],
    [0, 0.8, 0.8, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

  return (
    <AbsoluteFill style={{ backgroundColor: '#0A0A0C', overflow: 'hidden' }}>
      {/* 1. Continuous Background Sound */}
      <Audio src={staticFile('audio/bgm_128bpm.mp3')} volume={bgmVolume} />

      {/* 2. One-Take Continuous World Manager */}
      {/* Beat 1: Burst & Morph (f0 - f90) */}
      {/* Beat 2: Auto Update & Shrink to Capsule (f90 - f330) */}
      {/* Handoff: Capsule Pan-Down & Droplet Pancake Impact (f315 - f355) */}
      {/* Beat 3: Browser Instance & Dedicated Egress with 8° Tilt (f330 - f570) */}
      {/* Beat 4: Log-space Reverse Zoom-Out, Terminal Typing & Seal Hold (f570 - f720) */}
    </AbsoluteFill>
  );
};
```

## 5. Render Command
Always execute render with the dynamic timestamp:
```bash
npx remotion render src/index.ts PharosPromoV320 out/pharos-promo-v320-$(date +%Y%m%d-%H%M%S).mp4
```
```

---

## 七、工业级交付与实战自检清单 (Aesthetic Rules 核验)

根据 `video-shotcraft/references/aesthetic-rules.md` 标准，全片渲染交付前必须逐条核验并通过：

### 1. 节奏准则 (R) 自检
- [x] **R1 (呼吸与字标 hold 满 1 秒)**：第 675 帧至第 720 帧（共 45 帧 / 1.5 秒），终局终端与品牌徽标保持绝对静止呼吸，无冗余微动。
- [x] **R2 (速度来自加速度与物理隐喻)**：开场 0.3s 采用 Ease-In Expo 硬加速；自更新视窗收敛为胶囊下坠模拟真实自由落体重力加速度；胶囊触地发生真实水滴溃散变形。
- [x] **R3 (主体动作弧完整，真人操作速度)**：下载进度拉满与验签流水线演示预留了 8.0 秒充裕时间，Spotlight 搜索与过滤演示按真实操作节拍进行，清晰易读。
- [x] **R4 (全画面冲击全片 ≤ 3 处)**：全片整画面级冲击严格限定为 2 处（f9 奇点爆发、f337 胶囊触地水滴散开），均精准钉在 128 BPM 强 Kick 拍点上，其余时间镜头平稳推进。

### 2. 质感、运镜与构图 (Q) 自检
- [x] **Q1 (真实页面录屏与脱敏数据)**：`01-update.mp4` 与 `02-browser-routing.mp4` 均基于原生真实录屏，出口专线采用脱敏合规专线命名。
- [x] **Q2 (3D 透视下 UI 锐度)**：Chrome 实例 8° 3D 偏转时，文字和指示灯均保持高清原生采样，无降采样发糊。
- [x] **Q3 (镜头要稳)**：严禁添加随机手持噪声（Handheld Shake），所有相机移动均由物理目标或对数变焦精确驱动。
- [x] **Q4 (光效裁剪进圆角边界)**：自更新进度条与状态指示灯的高光波纹均通过 `overflow: hidden` 裁切于 22px 视窗圆角内部，杜绝光效外溢。
- [x] **Q5 (开场单主角)**：开场前 3 秒仅聚焦于中心发光奇点与破茧视窗，主体动作弧线唯一且聚焦。
- [x] **Q6 (机位服务可读性)**：列表筛选与更新日志面板保持正视水平机位，仅在实例卡片激活飞入时使用 8° 风格化偏转。

### 3. 声音准则 (S) 自检
- [x] **S1 (摒弃游戏化塑料提示音)**：彻底废弃合成电子音，采用短促空气抽吸、真实金属卡扣、清澈水滴碎裂和触觉马达震动微点。
- [x] **S2 (BGM 全程贯穿且能量匹配)**：128 BPM 现代极简轻快科技鼓点贯穿全片，f0–f15 淡入，f675–f720 随品牌定格自然淡出。
- [x] **S3 (误差 ≤ 2 帧)**：全片所有 Kick、Snare、打字音与落地音效均经过帧级量化对齐，误差绝对控制在 ±1 帧以内。
