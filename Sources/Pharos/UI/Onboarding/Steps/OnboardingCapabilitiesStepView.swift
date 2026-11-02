import SwiftUI
import PharosCore

/// Step 02 sandbox. Every button only mutates the local `OnboardingCapabilityDemo`; nothing here calls
/// `ProjectStore.terminate`, `DiskCleaner` or any `BatteryStore` write. Only the footer reads real values.
struct OnboardingCapabilitiesStepView: View {
    let level: OnboardingMotionLevel
    @EnvironmentObject private var store: ProjectStore
    @ObservedObject private var battery = BatteryStore.shared
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var cursor = OnboardingCursorController()
    @State private var demo = OnboardingCapabilityDemo()
    @State private var selected: OnboardingCapabilityKind = .memory
    /// 0…1 sweep shown while the sandbox "cleans"; the reclaimable figure rolls down with it.
    @State private var cleanupSweep: Double = 0
    @State private var cleaning = false
    @State private var cleanupTask: Task<Void, Never>?

    private var hasBattery: Bool { battery.reading.hasBattery }
    private var lineup: [OnboardingCapabilityKind] { OnboardingCapabilityKind.lineup(hasBattery: hasBattery) }

    var body: some View {
        content.onDisappear { cleanupTask?.cancel() }
    }

    private var content: some View {
        OnboardingStepScaffold(title: l10n.onboardingCapsTitle, subtitle: l10n.onboardingCapsSubtitle, level: level) {
            OnboardingCursorStage(controller: cursor, script: .capabilities(hasBattery: hasBattery),
                                  level: level, perform: handleScripted) {
                VStack(spacing: PharosSpacing.m) {
                    tabBar
                    sandboxCard
                }
                .frame(maxWidth: 580)
            }
        }
    }

