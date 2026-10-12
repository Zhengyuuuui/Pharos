import SwiftUI
import PharosCore

struct PopoverView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @State private var showSettings = false
    @AppStorage("popoverTab") private var tab: Tab = .projects

    enum Tab: String { case overview, projects }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showSettings {
                SettingsView(isPresented: $showSettings)
            } else {
                header
                Picker("", selection: $tab) {
                    Text(l10n.overview).tag(Tab.overview)
                    Text(l10n.projects).tag(Tab.projects)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if tab == .overview {
                    PopoverOverview()
                } else {
                    content
                }
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

    @ViewBuilder
    private var content: some View {
        if store.lastScan == nil {
            HStack {
                ProgressView().controlSize(.small)
                Text(l10n.loading).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            let chromeEntries = ChromeStore.shared.entries(store.chrome)
            let maxMem = store.projects.map(\.memoryBytes).max() ?? 1
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if store.projects.isEmpty {
                        emptyProjects
                    } else {
                        ForEach(store.projects) { project in
                            PopoverProjectRow(project: project,
                                              fraction: Double(project.memoryBytes) / Double(max(1, maxMem)))
                        }
                    }
                    if !chromeEntries.isEmpty {
                        PopoverChromeSection(entries: chromeEntries)
                            .padding(.top, 8)
                    }
                }
            }
            .frame(maxHeight: 460)
            .fixedSize(horizontal: false, vertical: store.projects.count + chromeEntries.count <= 7)
        }
    }

    private var emptyProjects: some View {
        VStack(spacing: 4) {
            Image(systemName: "network.slash")
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
            Text(l10n.noProjects)
                .font(.system(size: 12, weight: .medium))
            Text(l10n.noProjectsDesc)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
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

/// Compact version of the main window's overview pages.
struct PopoverOverview: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let s = store.system {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(l10n.systemMemory).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(ByteFormat.short(s.used)) / \(ByteFormat.short(s.total))")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                        Text("· \(l10n.availableMemory) \(ByteFormat.short(s.available))")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(.green)
                    }
                    MemoryCompositionBar(stats: s, height: 10, showLegend: false)
                    HStack {
                        PressureBadge(pressure: s.pressure)
                        Spacer()
                        Text("\(l10n.swapUsed) \(ByteFormat.short(s.swapUsed))")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if store.history.samples.count >= 2 {
                        SystemTrendChart(samples: store.history.samples, total: s.total, compact: true)
                            .frame(height: 70)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.devProjects).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(store.totalPorts) \(l10n.ports) · \(ByteFormat.short(store.totalMemory))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                }
                if store.history.samples.count >= 2 && !store.projects.isEmpty {
                    DevTrendChart(history: store.history, limit: 5, compact: true)
                        .frame(height: 80)
                }
                if !store.projects.isEmpty {
                    ProjectMemoryBars(projects: Array(store.projects.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(5)))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.topApps).font(.system(size: 12, weight: .semibold))
                ForEach(store.apps.prefix(5)) { app in
                    HStack {
                        Text(app.name).font(.system(size: 11)).lineLimit(1)
                        Spacer()
                        Text(ByteFormat.short(app.memoryBytes))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
