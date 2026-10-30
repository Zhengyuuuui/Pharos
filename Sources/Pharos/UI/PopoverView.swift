import SwiftUI
import PharosCore

struct PopoverView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @State private var showSettings = false
    @AppStorage("popoverTab") private var tab: PopoverTab = .projects
    @AppStorage("pharos.popoverGaussianBlur") private var popoverGaussianBlur: Bool = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var isAppearing = true
    @State private var isRefreshingBlur = false
    @State private var refreshTask: Task<Void, Never>? = nil

    private var isBlurActive: Bool {
        popoverGaussianBlur && !systemReduceMotion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showSettings {
                SettingsView(isPresented: $showSettings)
                    .transition(isBlurActive ? .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ) : .identity)
            } else {
                header
                PopoverTabsContent(layout: layoutStore.layout, tab: $tab)
                    .blur(radius: (isBlurActive && isRefreshingBlur) ? 3.5 : 0)
                    .animation(isBlurActive ? .easeInOut(duration: 0.25) : nil, value: isRefreshingBlur)
                Divider()
                footer
            }
        }
        .padding(14)
        .frame(width: 340)
        .blur(radius: (isBlurActive && isAppearing) ? 6.0 : 0)
        .scaleEffect((isBlurActive && isAppearing) ? 0.985 : 1.0)
        .opacity((isBlurActive && isAppearing) ? 0.7 : 1.0)
        .onAppear {
            store.viewAppeared()
            if isBlurActive {
                isAppearing = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 15_000_000)
                    withAnimation(.easeOut(duration: 0.22)) {
                        isAppearing = false
                    }
                }
            } else {
                isAppearing = false
            }
        }
        .onDisappear {
            store.viewDisappeared()
            refreshTask?.cancel()
            refreshTask = nil
            isRefreshingBlur = false
            isAppearing = true
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(l10n.appTitle)
                .font(.system(size: 14, weight: .bold))
            Spacer()
            if store.lastScan != nil {
                Text(l10n.summary(projects: store.projects.count, memory: ByteFormat.short(store.totalMemory)))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                triggerRefreshBlur()
                Task { await store.refresh() }
            } label: {
                HStack {
                    RefreshIcon(activity: store.activity)
                    Text(l10n.refreshNow)
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(l10n.updated(Format.relativeAge(store.lastScan, now: ctx.date)))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(RowButtonStyle())

            menuRow(l10n.agentChats, icon: "bubble.left.and.text.bubble.right") {
                AppDelegate.shared?.showMainWindow(selecting: .agentChats)
            }
            menuRow(l10n.diskCleanup, icon: "trash") {
                AppDelegate.shared?.showMainWindow(selecting: .diskCleanup)
            }
            menuRow(l10n.packagesTitle, icon: "shippingbox.fill") {
                AppDelegate.shared?.showMainWindow(selecting: .packages)
            }
            menuRow(l10n.customizePopover, icon: "square.grid.2x2") {
                AppDelegate.shared?.showMainWindow(selecting: .customize)
            }
            menuRow(l10n.settingsEllipsis, icon: "gearshape") {
                withAnimation(.easeOut(duration: 0.2)) { showSettings = true }
            }
            menuRow(l10n.mainWindow, icon: "macwindow") {
                AppDelegate.shared?.showMainWindow()
            }
            menuRow(l10n.quit, icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func triggerRefreshBlur() {
        guard isBlurActive else { return }
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            withAnimation(.easeIn(duration: 0.10)) {
                isRefreshingBlur = true
            }
            try? await Task.sleep(nanoseconds: 160_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.25)) {
                isRefreshingBlur = false
            }
        }
    }

    private func menuRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(.system(size: 11))
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
    }
}