    // MARK: Tabs

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(lineup, id: \.self) { kind in
                let isOn = kind == selected
                let id = OnboardingCursorScript.Target.tab(kind)
                Button { select(kind) } label: {
                    Label(l10n.onboardingCapsTab(kind), systemImage: icon(kind))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(isOn ? PharosColor.textPrimary : PharosColor.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(Capsule(style: .continuous).fill(isOn ? PharosColor.surface : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onboardingCursorPressed(cursor.isPressed(id), level: level)
                .onboardingCursorTarget(id)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule(style: .continuous).fill(PharosColor.fill))
    }

    // MARK: Card

    private var sandboxCard: some View {
        PharosCard(padding: 16) {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack {
                    PharosTag(l10n.onboardingCapsBadge, systemImage: "hand.tap", tint: PharosColor.warning)
                    Spacer()
                    Button(l10n.onboardingCapsReset) {
                        cleanupTask?.cancel()
                        cleaning = false
                        withAnimation(anim) { demo.reset(); cleanupSweep = 0 }
                    }
                        .buttonStyle(.plain)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                        .opacity(demo.done.isEmpty ? 0 : 1)
                        .disabled(demo.done.isEmpty)
                }
                ZStack(alignment: .topLeading) {
                    panel(selected)
                        .id(selected)
                        .transition(panelTransition)
                }
                .frame(minHeight: 132, alignment: .topLeading)
                .clipped()
                PharosListDivider()
                Text(l10n.onboardingCapsLive(liveText))
                    .font(PharosFont.captionDigits)
                    .foregroundStyle(PharosColor.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func panel(_ kind: OnboardingCapabilityKind) -> some View {
        VStack(alignment: .leading, spacing: PharosSpacing.s) {
            switch kind {
            case .memory: memoryPanel
            case .ports: portsPanel
            case .power: powerPanel
            case .thermals: thermalsPanel
            case .cleanup: cleanupPanel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memoryPanel: some View {
        Group {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.onboardingCapsMemoryPressure).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                Spacer()
                Text("\(demo.memoryPercent)%")
                    .font(PharosFont.metricValue)
                    .contentTransition(.numericText(value: Double(demo.memoryPercent)))
                PharosTag(demo.memoryHealthy ? l10n.onboardingCapsMemoryHealthy : l10n.onboardingCapsMemoryHigh,
                          tint: demo.memoryHealthy ? PharosColor.success : PharosColor.warning)
            }
            bar(Double(demo.memoryPercent) / 100, tint: demo.memoryHealthy ? PharosColor.success : PharosColor.warning)
            row(icon: "gearshape.2", title: "mediaanalysisd", detail: demo.isDone(.memory) ? l10n.onboardingCapsReclaimed : "2.4 GB",
                dimmed: demo.isDone(.memory)) {
                actionButton(.memory)
            }
            caption(l10n.onboardingCapsMemoryCaption)
        }
    }

    private var portsPanel: some View {
        Group {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.onboardingCapsPortsListening).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                Spacer()
                Text("\(demo.listeningPorts)")
                    .font(PharosFont.metricValue)
                    .contentTransition(.numericText(value: Double(demo.listeningPorts)))
            }
            VStack(spacing: PharosSpacing.s) {
                OnboardingCollapsibleSection(isExpanded: !demo.isDone(.ports), level: level) {
                    row(icon: "network", title: "next-server", detail: ":3000 · 412 MB") { actionButton(.ports) }
                        .padding(.bottom, PharosSpacing.s)
                }
                row(icon: "network", title: "vite", detail: ":5173 · 186 MB") { EmptyView() }
            }
            caption(l10n.onboardingCapsPortsCaption)
        }
    }

    private var powerPanel: some View {
        let on = demo.isDone(.power)
        return Group {
            HStack(spacing: PharosSpacing.m) {
                Image(systemName: on ? "powerplug.fill" : "bolt.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(on ? PharosColor.success : PharosColor.warning)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("80% · \(l10n.onboardingCapsPluggedIn)").font(PharosFont.rowLabel)
                    HStack(spacing: 4) {
                        Text(l10n.onboardingCapsCellCurrent).foregroundStyle(PharosColor.textSecondary)
                        Text(on ? "0 mA" : "+\(demo.cellMilliamps.formatted()) mA")
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(demo.cellMilliamps)))
                    }
                    .font(PharosFont.caption)
                }
                Spacer()
                actionButton(.power)
            }
            bar(0.8, tint: on ? PharosColor.success : PharosColor.warning)
            caption(on ? l10n.onboardingCapsPowerCaptionAfter : l10n.onboardingCapsPowerCaptionBefore)
        }
    }

    private var thermalsPanel: some View {
        let detail = demo.showsThermalDetail
        let sensors: [(SensorGroup, Int)] = [(.cpu, 64), (.gpu, 58), (.ssd, 46), (.memory, 44)]
        return Group {
            HStack(spacing: PharosSpacing.l) {
                metric(l10n.onboardingCapsPeakTemp, "64°C", "thermometer.medium")
                metric(l10n.onboardingCapsFan, "1,850 rpm", "fan")
                Spacer()
                actionButton(.thermals)
            }
            OnboardingCollapsibleSection(isExpanded: detail, level: level) {
                VStack(spacing: 4) {
                    ForEach(sensors, id: \.0) { g, t in
                        HStack {
                            Text(l10n.sensorGroup(g)).font(PharosFont.caption)
                            Spacer()
                            Text("\(t)°C").font(PharosFont.captionDigits).foregroundStyle(PharosColor.textSecondary)
                        }
                    }
                }
            }
            caption(l10n.onboardingCapsThermalCaption)
        }
    }

    private var cleanupPanel: some View {
        let done = demo.isDone(.cleanup)
        let remaining = OnboardingCapabilityDemo.cacheGBBefore * (1 - cleanupSweep)
        return Group {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.onboardingCapsReclaimable).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                Spacer()
                Text(String(format: "%.1f GB", done ? 0 : remaining))
                    .font(PharosFont.metricValue)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: remaining))
                if done {
                    PharosTag(l10n.onboardingCapsFreed("6.8 GB"), systemImage: "checkmark", tint: PharosColor.success)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            bar(done ? 1 : cleanupSweep, tint: done ? PharosColor.success : PharosColor.accentFill)
            cacheRow(icon: "hammer", title: "Xcode DerivedData", gb: 4.6, done: done) { actionButton(.cleanup) }
            cacheRow(icon: "shippingbox", title: "Homebrew / npm", gb: 2.2, done: done) { EmptyView() }
            caption(l10n.onboardingCapsCleanupRule)
        }
    }

    private func cacheRow<Trailing: View>(icon: String, title: String, gb: Double, done: Bool,
                                          @ViewBuilder trailing: () -> Trailing) -> some View {
        let left = done ? 0 : gb * (1 - cleanupSweep)
        return HStack(spacing: PharosSpacing.s) {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .foregroundStyle(done ? PharosColor.success : PharosColor.textSecondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 18)
            Text(title).font(PharosFont.rowLabel).lineLimit(1)
            Text(String(format: "%.1f GB", left))
                .font(PharosFont.captionDigits)
                .foregroundStyle(done ? PharosColor.success : PharosColor.textSecondary)
                .contentTransition(.numericText(value: left))
                .lineLimit(1)
            Spacer(minLength: 4)
            trailing()
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous).fill(PharosColor.fill.opacity(0.6)))
        .opacity(done ? 0.7 : 1)
    }

