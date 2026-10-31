import AppKit
import SwiftUI
import PharosCore

// MARK: - 1. Ports Overview Inspector (Paradigm B: Twin-Tile Matrix)

struct PortsOverviewInspectorView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @State private var lanIP: String? = nil

    var body: some View {
        let allPorts = store.projects.flatMap(\.ports)
        let exposedCount = allPorts.filter { !$0.loopbackOnly }.count
        let webUrls = LocalNetwork.resolveWebURLs(ports: allPorts, lanIP: lanIP)
        let daemons = LocalNetwork.auditDaemons(listeningPorts: allPorts)

        VStack(spacing: 8) {
            // [Block 1A & 1B] 1:1 双子微方块 (高 68pt，宽 126pt × 2)
            InspectorTwinTilesRow {
                PharosBentoTile(
                    title: l10n.activePorts,
                    value: "\(allPorts.count)",
                    subtitle: allPorts.isEmpty ? (l10n.isZh ? "端口空闲" : "Idle") : l10n.normalListening,
                    systemImage: "antenna.radiowaves.left.and.right",
                    dotLevel: allPorts.isEmpty ? .offline : .normal
                )
            } b: {
                PharosBentoTile(
                    title: l10n.publicExposure,
                    value: "\(exposedCount)",
                    subtitle: exposedCount > 0 ? l10n.openBroadcasting : (l10n.isZh ? "无公网开放" : "Safe Local"),
                    systemImage: "network",
                    dotLevel: exposedCount > 0 ? .warning : .normal
                )
            }

            // [Block 2] 局域网联调中枢 (Hero 主力大卡)
            PharosBentoCard(title: l10n.lanDebugStation, systemImage: "wifi", trailingBadge: lanIP ?? "-") {
                VStack(alignment: .leading, spacing: 8) {
                    if webUrls.isEmpty {
                        Text(l10n.isZh ? "未检测到常见 Web 调试端口" : "No active web dev ports")
                            .font(.system(size: 11))
                            .foregroundStyle(PharosColor.textTertiary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(webUrls.prefix(3)) { item in
                                HStack(spacing: 5) {
                                    PharosStatusDot(level: item.isLoopbackOnly ? .normal : .warning)
                                    Text(item.lanURL)
                                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                                        .foregroundStyle(PharosColor.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        copyToClipboard(item.lanURL)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 10))
                                            .foregroundStyle(PharosColor.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help(l10n.copyLanUrl)
                                }
                            }
                        }
                    }

                    if let firstUrl = webUrls.first {
                        PharosActionPill(title: l10n.copyMobileLanUrl, systemImage: "iphone.gen3", isPrimary: true) {
                            copyToClipboard(firstUrl.lanURL)
                        }
                    }
                }
            }

            // [Block 3] 暴露安全审计微卡 (Medium 卡)
            PharosBentoCard(title: l10n.exposureAuditTitle, systemImage: "shield.checkered") {
                VStack(alignment: .leading, spacing: 6) {
                    if exposedCount > 0 {
                        Text(l10n.lanExposedWarning(exposedCount))
                            .font(.system(size: 11))
                            .foregroundStyle(PharosColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(l10n.allLoopbackSafe)
                            .font(.system(size: 11))
                            .foregroundStyle(PharosColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Background daemons row
                    HStack(spacing: 8) {
                        ForEach(daemons.prefix(3)) { daemon in
                            HStack(spacing: 3) {
                                PharosStatusDot(level: daemon.isRunning ? .normal : .offline)
                                Text(daemon.name)
                                    .font(.system(size: 10))
                                    .foregroundStyle(daemon.isRunning ? PharosColor.textSecondary : PharosColor.textTertiary)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .onAppear {
            lanIP = LocalNetwork.activeLANIPv4()
        }
        .onChange(of: store.lastScan) { _, _ in
            if lanIP == nil { lanIP = LocalNetwork.activeLANIPv4() }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - 2. System Memory Inspector (Paradigm A: Classic Cadence)

struct SystemMemoryInspectorView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @State private var showConfirmReclaim = false
    @State private var showConfirmDisableAIMedia = false

    var body: some View {
        let stats = store.system
        let breakdown = MemoryAttribution.calculate(apps: store.apps)
        let pressure = stats?.pressure ?? .normal
        let isThrashing = (stats?.swapUsed ?? 0) > 1024 * 1024 * 1024 // > 1GB swap
        let diagnosis = store.memoryDiagnosis

        VStack(spacing: 8) {
            // [Block 1] 内存压力与颠簸脉搏条 (Mini 胶囊卡, 高 48pt)
            PharosBentoPulse(
                text: pressure == .normal && !isThrashing ? l10n.memoryPulseNormal : l10n.memoryPulseWarning,
                dotLevel: pressure == .critical ? .critical : (pressure == .warning || isThrashing ? .warning : .normal)
            )

            // [Daemon Governance Block] 守护进程治理与 Not Launch 永久禁启卡片
            PharosBentoCard(title: l10n.memoryBloatDiagnostics, systemImage: "cross.vial.fill") {
                VStack(alignment: .leading, spacing: 6) {
                    if diagnosis.hasBloat {
                        HStack(spacing: 6) {
                            Image(systemName: diagnosis.criticalCount > 0 ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(diagnosis.criticalCount > 0 ? PharosColor.error : PharosColor.warning)
                                .font(.system(size: 13))
                            Text(l10n.ambientBloatWarning(diagnosis.bloatedCount, ByteFormat.short(diagnosis.reclaimableBytes)))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PharosColor.textPrimary)
                        }

                        if let topBloat = diagnosis.bloatedItems.first {
                            Text("\(topBloat.daemon.primaryName): \(ByteFormat.short(topBloat.memoryBytes)) (\(l10n.daemonStatus(topBloat.status)))")
                                .font(.system(size: 10))
                                .foregroundStyle(PharosColor.textSecondary)
                                .lineLimit(1)
                        }

                        PharosActionPill(title: l10n.reclaimAllBloated, systemImage: "sparkles", isPrimary: true) {
                            showConfirmReclaim = true
                        }
                    } else {
                        HStack(spacing: 5) {
                            PharosStatusDot(level: .normal)
                            Text(diagnosis.disabledCount > 0 ? l10n.disabledDaemonsCount(diagnosis.disabledCount) : l10n.allDaemonsHealthy)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(PharosColor.textPrimary)
                                .lineLimit(1)
                        }
                    }

                    if !diagnosis.allRecommendedDisabled {
                        PharosActionPill(title: l10n.disableAllAIMediaAutostart, systemImage: "nosign", isPrimary: !diagnosis.hasBloat) {
                            showConfirmDisableAIMedia = true
                        }
                    }
                }
            }

            // [Block 2] 三大领域占用归因组件 (Hero 主力大卡, 约 160pt)
            PharosBentoCard(title: l10n.domainBreakdown, systemImage: "chart.pie.fill") {
                VStack(spacing: 5) {
                    HStack {
                        Text(l10n.domainDevTools).font(.system(size: 10.5)).foregroundStyle(PharosColor.textSecondary)
                        Spacer()
                        Text(ByteFormat.short(breakdown.devBytes)).font(.system(size: 11, weight: .medium).monospacedDigit())
                    }
                    ProgressView(value: breakdown.devFraction)
                        .tint(PharosColor.accent)
                        .scaleEffect(x: 1, y: 0.6, anchor: .center)

                    HStack {
                        Text(l10n.domainBrowsers).font(.system(size: 10.5)).foregroundStyle(PharosColor.textSecondary)
                        Spacer()
                        Text(ByteFormat.short(breakdown.browserBytes)).font(.system(size: 11, weight: .medium).monospacedDigit())
                    }
                    ProgressView(value: breakdown.browserFraction)
                        .tint(Color.orange)
                        .scaleEffect(x: 1, y: 0.6, anchor: .center)

                    HStack {
                        Text(l10n.domainSystem).font(.system(size: 10.5)).foregroundStyle(PharosColor.textSecondary)
                        Spacer()
                        Text(ByteFormat.short(breakdown.otherBytes)).font(.system(size: 11, weight: .medium).monospacedDigit())
                    }
                    ProgressView(value: breakdown.otherFraction)
                        .tint(PharosColor.textTertiary)
                        .scaleEffect(x: 1, y: 0.6, anchor: .center)

                    if let topApp = store.apps.first {
                        HStack(spacing: 4) {
                            Text(l10n.isZh ? "主要消耗:" : "Top:")
                                .font(.system(size: 10))
                                .foregroundStyle(PharosColor.textTertiary)
                            Text(topApp.name)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(PharosColor.textPrimary)
                                .lineLimit(1)
                        }
                        .padding(.top, 2)
                    }
                }
            }

            // [Block 3] 持续递增进程诊断卡 (Medium 卡, 约 80pt)
            PharosBentoCard(title: l10n.trendWatch, systemImage: "waveform.path.ecg") {
                VStack(alignment: .leading, spacing: 6) {
                    if let topApp = store.apps.first {
                        HStack {
                            Text(topApp.name)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(ByteFormat.short(topApp.memoryBytes))
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                .foregroundStyle(PharosColor.textPrimary)
                        }
                    } else {
                        Text(l10n.isZh ? "采样中…" : "Sampling…")
                            .font(.system(size: 11))
                            .foregroundStyle(PharosColor.textTertiary)
                    }

                    PharosActionPill(title: l10n.openActivityMonitor, systemImage: "waveform.path.ecg", isPrimary: true) {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                    }
                }
            }
        }
        .alert(l10n.confirmReclaimAllTitle, isPresented: $showConfirmReclaim) {
            Button(l10n.cancel, role: .cancel) {}
            Button(l10n.confirmReclaimButton, role: .destructive) {
                Task { await store.reclaimAllBloatedDaemons() }
            }
        } message: {
            Text(l10n.confirmReclaimDesc)
        }
        .alert(l10n.confirmDisableAllAIMediaTitle, isPresented: $showConfirmDisableAIMedia) {
            Button(l10n.cancel, role: .cancel) {}
            Button(l10n.confirmDisableAllAIMediaButton, role: .destructive) {
                Task { await store.disableAllRecommendedDaemons() }
            }
        } message: {
            Text(l10n.confirmDisableAllAIMediaDesc)
        }
    }
}

// MARK: - 3. Disk Usage Inspector (Paradigm B: Twin-Tile Matrix)

struct DiskUsageInspectorView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let startup = store.volumes.first(where: { $0.kind == .startup })
        let (availPercent, runwayLevel) = DiskRunway.evaluate(usedFraction: startup?.usedFraction ?? 0.5)
        let externals = store.volumes.filter { $0.kind == .external || $0.kind == .network }

        VStack(spacing: 8) {
            // [Block 1A & 1B] 1:1 双子微方块 (高 68pt，宽 126pt × 2)
            InspectorTwinTilesRow {
                PharosBentoTile(
                    title: l10n.systemDiskMargin,
                    value: "\(Int(availPercent.rounded()))%",
                    subtitle: l10n.ampleAvailable(Int(availPercent.rounded())),
                    systemImage: "internaldrive",
                    dotLevel: runwayLevel == .critical ? .critical : (runwayLevel == .warning ? .warning : .normal)
                )
            } b: {
                PharosBentoTile(
                    title: l10n.externalStorageTile,
                    value: "\(externals.count)",
                    subtitle: l10n.mountedCount(externals.count),
                    systemImage: "externaldrive",
                    dotLevel: externals.isEmpty ? .offline : .normal
                )
            }

            // [Block 2] 大容量集水区直达站 (Hero 主力大卡, 约 165pt)
            PharosBentoCard(title: l10n.quickJumpers, systemImage: "arrow.up.forward.app") {
                VStack(spacing: 6) {
                    jumperRow(title: l10n.jumpDownloads, path: ("~/Downloads" as NSString).expandingTildeInPath)
                    jumperRow(title: l10n.openDerivedData, path: ("~/Library/Developer/Xcode/DerivedData" as NSString).expandingTildeInPath)
                    jumperRow(title: l10n.jumpCaches, path: ("~/Library/Caches" as NSString).expandingTildeInPath)
                }
            }

            // [Block 3] 空间健康与动作卡 (Medium 卡)
            PharosBentoCard(title: l10n.runwayHealth, systemImage: "gauge.with.dots.needle.50percent") {
                VStack(alignment: .leading, spacing: 6) {
                    if let vol = startup {
                        HStack {
                            Text(l10n.isZh ? "已用 / 总量" : "Used / Total")
                                .font(.system(size: 10.5))
                                .foregroundStyle(PharosColor.textSecondary)
                            Spacer()
                            Text("\(ByteFormat.disk(vol.used)) / \(ByteFormat.disk(vol.total))")
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                        }
                    }

                    PharosActionPill(title: l10n.quickCleanupSuggest, systemImage: "trash", isPrimary: true) {
                        WindowRouter.shared.request = .diskCleanup
                    }
                }
            }
        }
    }

    private func jumperRow(title: String, path: String) -> some View {
        Button {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(PharosColor.textSecondary)
                Spacer()
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(PharosColor.textTertiary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 4. Battery & Thermal Inspector (Paradigm C: Balanced Dual)

struct BatteryThermalInspectorView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var battery = BatteryStore.shared
    @ObservedObject private var fanStore = FanStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let r = battery.reading
        let thermals = store.thermals
        let peakTemp = thermals?.peakChipTemperature ?? 48.0
        let (headroom, isThrottling) = ThermalHeadroom.calculate(peakTemp: peakTemp)
        let wattsString = String(format: "%.1f", abs(r.watts))

        VStack(spacing: 8) {
            // [Block 1] 散热节流安全裕度仪 (Medium 卡, 约 120pt)
            PharosBentoCard(title: l10n.thermalHeadroomTitle, systemImage: "thermometer.medium") {
                VStack(alignment: .leading, spacing: 5) {
                    PharosMicroMetric(
                        label: l10n.isZh ? "最高芯片温度" : "Peak Sensor",
                        value: "\(Int(peakTemp.rounded()))°C",
                        unit: l10n.headroomDegrees(Int(headroom.rounded())),
                        dotLevel: isThrottling ? .critical : (headroom < 15 ? .warning : .normal)
                    )
                    ProgressView(value: min(1.0, max(0.0, peakTemp / 100.0)))
                        .tint(headroom > 25 ? PharosColor.success : (headroom > 10 ? PharosColor.warning : PharosColor.error))
                        .scaleEffect(x: 1, y: 0.6, anchor: .center)

                    HStack(spacing: 4) {
                        Text(l10n.throttlingStatus + ":")
                            .font(.system(size: 10))
                            .foregroundStyle(PharosColor.textTertiary)
                        Text(isThrottling ? l10n.throttlingActive : l10n.throttlingNone)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(isThrottling ? PharosColor.error : PharosColor.success)
                    }
                }
            }

            // [Block 2] 实时功率与续航测算 (Medium 卡, 约 120pt)
            PharosBentoCard(title: l10n.powerDraw, systemImage: "bolt.fill") {
                VStack(spacing: 5) {
                    PharosMicroMetric(label: l10n.isZh ? "实时整机功耗" : "Power Draw", value: "\(wattsString) W", dotLevel: .normal)
                    if r.hasBattery {
                        PharosMicroMetric(
                            label: l10n.isZh ? "健康度 / 循环" : "Health / Cycles",
                            value: "\(r.healthPercent)% / \(r.cycleCount)"
                        )
                        HStack {
                            Text(r.isCharging ? l10n.batteryPulseCharging : (l10n.isZh ? "放电运行中" : "On Battery"))
                                .font(.system(size: 10))
                                .foregroundStyle(PharosColor.textTertiary)
                            Spacer()
                        }
                    }
                }
            }

            // [Block 3] 风扇策略快捷切换微条 (Mini 胶囊卡, 高 44pt)
            PharosBentoCard(title: l10n.fanControlAction, systemImage: "fanblades") {
                if fanStore.helper == .ready {
                    HStack(spacing: 8) {
                        PharosActionPill(
                            title: l10n.fanSystemManaged,
                            systemImage: "gearshape",
                            isPrimary: fanStore.request == .system
                        ) {
                            fanStore.apply(.system)
                        }

                        PharosActionPill(
                            title: l10n.fanFullSpeed,
                            systemImage: "wind",
                            isPrimary: fanStore.request == .max
                        ) {
                            fanStore.apply(.max)
                        }
                    }
                } else {
                    HStack {
                        Text(l10n.isZh ? "风扇控制服务未安装" : "Fan helper not installed")
                            .font(.system(size: 10.5))
                            .foregroundStyle(PharosColor.textTertiary)
                        Spacer()
                        Button(l10n.isZh ? "前往配置" : "Setup") {
                            WindowRouter.shared.batteryThermalTab = .thermals
                            WindowRouter.shared.request = .batteryAndThermals
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}

// MARK: - 5. Packages Inspector (Paradigm A: Classic Cadence)

struct PackagesInspectorView: View {
    @ObservedObject private var packageStore = PackageStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let caches = packageStore.cacheRepos
        let totalBytes = caches.reduce(0) { $0 + $1.fileSizeBytes }
        let nodeBytes = computeNodeBytes(caches)
        let nodePct = totalBytes > 0 ? Int((Double(nodeBytes) / Double(totalBytes) * 100).rounded()) : 0

        VStack(spacing: 8) {
            // [Block 1] 生态资产脉搏微条 (Mini 胶囊卡, 高 48pt)
            PharosBentoPulse(
                text: l10n.packagesPulse(nodePct: nodePct, count: packageStore.globalCliCount),
                dotLevel: .normal
            )

            // [Block 2] 多生态体积占比横条 (Hero 主力大卡, 约 150pt)
            PharosBentoCard(title: l10n.ecosystemProportions, systemImage: "chart.bar.xaxis") {
                VStack(spacing: 5) {
                    PharosMicroMetric(label: "Node (npm / pnpm)", value: ByteFormat.disk(nodeBytes))
                    ProgressView(value: totalBytes > 0 ? Double(nodeBytes) / Double(totalBytes) : 0)
                        .tint(PharosColor.accent)
                        .scaleEffect(x: 1, y: 0.6, anchor: .center)

                    PharosMicroMetric(label: l10n.isZh ? "总依赖缓存" : "Total Caches", value: ByteFormat.disk(totalBytes))
                    PharosMicroMetric(label: l10n.isZh ? "全局 CLI 工具" : "Global CLIs", value: "\(packageStore.globalCliCount)")
                }
            }

            // [Block 3] 官方清理指令速查卡 (Medium 卡, 约 82pt)
            PharosBentoCard(title: l10n.cliSnippets, systemImage: "terminal") {
                VStack(alignment: .leading, spacing: 6) {
                    snippetRow(cmd: "pnpm store prune")
                    snippetRow(cmd: "brew cleanup -s")

                    PharosActionPill(title: l10n.copyCleanCmd, systemImage: "doc.on.doc", isPrimary: true) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("pnpm store prune", forType: .string)
                    }
                }
            }
        }
    }

    private func snippetRow(cmd: String) -> some View {
        HStack {
            Text(cmd)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(PharosColor.textPrimary)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(cmd, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9.5))
                    .foregroundStyle(PharosColor.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private func computeNodeBytes(_ caches: [PackageCacheRepoSummary]) -> UInt64 {
        var nodeBytes: UInt64 = 0
        for c in caches {
            if c.ecosystem == .node {
                nodeBytes += c.fileSizeBytes
            }
        }
        return nodeBytes
    }
}

// MARK: - 6. Chrome Inspector (Paradigm B: Twin-Tile Matrix)

struct ChromeInspectorView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let instances = store.chrome
        let ports = instances.compactMap { $0.config.debugPort }
        let totalMem = instances.reduce(0) { $0 + $1.memoryBytes }

        VStack(spacing: 8) {
            // [Block 1A & 1B] 1:1 双子微方块 (高 68pt，宽 126pt × 2)
            InspectorTwinTilesRow {
                PharosBentoTile(
                    title: l10n.runningInstances,
                    value: "\(instances.count)",
                    subtitle: l10n.isolatedProfiles,
                    systemImage: "globe",
                    dotLevel: instances.isEmpty ? .offline : .normal
                )
            } b: {
                PharosBentoTile(
                    title: l10n.cdpEndpoints,
                    value: "\(ports.count)",
                    subtitle: l10n.remoteDebugReady,
                    systemImage: "hammer.fill",
                    dotLevel: ports.isEmpty ? .offline : .normal
                )
            }

            // [Block 2] DevTools 远程调试直达站 (Hero 主力大卡, 约 150pt)
            PharosBentoCard(title: l10n.activeDevToolsPorts, systemImage: "point.3.connected.trianglepath.dotted") {
                if ports.isEmpty {
                    Text(l10n.isZh ? "未绑定 --remote-debugging-port" : "No remote debugging ports")
                        .font(.system(size: 10.5))
                        .foregroundStyle(PharosColor.textTertiary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(ports, id: \.self) { port in
                            HStack {
                                PharosStatusDot(level: .normal)
                                Text(":\(port)")
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                Spacer()
                                Button(l10n.openInBrowser) {
                                    if let url = URL(string: "http://127.0.0.1:\(port)") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .font(.system(size: 10))
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }

            // [Block 3] 内存总览与快捷预设启动卡 (Medium 卡, 约 72pt)
            PharosBentoCard(title: l10n.browserFootprint, systemImage: "memorychip") {
                VStack(alignment: .leading, spacing: 6) {
                    PharosMicroMetric(
                        label: l10n.isZh ? "实例与渲染进程" : "Instances & Helpers",
                        value: ByteFormat.short(totalMem),
                        dotLevel: .normal
                    )

                    PharosActionPill(title: l10n.newCleanProfile, systemImage: "plus.circle", isPrimary: true) {
                        WindowRouter.shared.request = .chrome
                    }
                }
            }
        }
    }
}

// MARK: - 7. Agent Chats Inspector (Paradigm A: Classic Cadence)

struct AgentChatsInspectorView: View {
    @ObservedObject private var agentStore = AgentChatStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let entries = agentStore.entries
        let bloatCount = entries.filter { $0.fileSizeBytes > 15 * 1024 * 1024 }.count

        VStack(spacing: 8) {
            // [Block 1] 数据库安全脉搏微条 (Mini 胶囊卡, 高 48pt)
            PharosBentoPulse(
                text: l10n.isZh ? "检测到 \(agentStore.totalDatabases) 个编辑器库 · 100% 只读解析中" : "Tracking \(agentStore.totalDatabases) agent databases · 100% read-only",
                dotLevel: agentStore.orphanedCount > 0 ? .warning : .normal
            )

            // [Block 2] 超长会话膨胀预警 (Hero 主力大卡, 约 145pt)
            PharosBentoCard(title: l10n.contextBloatWatch, systemImage: "exclamationmark.triangle") {
                VStack(alignment: .leading, spacing: 6) {
                    if bloatCount > 0 {
                        HStack(spacing: 5) {
                            PharosStatusDot(level: .warning)
                            Text(l10n.contextBloatAlert(bloatCount))
                                .font(.system(size: 11))
                                .foregroundStyle(PharosColor.warning)
                        }
                        Text(l10n.isZh ? "超大会话可能导致编辑器补全延迟与高额费用" : "Large sessions may cause editor latency")
                            .font(.system(size: 10))
                            .foregroundStyle(PharosColor.textTertiary)
                    } else {
                        HStack(spacing: 5) {
                            PharosStatusDot(level: .normal)
                            Text(l10n.contextBloatNormal)
                                .font(.system(size: 11))
                                .foregroundStyle(PharosColor.textPrimary)
                        }
                    }

                    PharosMicroMetric(label: l10n.isZh ? "总数据库数" : "Total Databases", value: "\(agentStore.totalDatabases)")
                    PharosMicroMetric(label: l10n.isZh ? "总会话记录" : "Conversations", value: "\(agentStore.totalConversations)")
                }
            }

            // [Block 3] 备份与快照动作卡 (Medium 卡, 约 76pt)
            PharosBentoCard(title: l10n.snapshotFreshness, systemImage: "externaldrive.badge.timemachine") {
                VStack(alignment: .leading, spacing: 6) {
                    if agentStore.orphanedCount > 0 {
                        HStack(spacing: 5) {
                            PharosStatusDot(level: .warning)
                            Text(l10n.orphanedDbCount(agentStore.orphanedCount))
                                .font(.system(size: 11))
                                .foregroundStyle(PharosColor.warning)
                        }
                    } else {
                        Text(l10n.isZh ? "数据库状态全部健康" : "All databases intact")
                            .font(.system(size: 10.5))
                            .foregroundStyle(PharosColor.textTertiary)
                    }

                    PharosActionPill(title: l10n.quickExportDb, systemImage: "arrow.down.doc", isPrimary: true) {
                        if let first = agentStore.entries.first {
                            agentStore.backupEntry(first)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 8. Disk Cleanup Inspector (Paradigm A: Classic Cadence)

struct DiskCleanupInspectorView: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let startup = store.volumes.first(where: { $0.kind == .startup })
        let cleanBytes = cleanup.totalBytes

        VStack(spacing: 8) {
            // [Block 1] 释放效益预演微条 (Mini 胶囊卡, 高 48pt)
            PharosBentoPulse(
                text: l10n.cleanupPulse(ByteFormat.short(cleanBytes)),
                dotLevel: cleanBytes > 0 ? .info : .normal
            )

            // [Block 2] 累计瘦身荣誉成就卡 (Hero 主力大卡, 约 140pt)
            PharosBentoCard(title: l10n.beforeAndAfter, systemImage: "arrow.left.arrow.right") {
                VStack(spacing: 6) {
                    if let vol = startup {
                        let beforePct = Int((vol.usedFraction * 100).rounded())
                        let afterUsed = vol.used > cleanBytes ? (vol.used - cleanBytes) : 0
                        let afterPct = vol.total > 0 ? Int((Double(afterUsed) / Double(vol.total) * 100).rounded()) : beforePct
                        HStack {
                            Text("\(beforePct)%")
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(PharosColor.textSecondary)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(PharosColor.textTertiary)
                            Text("\(afterPct)%")
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundStyle(PharosColor.success)
                            Spacer()
                            Text("-\(ByteFormat.short(cleanBytes))")
                                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(PharosColor.accent)
                        }
                    }

                    PharosMicroMetric(
                        label: l10n.isZh ? "待清理条目" : "Cleanable Items",
                        value: "\(cleanup.rows.count) \(l10n.isZh ? "项" : "items")",
                        unit: ByteFormat.short(cleanBytes)
                    )
                }
            }

            // [Block 3] 安全准则与一键动作卡 (Medium 卡, 约 88pt)
            PharosBentoCard(title: l10n.safetyPrinciples, systemImage: "checkmark.shield") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n.safetyPrinciplesDetail)
                        .font(.system(size: 10))
                        .foregroundStyle(PharosColor.textTertiary)
                        .lineSpacing(2)

                    PharosActionPill(title: l10n.cleanTempCachesOnly, systemImage: "sparkles", isPrimary: true) {
                        cleanup.clean(group: .temp)
                    }
                }
            }
        }
    }
}

// MARK: - 9. Project Detail & Favorites Inspector (Paradigm B: Twin-Tile Matrix)

struct ProjectDetailInspectorView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let project: Project

    var body: some View {
        let badges = ProjectTechStack.detect(directory: project.directory)

        VStack(spacing: 8) {
            // [Block 1A & 1B] 1:1 双子微方块 (高 68pt，宽 126pt × 2)
            InspectorTwinTilesRow {
                PharosBentoTile(
                    title: l10n.activePorts,
                    value: "\(project.ports.count)",
                    subtitle: project.ports.isEmpty ? (l10n.isZh ? "无端口" : "No Ports") : l10n.normalListening,
                    systemImage: "antenna.radiowaves.left.and.right",
                    dotLevel: project.ports.isEmpty ? .offline : .normal
                )
            } b: {
                PharosBentoTile(
                    title: l10n.activeThreads,
                    value: "\(project.processCount)",
                    subtitle: l10n.resourceModerate,
                    systemImage: "waveform.path.ecg",
                    dotLevel: .normal
                )
            }

            // [Block 2] 技术栈徽章与端口直达 (Hero 主力大卡, 约 150pt)
            PharosBentoCard(title: l10n.techStackFingerprint, systemImage: "cpu") {
                VStack(alignment: .leading, spacing: 6) {
                    if badges.isEmpty {
                        Text(l10n.isZh ? "纯运行时进程 (未检测到项目清单)" : "Native process (No manifest detected)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(PharosColor.textTertiary)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(badges) { badge in
                                HStack(spacing: 4) {
                                    Image(systemName: badge.systemIcon)
                                        .font(.system(size: 9))
                                        .foregroundStyle(PharosColor.accent)
                                    Text(badge.rawValue)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(PharosColor.textPrimary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(PharosColor.fill.opacity(0.5)))
                            }
                        }
                    }

                    if !project.ports.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(project.ports, id: \.self) { p in
                                HStack {
                                    Text("localhost:\(p.port)")
                                        .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                                    Spacer()
                                    Button(l10n.openInBrowser) {
                                        store.openInBrowser(p)
                                    }
                                    .font(.system(size: 10))
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }

            // [Block 3] 快捷终端跳板卡 (Medium 卡, 约 76pt)
            PharosBentoCard(title: l10n.localJumpers, systemImage: "terminal") {
                VStack(alignment: .leading, spacing: 6) {
                    PharosMicroMetric(label: l10n.memory, value: ByteFormat.short(project.memoryBytes))

                    if project.directory != nil {
                        PharosActionPill(title: l10n.revealInFinder, systemImage: "folder", isPrimary: true) {
                            store.revealInFinder(project)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 10. Customize Popover Inspector (Paradigm A: Classic Cadence)

struct CustomizePopoverInspectorView: View {
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let estHeight = PopoverHeightEstimator.estimatedHeight(blocks: layoutStore.layout.overview)

        VStack(spacing: 8) {
            // [Block 1] 小组件高度规整尺 (Mini 胶囊卡, 高 48pt)
            PharosBentoPulse(
                text: l10n.customizePulse(estHeight),
                dotLevel: .normal
            )

            // [Block 2] 风格排版预设卡 (Hero 主力大卡, 约 145pt)
            PharosBentoCard(title: l10n.recommendedPresets, systemImage: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.presetMinimal)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(PharosColor.textPrimary)
                        Text(l10n.isZh ? "内存 · 磁盘 · 温度 · 风扇" : "Memory · Disk · Thermals · Battery")
                            .font(.system(size: 10))
                            .foregroundStyle(PharosColor.textTertiary)
                    }

                    PharosActionPill(title: l10n.applyMinimalPreset, systemImage: "wand.and.stars", isPrimary: true) {
                        layoutStore.reset()
                    }
                }
            }

            // [Block 3] 渲染能耗小贴士卡 (Medium 卡, 约 70pt)
            PharosBentoCard(title: l10n.renderingFootprint, systemImage: "leaf") {
                HStack(spacing: 5) {
                    PharosStatusDot(level: .normal)
                    Text(l10n.renderingLow)
                        .font(.system(size: 10.5))
                        .foregroundStyle(PharosColor.textSecondary)
                }
            }
        }
    }
}

// MARK: - 11. Settings Inspector (Paradigm A: Classic Cadence)

struct SettingsInspectorView: View {
    @ObservedObject private var fanStore = FanStore.shared
    @ObservedObject private var batteryStore = BatteryStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(spacing: 8) {
            // [Block 1] 守护进程通信脉搏 (Mini 胶囊卡, 高 48pt)
            PharosBentoPulse(
                text: l10n.settingsPulse,
                dotLevel: .normal
            )

            // [Block 2] 守护进程健康与通信状态 (Hero 主力大卡, 约 140pt)
            PharosBentoCard(title: l10n.daemonHealthcheck, systemImage: "bolt.shield") {
                let fandActive = fanStore.helper == .ready
                let battdActive = batteryStore.helper == .ready
                VStack(spacing: 6) {
                    HStack {
                        PharosStatusDot(level: fandActive ? .normal : .offline)
                        Text(l10n.daemonFand).font(.system(size: 10.5))
                        Spacer()
                        Text(fandActive ? (l10n.isZh ? "在线" : "Active") : (l10n.isZh ? "未就绪" : "Not Ready"))
                            .font(.system(size: 10))
                            .foregroundStyle(PharosColor.textTertiary)
                    }
                    HStack {
                        PharosStatusDot(level: battdActive ? .normal : .offline)
                        Text(l10n.daemonBattd).font(.system(size: 10.5))
                        Spacer()
                        Text(battdActive ? (l10n.isZh ? "在线" : "Active") : (l10n.isZh ? "未就绪" : "Not Ready"))
                            .font(.system(size: 10))
                            .foregroundStyle(PharosColor.textTertiary)
                    }

                    PharosActionPill(title: l10n.recheckDaemons, systemImage: "arrow.clockwise", isPrimary: true) {
                        fanStore.refreshState()
                        batteryStore.refreshHelperState()
                    }
                    .padding(.top, 2)
                }
            }

            // [Block 3] 纯原生零遥测宣言 (Medium 卡, 约 78pt)
            PharosBentoCard(title: l10n.zeroTelemetrySeal, systemImage: "shield.lefthalf.filled") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.zeroTelemetryDesc)
                        .font(.system(size: 10))
                        .foregroundStyle(PharosColor.textTertiary)
                        .lineSpacing(2)

                    HStack {
                        Text(l10n.isZh ? "快捷键 ⌥ + P 唤醒" : "⌥ + P to Toggle")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(PharosColor.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }
}