/// Tab picker + the blocks of the selected tab, following the saved layout.
/// A tab with no blocks is hidden; with one tab left, the picker disappears.
struct PopoverTabsContent: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let layout: PopoverLayout
    @Binding var tab: PopoverTab
    /// false in the Customize preview: blocks render but don't take clicks.
    var interactive = true

    @AppStorage("pharos.popoverGaussianBlur") private var popoverGaussianBlur: Bool = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var isSwitchingTab = false
    @State private var switchTask: Task<Void, Never>? = nil
    @State private var contentHeight: CGFloat = 200

    private var isBlurActive: Bool {
        interactive && popoverGaussianBlur && !systemReduceMotion
    }

    var body: some View {
        let tabs = layout.visibleTabs
        let current = tabs.contains(tab) ? tab : (tabs.first ?? .overview)
        VStack(alignment: .leading, spacing: 10) {
            if tabs.count > 1 {
                Picker("", selection: $tab) {
                    ForEach(tabs, id: \.self) { Text(l10n.popoverTabName($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            if store.lastScan == nil {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(l10n.loading).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if tabs.isEmpty {
                Text(l10n.popoverEmpty).font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                let maxH = maxAllowedHeight(for: layout[current], limit: layout.visibleProjectRows)
                let isScrollNeeded = contentHeight > maxH
                ScrollView {
                    PopoverBlockStack(blocks: layout[current])
                        .allowsHitTesting(interactive)
                        .padding(.trailing, 6)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                        })
                        .background(SlimScrollerAttacher())
                }
                .scrollDisabled(!isScrollNeeded)
                // Grow with the content, scroll past maxH pt.
                .frame(height: min(max(contentHeight, 40), maxH))
                .animation(isBlurActive ? .spring(response: 0.28, dampingFraction: 0.85) : nil, value: contentHeight)
                .blur(radius: (isBlurActive && isSwitchingTab) ? 5.0 : 0)
                .opacity((isBlurActive && isSwitchingTab) ? 0.75 : 1.0)
                .scaleEffect((isBlurActive && isSwitchingTab) ? 0.99 : 1.0)
                .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
            }
        }
        .onChange(of: current) { _, _ in
            guard isBlurActive else { return }
            switchTask?.cancel()
            switchTask = Task { @MainActor in
                isSwitchingTab = true
                try? await Task.sleep(nanoseconds: 25_000_000)
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: 0.20)) {
                    isSwitchingTab = false
                }
            }
        }
        .onDisappear {
            switchTask?.cancel()
            switchTask = nil
            isSwitchingTab = false
        }
    }

    private func maxAllowedHeight(for blocks: [PopoverBlock], limit: Int) -> CGFloat {
        let standardMax: CGFloat = 520
        // When tab strictly contains only running projects, align maximum viewport height with visibleProjectRows limit
        if blocks == [.projects], limit > 0 {
            let rowEstimate: CGFloat = 56
            let target = CGFloat(limit) * rowEstimate + 4
            return min(max(target, 160), standardMax)
        }
        return standardMax
    }
}

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct PopoverProjectRow: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let project: Project
    let fraction: Double
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(project.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                Text(ByteFormat.short(project.memoryBytes))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                PinButton(project: project)
                if project.directory != nil {
                    IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                        store.revealInFinder(project)
                    }
                }
                StopButton(project: project, compact: true)
            }
            HStack(alignment: .top, spacing: 6) {
                PortChips(ports: project.ports)
                Spacer(minLength: 0)
                Text(project.startCommand)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150, alignment: .trailing)
                    .help(project.startCommand)
            }
            MemoryBar(fraction: fraction)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? Color.primary.opacity(0.05) : .clear)
        )
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
        .help(project.directory ?? project.name)
    }
}

/// Two-step stop: first click arms, second click sends SIGTERM. If the project
/// survives SIGTERM the button becomes a force kill.
struct StopButton: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let project: Project
    var compact = false
    @State private var armed = false

    var body: some View {
        if store.stubborn.contains(project.id) {
            Button(l10n.forceKill) { store.forceKill(project) }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
                .help(l10n.stillRunning)
        } else if armed {
            HStack(spacing: 4) {
                Button(compact ? l10n.stop : l10n.stopProject) {
                    armed = false
                    store.terminate(project)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
                IconButton(systemImage: "xmark", help: l10n.cancel) { armed = false }
            }
            .task {
                try? await Task.sleep(for: .seconds(4))
                armed = false
            }
        } else if compact {
            IconButton(systemImage: "stop.circle", help: l10n.stop, tint: .red.opacity(0.8)) {
                armed = true
            }
        } else {
            Button(role: .destructive) { armed = true } label: {
                Label(l10n.stopProject, systemImage: "stop.circle")
            }
            .controlSize(.small)
        }
    }
}

private struct RefreshIcon: View {
    @ObservedObject var activity: ScanActivity

    var body: some View {
        if activity.isScanning {
            ProgressView().controlSize(.mini)
        } else {
            Image(systemName: "arrow.clockwise").font(.system(size: 11))
        }
    }
}

/// An ultra-slim (3.5pt), highly refined custom overlay scroller designed specifically for menu bar popovers.
/// Eliminates the thick default macOS scroller and prevents obstructing buttons or text.
final class SlimPopoverScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override func drawKnob() {
        let knobRect = self.rect(for: .knob)
        guard knobRect.width > 0, knobRect.height > 0 else { return }

        let slimWidth: CGFloat = 3.5
        let rightMargin: CGFloat = 2.0
        let x = bounds.width - slimWidth - rightMargin
        let y = knobRect.origin.y + 2
        let h = max(16, knobRect.height - 4)

        let pillRect = NSRect(x: x, y: y, width: slimWidth, height: h)
        let path = NSBezierPath(roundedRect: pillRect, xRadius: slimWidth / 2, yRadius: slimWidth / 2)

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let color = isDark ? NSColor.white.withAlphaComponent(0.40) : NSColor.black.withAlphaComponent(0.30)
        color.setFill()
        path.fill()
    }

    override func drawKnobSlot(in rect: NSRect, highlight: Bool) {
        // Keep track background completely invisible
    }
}

private struct SlimScrollerAttacher: NSViewRepresentable {
    func makeNSView(context: Context) -> SlimScrollerNSView {
        SlimScrollerNSView()
    }
    func updateNSView(_ nsView: SlimScrollerNSView, context: Context) {
        nsView.attach()
    }
}

private final class SlimScrollerNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attach()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        attach()
    }

    func attach() {
        guard let sv = enclosingScrollView else { return }
        if !(sv.verticalScroller is SlimPopoverScroller) {
            let s = SlimPopoverScroller()
            sv.verticalScroller = s
            sv.scrollerStyle = .overlay
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
