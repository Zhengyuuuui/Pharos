import SwiftUI
import PharosCore

/// A self-contained mock of the menu bar and popover with fixed sample data, so the page looks the
/// same on every Mac regardless of the user's own menu bar text or popover layout.
struct OnboardingMenuBarStepView: View {
    let level: OnboardingMotionLevel
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var cursor = OnboardingCursorController()
    /// Reduce Motion shows the popover open; otherwise the cursor opens it from the icon.
    @State private var expanded: Bool
    @State private var tab: PopoverTab = .overview

    init(level: OnboardingMotionLevel) {
        self.level = level
        _expanded = State(initialValue: level == .minimal)
    }

    var body: some View {
        OnboardingStepScaffold(title: l10n.onboardingMenuBarTitle, subtitle: l10n.onboardingMenuBarSubtitle, level: level) {
            HStack(alignment: .top, spacing: PharosSpacing.xl) {
                OnboardingCursorStage(controller: cursor, script: .menuBar(hasSecondTab: true),
                                      level: level, perform: handleScripted) {
                    VStack(alignment: .trailing, spacing: PharosSpacing.s) {
                        menuBarStrip
                        if expanded {
                            popover.transition(popoverTransition)
                        }
                    }
                    .frame(width: 320, height: 285, alignment: .top)
                }
                .animation(OnboardingMotion.stepAnimation(level), value: expanded)

                VStack(alignment: .leading, spacing: PharosSpacing.m) {
                    tip("circle.dashed", l10n.onboardingMenuBarTipRing)
                    tip("moon.zzz", l10n.onboardingMenuBarTipBackground)
                    tip("bolt.batteryblock", l10n.onboardingMenuBarTipFull)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, PharosSpacing.s)
            }
            .frame(maxWidth: 620)
        }
    }

    // MARK: Sample data (real model types, so the real chart/badge/chip views render them)

    private static let gb: UInt64 = 1_073_741_824
    private static let mb: UInt64 = 1_048_576
    private static let sampleMemory = SystemMemoryStats(
        total: 16 * gb, appMemory: 5 * gb + 200 * mb, wired: 2 * gb + 100 * mb, compressed: 900 * mb,
        cachedFiles: 3 * gb + 400 * mb, swapUsed: 300 * mb, swapTotal: 1 * gb, pressure: .normal)

    private static func sampleProject(_ name: String, pid: Int32, ports: [UInt16], args: [String], mem: UInt64) -> Project {
        let listening = ports.map { ListeningPort(port: $0, loopbackOnly: true) }
        // directory nil: startCommand falls back to the arguments and never touches the disk.
        let p = ProcessSnapshot(pid: pid, ppid: 1, name: args.first ?? name, arguments: args, memoryBytes: mem, ports: listening)
        return Project(id: name, name: name, directory: nil, listeners: [p], helpers: [], ports: listening, memoryBytes: mem)
    }

    private static let sampleProjects: [Project] = [
        sampleProject("web-dashboard", pid: 101, ports: [3000], args: ["node", "next", "dev"], mem: 412 * mb),
        sampleProject("api-server", pid: 103, ports: [8080, 9229], args: ["python3", "manage.py", "runserver"], mem: 128 * mb),
    ]

    private var samplePorts: Int { Self.sampleProjects.reduce(0) { $0 + $1.ports.count } }
    private var sampleTotal: UInt64 { Self.sampleProjects.reduce(0) { $0 + $1.memoryBytes } }

    // MARK: Menu bar