    // MARK: Pieces

    private func actionButton(_ kind: OnboardingCapabilityKind) -> some View {
        let id = OnboardingCursorScript.Target.action(kind)
        let done = demo.isDone(kind)
        return Button { act(kind) } label: {
            HStack(spacing: 4) {
                if done { Image(systemName: "checkmark") }
                Text(l10n.onboardingCapsAction(kind))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(done ? PharosColor.textSecondary : PharosColor.onAccent)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule(style: .continuous).fill(done ? PharosColor.fill : PharosColor.accentFill))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(done || (kind == .cleanup && cleaning))
        .fixedSize()
        .onboardingCursorPressed(cursor.isPressed(id), level: level)
        .onboardingCursorTarget(id)
    }

    private func row<Trailing: View>(icon: String, title: String, detail: String, dimmed: Bool = false,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: PharosSpacing.s) {
            Image(systemName: icon).foregroundStyle(PharosColor.textSecondary).frame(width: 18)
            Text(title).font(PharosFont.rowLabel).lineLimit(1)
            Text(detail).font(PharosFont.captionDigits).foregroundStyle(dimmed ? PharosColor.success : PharosColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            trailing()
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous).fill(PharosColor.fill.opacity(0.6)))
    }

    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: PharosSpacing.s) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(PharosColor.textSecondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                Text(value).font(PharosFont.rowLabel).monospacedDigit()
            }
        }
    }

    private func bar(_ fraction: Double, tint: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(PharosColor.fill)
                Capsule().fill(tint).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(PharosFont.caption)
            .foregroundStyle(PharosColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func icon(_ kind: OnboardingCapabilityKind) -> String {
        switch kind {
        case .memory: "memorychip"
        case .ports: "network"
        case .power: "battery.75percent"
        case .thermals: "fan"
        case .cleanup: "sparkles"
        }
    }

    // MARK: Behaviour

    private var anim: Animation { OnboardingMotion.collapseAnimation(level) }

    private var panelTransition: AnyTransition {
        guard level != .minimal else { return .opacity }
        return .modifier(
            active: CapabilityPanelFade(opacity: 0, scale: 0.98, blur: level.allowsBlur ? 3 : 0),
            identity: CapabilityPanelFade(opacity: 1, scale: 1, blur: 0)
        )
    }

    private func select(_ kind: OnboardingCapabilityKind) {
        withAnimation(.easeOut(duration: 0.24)) { selected = kind }
    }

    private func act(_ kind: OnboardingCapabilityKind) {
        guard kind == .cleanup else { withAnimation(anim) { demo.perform(kind) }; return }
        guard !cleaning, !demo.isDone(.cleanup) else { return }
        cleaning = true
        // A few discrete steps so the figures visibly count down while the bar sweeps.
        let instant = level == .minimal
        cleanupTask = Task { @MainActor in
            if !instant {
                for i in 1...6 {
                    withAnimation(.easeInOut(duration: 0.14)) { cleanupSweep = Double(i) / 6 }
                    try? await Task.sleep(for: .milliseconds(140))
                    if Task.isCancelled { return }
                }
            }
            withAnimation(anim) { demo.perform(.cleanup) }
            cleaning = false
        }
    }

    private func handleScripted(_ id: String) {
        for kind in lineup {
            if id == OnboardingCursorScript.Target.tab(kind) { select(kind); return }
            if id == OnboardingCursorScript.Target.action(kind) { act(kind); return }
        }
    }

    private var liveText: String {
        switch selected {
        case .memory:
            return store.system.map { l10n.onboardingCapsLiveMemory(Int(($0.usedFraction * 100).rounded())) } ?? "—"
        case .ports:
            return l10n.onboardingCapsLivePorts(store.totalPorts)
        case .power:
            return l10n.onboardingCapsLiveBattery(battery.reading.currentPercent)
        case .thermals:
            return store.thermals?.peakChipTemperature.map { l10n.onboardingCapsLiveTemp("\(Int($0.rounded()))°C") } ?? "—"
        case .cleanup:
            return l10n.onboardingCapsCleanupRule
        }
    }
}

/// Cross-fade with a transient blur that is exactly 0 at rest.
private struct CapabilityPanelFade: ViewModifier {
    let opacity: Double
    let scale: Double
    let blur: Double
    func body(content: Content) -> some View {
        content.opacity(opacity).scaleEffect(scale).blur(radius: blur)
    }
}
