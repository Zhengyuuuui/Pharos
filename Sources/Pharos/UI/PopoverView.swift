import SwiftUI
import PharosCore

struct PopoverView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @State private var showSettings = false
    @AppStorage("popoverTab") private var tab: PopoverTab = .projects

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showSettings {
                SettingsView(isPresented: $showSettings)
            } else {
                header
                PopoverTabsContent(layout: layoutStore.layout, tab: $tab)
                Divider()
                footer
            }
        }
        .padding(14)
        .frame(width: 340)
        .onAppear { store.viewAppeared() }
        .onDisappear { store.viewDisappeared() }
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

            menuRow(l10n.diskCleanup, icon: "trash") {
                AppDelegate.shared?.showMainWindow(selecting: .diskCleanup)
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
                ScrollView {
                    PopoverBlockStack(blocks: layout[current])
                        .allowsHitTesting(interactive)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                        })
                }
                // Grow with the content, scroll past 520 pt.
                .frame(height: min(max(contentHeight, 40), 520))
                .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
            }
        }
    }

    @State private var contentHeight: CGFloat = 200
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
                Text(project.listeners.first?.shortCommand ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 130, alignment: .trailing)
            }
            MemoryBar(fraction: fraction)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering ? Color.primary.opacity(0.05) : .clear)
        )
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
