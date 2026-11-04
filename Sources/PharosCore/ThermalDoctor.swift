import Foundation
import Darwin

/// Thermal severity assessment level.
public enum ThermalSeverityLevel: String, Codable, Sendable, Comparable {
    case cool        // < 60°C, nominal
    case warm        // 60°C..<75°C, fair
    case hot         // 75°C..<88°C, serious
    case critical    // >= 88°C or critical thermal state

    public var rank: Int {
        switch self {
        case .cool: return 0
        case .warm: return 1
        case .hot: return 2
        case .critical: return 3
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

/// Category of process or workload causing thermal elevation.
public enum ThermalCulpritCategory: String, Codable, Sendable, CaseIterable {
    case compiler            // Code compilers (swift-frontend, clang, rustc, cargo)
    case devServer           // Dev servers / runtimes (node, python, java, bun)
    case mediaIndexing       // Background photo & video AI indexing (mediaanalysisd, photoanalysisd)
    case systemIndexing      // Spotlight / metadata indexing (mdworker, corespotlightd, cloudd)
    case graphicsOrBrowser   // GPU rendering / video decode (Chrome GPU, WebKit GPU, VTDecoder)
    case runawayDaemon       // Bloated user-space daemons (intelligenceplatformd, WallpaperVideoExtension)
    case otherWorkload       // Other high-activity tasks

    public var icon: String {
        switch self {
        case .compiler: return "hammer.fill"
        case .devServer: return "server.rack"
        case .mediaIndexing: return "photo.stack.fill"
        case .systemIndexing: return "magnifyingglass.circle.fill"
        case .graphicsOrBrowser: return "display"
        case .runawayDaemon: return "gearshape.2.fill"
        case .otherWorkload: return "cpu"
        }
    }
}

/// A specific process diagnosed as generating notable heat.
public struct ThermalCulprit: Identifiable, Hashable, Sendable, Codable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let category: ThermalCulpritCategory
    public let memoryBytes: UInt64
    public let cpuTimeNs: UInt64
    public let explanation: String
    public let isKillable: Bool

    public init(
        pid: Int32,
        name: String,
        category: ThermalCulpritCategory,
        memoryBytes: UInt64 = 0,
        cpuTimeNs: UInt64 = 0,
        explanation: String,
        isKillable: Bool = true
    ) {
        self.pid = pid
        self.name = name
        self.category = category
        self.memoryBytes = memoryBytes
        self.cpuTimeNs = cpuTimeNs
        self.explanation = explanation
        self.isKillable = isKillable
    }
}

/// Identified root cause explaining why the machine is warm or hot.
public struct ThermalReason: Identifiable, Hashable, Sendable, Codable {
    public var id: String { title }
    public let title: String
    public let detail: String
    public let icon: String
    public let severity: ThermalSeverityLevel

    public init(title: String, detail: String, icon: String, severity: ThermalSeverityLevel) {
        self.title = title
        self.detail = detail
        self.icon = icon
        self.severity = severity
    }
}

/// Concrete actionable recommendation to mitigate thermal stress.
public struct ThermalSuggestion: Identifiable, Hashable, Sendable, Codable {
    public var id: String { title }
    public let title: String
    public let detail: String
    public let actionKind: ActionKind

    public enum ActionKind: Sendable, Codable, Equatable, Hashable {
        case maxFans
        case killProcess(pid: Int32, name: String)
        case openEnergySettings
        case adviceOnly
    }

    public init(title: String, detail: String, actionKind: ActionKind) {
        self.title = title
        self.detail = detail
        self.actionKind = actionKind
    }
}

/// Complete diagnostic report on machine thermal status and heat sources.
public struct ThermalDiagnosisReport: Sendable, Codable, Equatable {
    public let level: ThermalSeverityLevel
    public let peakTemperature: Double
    public let chipPeakTemp: Double?
    public let batteryTemp: Double?
    public let powerTemp: Double?
    public let thermalStateRaw: Int
    public let reasons: [ThermalReason]
    public let culprits: [ThermalCulprit]
    public let suggestions: [ThermalSuggestion]
    public let isChargingHeat: Bool
    public let isFanLagging: Bool

    public var thermalState: ProcessInfo.ThermalState {
        ProcessInfo.ThermalState(rawValue: thermalStateRaw) ?? .nominal
    }

    public init(
        level: ThermalSeverityLevel,
        peakTemperature: Double,
        chipPeakTemp: Double?,
        batteryTemp: Double?,
        powerTemp: Double?,
        thermalState: ProcessInfo.ThermalState,
        reasons: [ThermalReason],
        culprits: [ThermalCulprit],
        suggestions: [ThermalSuggestion],
        isChargingHeat: Bool,
        isFanLagging: Bool
    ) {
        self.level = level
        self.peakTemperature = peakTemperature
        self.chipPeakTemp = chipPeakTemp
        self.batteryTemp = batteryTemp
        self.powerTemp = powerTemp
        self.thermalStateRaw = thermalState.rawValue
        self.reasons = reasons
        self.culprits = culprits
        self.suggestions = suggestions
        self.isChargingHeat = isChargingHeat
        self.isFanLagging = isFanLagging
    }
}

/// Pure-logic engine diagnosing why the Mac is heating up and identifying culprit workloads.
public enum ThermalDoctor {

    public static func diagnose(
        thermals: ThermalSnapshot?,
        thermalState: ProcessInfo.ThermalState,
        processes: [ProcessSnapshot],
        battery: BatteryReading?
    ) -> ThermalDiagnosisReport {
        let chipPeak = thermals?.peakChipTemperature
        let batTemp = battery?.temperatureCelsius ?? thermals?.groups[.battery]
        let pwrTemp = thermals?.groups[.power]

        // Calculate maximum physical temperature observed across chip, power and battery
        let candidateTemps = [chipPeak, batTemp, pwrTemp, thermals?.groups[.gpu]].compactMap { $0 }
        let peakTemp = candidateTemps.max() ?? 45.0

        // Assess overall severity level
        let level: ThermalSeverityLevel
        if thermalState == .critical || peakTemp >= 88.0 {
            level = .critical
        } else if thermalState == .serious || peakTemp >= 75.0 {
            level = .hot
        } else if thermalState == .fair || peakTemp >= 60.0 {
            level = .warm
        } else {
            level = .cool
        }

        var reasons: [ThermalReason] = []
        var culprits: [ThermalCulprit] = []
        var suggestions: [ThermalSuggestion] = []

        // 1. Charging / Fast Charging Heat
        var chargingHeatDetected = false
        if let bat = battery, bat.isCharging {
            let watts = bat.adapterWatts ?? Int(bat.watts)
            if watts >= 45 || (bat.temperatureCelsius >= 35.0 && peakTemp >= 60.0) {
                chargingHeatDetected = true
                reasons.append(ThermalReason(
                    title: "大功率快充发热 (Fast Charging Heat)",
                    detail: "当前连接了 \(watts > 0 ? "\(watts)W " : "")电源适配器进行充电。大电流流经电芯与内部降压变换芯片（PMU），机身与电池温度会升高约 8°C~15°C，属于正常物理发热特性。",
                    icon: "bolt.fill",
                    severity: level >= .hot ? .hot : .warm
                ))
            }
        }

        // 2. Apple Silicon Silent Fan Curve Delay (Silent Fan Lag)
        var fanLagDetected = false
        if let fans = thermals?.fans, !fans.isEmpty {
            let allStoppedOrLow = fans.allSatisfy { $0.actualRPM == 0 || $0.actualRPM < 1500 }
            if (chipPeak ?? 0) >= 75.0 && allStoppedOrLow {
                fanLagDetected = true
                reasons.append(ThermalReason(
                    title: "系统静音风扇策略延迟 (Silent Fan Delay)",
                    detail: "macOS 默认追求极致静音，风扇起转阈值较晚（通常在芯片达到 85°C 左右才开始升速）。当前风扇尚未全力运转，热量主要依靠铝合金机身被动散热。",
                    icon: "fanblades.slash",
                    severity: .warm
                ))
                suggestions.append(ThermalSuggestion(
                    title: "一键提速风扇强制排热",
                    detail: "提前将风扇调整为较高转速，可迅速将机身与芯片降温 10°C~20°C。",
                    actionKind: .maxFans
                ))
            }
        }

        // 3. Process analysis: Identify Top Heat Culprits
        var foundCompiler = false
        var foundMediaAI = false
        var foundSpotlight = false
        var foundGPU = false
        var foundDevServer = false

        for p in processes {
            let name = p.name.lowercased()
            let path = (p.executablePath ?? "").lowercased()

            // Compilers & Build Tools
            if name.contains("swift-frontend") || name.contains("clang") || name.contains("rustc") ||
               name == "cargo" || name == "xcodebuild" || name == "ghc" ||
               path.hasSuffix("/clang") || path.hasSuffix("/swift-frontend") {
                foundCompiler = true
                culprits.append(ThermalCulprit(
                    pid: p.pid,
                    name: p.name,
                    category: .compiler,
                    memoryBytes: p.memoryBytes,
                    explanation: "多核并发编译构建进程，密集调用 CPU 性能核心释放峰值功耗",
                    isKillable: true
                ))
            }
            // Background Media AI
            else if name.contains("mediaanalysisd") || name.contains("photoanalysisd") {
                foundMediaAI = true
                culprits.append(ThermalCulprit(
                    pid: p.pid,
                    name: p.name,
                    category: .mediaIndexing,
                    memoryBytes: p.memoryBytes,
                    explanation: "相册与视频实况文本/人脸视觉 AI 后台索引，多核高负荷扫描",
                    isKillable: true
                ))
            }
            // System Indexing (Spotlight / iCloud)
            else if name.contains("mdworker") || name.contains("corespotlightd") || name == "cloudd" {
                foundSpotlight = true
                culprits.append(ThermalCulprit(
                    pid: p.pid,
                    name: p.name,
                    category: .systemIndexing,
                    memoryBytes: p.memoryBytes,
                    explanation: "Spotlight 全盘文件与元数据建立索引，磁盘与 CPU 活跃占用",
                    isKillable: true
                ))
            }
            // GPU & Browser Rendering
            else if name.contains("gpu-process") || name.contains("webkit.gpu") || name == "vtdecoderxpcservice" {
                foundGPU = true
                culprits.append(ThermalCulprit(
                    pid: p.pid,
                    name: p.name,
                    category: .graphicsOrBrowser,
                    memoryBytes: p.memoryBytes,
                    explanation: "图形与视频硬件加速管道活跃，引发 GPU 芯片温升",
                    isKillable: true
                ))
            }
            // Dev servers with large footprint (> 250MB)
            else if (name == "node" || name == "python" || name == "python3" || name == "java" || name == "docker") && p.memoryBytes > 250 * 1024 * 1024 {
                foundDevServer = true
                culprits.append(ThermalCulprit(
                    pid: p.pid,
                    name: p.name,
                    category: .devServer,
                    memoryBytes: p.memoryBytes,
                    explanation: "长期活跃的本地开发服务或容器环境，保持持续计算占用",
                    isKillable: true
                ))
            }
            // Runaway system daemons
            else if name == "wallpapervideoextension" || name == "intelligenceplatformd" {
                culprits.append(ThermalCulprit(
                    pid: p.pid,
                    name: p.name,
                    category: .runawayDaemon,
                    memoryBytes: p.memoryBytes,
                    explanation: "动态壁纸或本地知识图谱守护进程持续渲染/计算",
                    isKillable: true
                ))
            }
        }

        // Add Reason entries based on matched culprits
        if foundCompiler {
            reasons.append(ThermalReason(
                title: "高负载代码编译构建 (Heavy Compilation)",
                detail: "检测到 Swift / Rust / C++ 编译器正在多线程高并发运行，这是导致 Mac 瞬时升温至 80°C~95°C 最主要的开发场景。",
                icon: "hammer.fill",
                severity: .hot
            ))
        }

        if foundMediaAI {
            reasons.append(ThermalReason(
                title: "系统后台媒体视觉 AI 分析 (Media Analysis)",
                detail: "系统正在后台扫描图库与视频帧执行实况文本 OCR 及人物聚类。这通常在新导入视频或系统更新后集中发生，发热属于瞬态。",
                icon: "photo.stack.fill",
                severity: .warm
            ))
        }

        if foundSpotlight {
            reasons.append(ThermalReason(
                title: "Spotlight 全盘索引建立 (Disk Indexing)",
                detail: "Spotlight 元数据索引守护进程（mdworker）正在扫描更新文件树，会带来持续的 CPU 算力与存储器能耗。",
                icon: "magnifyingglass.circle.fill",
                severity: .warm
            ))
        }

        if foundGPU {
            reasons.append(ThermalReason(
                title: "GPU 渲染与图形硬件加速 (Graphics & Video Load)",
                detail: "外接多显示器、高刷屏幕渲染或浏览器 GPU 硬件加速管线处于活跃状态，导致图形核心温度提升。",
                icon: "display",
                severity: .warm
            ))
        }

        if foundDevServer {
            reasons.append(ThermalReason(
                title: "本地多服务运行环境 (Dev Servers & Containers)",
                detail: "存在占用较高内存与计算资源的 Node / Python / Java 本地服务，持续的监听与热重载引起机身温热。",
                icon: "server.rack",
                severity: .warm
            ))
        }

        // 4. System Throttling Reason
        if thermalState == .serious || thermalState == .critical {
            reasons.append(ThermalReason(
                title: "macOS 系统温控降频保护 (Thermal Throttling Engaged)",
                detail: "系统热压力已达到警戒线，macOS 正在限制芯片核心时钟频率以防止物理损坏，部分应用可能会出现掉帧或卡顿。",
                icon: "exclamationmark.triangle.fill",
                severity: .critical
            ))
            suggestions.append(ThermalSuggestion(
                title: "开启 macOS 低电量模式降低发热",
                detail: "低电量模式会主动限制峰值功耗并关闭部分耗热特效，有助于机身迅速降温。",
                actionKind: .openEnergySettings
            ))
        }

        // If top culprits exist, suggest terminating top one
        if let topKillable = culprits.first(where: { $0.isKillable }) {
            suggestions.append(ThermalSuggestion(
                title: "结束高耗热进程：\(topKillable.name) (PID \(topKillable.pid))",
                detail: topKillable.explanation,
                actionKind: .killProcess(pid: topKillable.pid, name: topKillable.name)
            ))
        }

        // Clean cool baseline state
        if reasons.isEmpty && level == .cool {
            reasons.append(ThermalReason(
                title: "散热状况优良 (Thermal Condition Optimal)",
                detail: "当前各芯片温度处于最佳能效温区（低于 60°C），无异常高发热进程，机身清凉静音运行。",
                icon: "checkmark.shield.fill",
                severity: .cool
            ))
        }

        return ThermalDiagnosisReport(
            level: level,
            peakTemperature: peakTemp,
            chipPeakTemp: chipPeak,
            batteryTemp: batTemp,
            powerTemp: pwrTemp,
            thermalState: thermalState,
            reasons: reasons,
            culprits: Array(culprits.prefix(6)),
            suggestions: suggestions,
            isChargingHeat: chargingHeatDetected,
            isFanLagging: fanLagDetected
        )
    }
}