    private var menuBarStrip: some View {
        let s = Self.sampleMemory
        return HStack(spacing: PharosSpacing.m) {
            Text(l10n.onboardingMenuBarClickHint)
                .font(PharosFont.caption)
                .foregroundStyle(PharosColor.textTertiary)
            Spacer()
            Button { expanded.toggle() } label: {
                // Same icon renderer and number format as the real status item.
                HStack(spacing: 4) {
                    Image(nsImage: DynamicMenuBarIcon.image(fraction: s.usedFraction, pressure: s.pressure))
                    Text("\(Int((s.usedFraction * 100).rounded()))%").monospacedDigit()
                }
                .font(.system(size: 13))
                .padding(.horizontal, 6)
                .frame(height: 20)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(expanded ? PharosColor.fillPressed : .clear))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onboardingCursorPressed(cursor.isPressed(OnboardingCursorScript.Target.menuBarIcon), level: level)
            .onboardingCursorTarget(OnboardingCursorScript.Target.menuBarIcon)
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("9:41").font(.system(size: 12, weight: .medium).monospacedDigit())
        }
        .font(.system(size: 12))
        .foregroundStyle(PharosColor.textPrimary)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous).fill(.bar))
        .overlay(RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
            .strokeBorder(PharosColor.separator.opacity(0.6), lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    // MARK: Popover (mirrors PopoverView: header, segmented tabs, blocks, footer)

    private var popover: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.appTitle).font(.system(size: 14, weight: .bold))
                Spacer()
                Text(l10n.summary(projects: Self.sampleProjects.count, memory: ByteFormat.short(sampleTotal)))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            tabPicker
            ZStack(alignment: .topLeading) {
                Group {
                    switch tab {
                    case .overview: overview
                    case .projects: projects
                    }
                }
                .id(tab)
                .transition(tabTransition)
            }
            .frame(height: 148, alignment: .top)
            .clipped()
            .allowsHitTesting(false)
            .animation(OnboardingMotion.collapseAnimation(level), value: tab)
            Divider()
            HStack {
                Image(systemName: "arrow.clockwise").font(.system(size: 11))
                Text(l10n.refreshNow)
                Spacer()
                Text(l10n.onboardingMenuDemoSample).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .font(.system(size: 11))
            .frame(height: 16)
            .padding(.horizontal, PharosSpacing.s)
        }
        .padding(10)
        .frame(width: 320, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(PharosColor.separator.opacity(0.6), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    /// Same control as the real popover; the second segment's slice is the cursor target.
    private var tabPicker: some View {
        Picker("", selection: $tab) {
            Text(l10n.popoverTabName(.overview)).tag(PopoverTab.overview)
            Text(l10n.popoverTabName(.projects)).tag(PopoverTab.projects)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .overlay(alignment: .leading) {
            GeometryReader { geo in
                let w = geo.size.width / 2
                Color.clear
                    .frame(width: w, height: geo.size.height)
                    .offset(x: w)
                    .onboardingCursorTarget(OnboardingCursorScript.Target.menuBarSecondTab)
            }
            .allowsHitTesting(false)
        }
    }

    /// Mirrors `MemoryBlock` + `DevProjectsBlock`.
    private var overview: some View {
        let s = Self.sampleMemory
        return VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.systemMemory).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(ByteFormat.short(s.used)) / \(ByteFormat.short(s.total))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                    Text("· \(l10n.availableMemory) \(ByteFormat.short(s.available))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.green)
                }
                MemoryCompositionBar(stats: s, height: 8, showLegend: false)
                HStack {
                    PressureBadge(pressure: s.pressure)
                    Spacer()
                    Text("\(l10n.swapUsed) \(ByteFormat.short(s.swapUsed))")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.devProjects).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(samplePorts) \(l10n.ports) · \(ByteFormat.short(sampleTotal))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                }
                ProjectMemoryBars(projects: Self.sampleProjects)
            }
        }
    }

    /// Mirrors `PopoverProjectRow` (buttons drawn, never wired to the store).
    private var projects: some View {
        let maxMem = Self.sampleProjects.map(\.memoryBytes).max() ?? 1
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Self.sampleProjects, id: \.id) { p in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(p.name).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(ByteFormat.short(p.memoryBytes))
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Image(systemName: "star").font(.system(size: 11)).foregroundStyle(.secondary)
                        Image(systemName: "folder").font(.system(size: 11)).foregroundStyle(.secondary)
                        Image(systemName: "stop.circle").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        PortChips(ports: p.ports)
                        Spacer(minLength: 0)
                        Text(p.startCommand)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    MemoryBar(fraction: Double(p.memoryBytes) / Double(maxMem))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
            }
        }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: PharosSpacing.s) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(PharosColor.textSecondary)
                .frame(width: 20)
            Text(text)
                .font(PharosFont.caption)
                .foregroundStyle(PharosColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Motion

    private var popoverTransition: AnyTransition {
        guard level != .minimal else { return .opacity }
        return .modifier(
            active: DemoPopFade(opacity: 0, scale: 0.94, blur: level.allowsBlur ? 4.5 : 0, anchor: .topTrailing),
            identity: DemoPopFade(opacity: 1, scale: 1, blur: 0, anchor: .topTrailing)
        )
    }

    private var tabTransition: AnyTransition {
        guard level != .minimal else { return .opacity }
        return .modifier(
            active: DemoPopFade(opacity: 0, scale: 0.98, blur: level.allowsBlur ? 3 : 0, anchor: .top),
            identity: DemoPopFade(opacity: 1, scale: 1, blur: 0, anchor: .top)
        )
    }

    private func handleScripted(_ id: String) {
        switch id {
        case OnboardingCursorScript.Target.menuBarIcon: expanded = true
        case OnboardingCursorScript.Target.menuBarSecondTab: tab = .projects
        default: break
        }
    }
}

/// Blur is exactly 0 at rest.
private struct DemoPopFade: ViewModifier {
    let opacity: Double
    let scale: Double
    let blur: Double
    let anchor: UnitPoint
    func body(content: Content) -> some View {
        content.opacity(opacity).scaleEffect(scale, anchor: anchor).blur(radius: blur)
    }
}
