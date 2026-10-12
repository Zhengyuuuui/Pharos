import SwiftUI
import PharosCore

struct MainWindowView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var workspaces = WorkspaceStore.shared
    @ObservedObject private var router = WindowRouter.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var selection: SidebarItem?
    /// Entry point from the menu-bar popover (e.g. "Disk Cleanup").
    private let initialSelection: SidebarItem?

    init(initialSelection: SidebarItem? = nil) {
        self.initialSelection = initialSelection
    }

    enum SidebarItem: Hashable {
        case systemMemory
        case portsOverview
        case diskCleanup
        case chrome
        case favorite(String)
        case project(String)
        case settings
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section(l10n.overview) {
                    HStack {
                        Label(l10n.systemMemory, systemImage: "memorychip")
                        Spacer()
                        if let s = store.system {
                            Text("\(Int((s.usedFraction * 100).rounded()))%")
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(SidebarItem.systemMemory)
                    HStack {
                        Label(l10n.portsOverview, systemImage: "point.3.connected.trianglepath.dotted")
                        Spacer()
                        Text("\(store.totalPorts)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .tag(SidebarItem.portsOverview)
                    HStack {
                        Label(l10n.diskCleanup, systemImage: "trash")
                        Spacer()
                        Text(ByteFormat.short(cleanup.totalBytes))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .tag(SidebarItem.diskCleanup)
                    HStack {
                        Label(l10n.chromeTitle, systemImage: "globe")
                        Spacer()
                        Text("\(store.chrome.count)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .tag(SidebarItem.chrome)
                }
                Section {
                    ForEach(workspaces.statuses(store.projects), id: \.favorite.id) { s in
                        HStack(spacing: 6) {
                            RunDot(running: s.isRunning)
                            Text(s.favorite.name).lineLimit(1)
                            Spacer()
                            Text(s.isRunning
                                 ? s.ports.prefix(2).map { ":\($0.port)" }.joined(separator: " ")
                                 : l10n.stoppedShort)
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .tag(SidebarItem.favorite(s.favorite.id))
                        .contextMenu {
                            Button(l10n.openInTerminal) { workspaces.openInTerminal(s.favorite) }
                                .disabled(s.favorite.command.isEmpty)
                            Button(l10n.revealInFinder) { workspaces.revealInFinder(s.favorite) }
                            Divider()
                            Button(l10n.removeFavorite) { workspaces.unpin(id: s.favorite.id) }
                        }
                    }
                } header: {
                    HStack {
                        Text(l10n.favorites)
                        Spacer()
                        Button {
                            if let id = workspaces.addFolder() { selection = .favorite(id) }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        .help(l10n.addWorkspace)
                    }
                }
                Section(l10n.runningProjects) {
                    ForEach(store.projects) { project in
                        HStack {
                            Label(project.name, systemImage: workspaces.isPinned(project) ? "star.fill" : "shippingbox")
                                .lineLimit(1)
                            Spacer()
                            Text(ByteFormat.short(project.memoryBytes))
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .tag(SidebarItem.project(project.id))
                    }
                }
                Section {
                    Label(l10n.settings, systemImage: "gearshape")
                        .tag(SidebarItem.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    if store.lastScan != nil {
                        Text(l10n.summary(projects: store.projects.count, memory: ByteFormat.short(store.totalMemory)))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Label(l10n.refreshNow, systemImage: "arrow.clockwise")
                            .labelStyle(.titleAndIcon)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                .padding(.vertical, 8)
            }
        } detail: {
            switch selection {
            case .systemMemory:
                SystemMemoryView()
            case .portsOverview:
                PortsOverviewView(onSelect: { selection = .project($0.id) },
                                  onSelectFavorite: { selection = .favorite($0.id) })
            case .favorite(let id):
                FavoriteDetailView(favoriteId: id) { selection = .portsOverview }
            case .diskCleanup:
                CleanupView()
            case .chrome:
                ChromeView()
            case .project(let id):
                if let project = store.project(id: id) {
                    ProjectDetailView(project: project)
                } else {
                    ContentUnavailableView(l10n.noProjects, systemImage: "network.slash",
                                           description: Text(l10n.noProjectsDesc))
                }
            case .settings:
                MainSettingsView()
            case nil:
                if store.projects.isEmpty && store.lastScan != nil {
                    ContentUnavailableView(l10n.noProjects, systemImage: "network.slash",
                                           description: Text(l10n.noProjectsDesc))
                } else {
                    ContentUnavailableView(l10n.selectProject, systemImage: "shippingbox",
                                           description: Text(l10n.selectProjectDesc))
                }
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        .onAppear {
            store.viewAppeared()
            if selection == nil { selection = initialSelection ?? .portsOverview }
        }
        .onDisappear { store.viewDisappeared() }
        .onChange(of: router.request) { _, request in
            guard let request else { return }
            selection = request
            router.request = nil
        }
        .onChange(of: store.lastScan) { _, _ in
            workspaces.recordPorts(workspaces.running(in: store.projects))
        }
    }
}

struct ProjectDetailView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let project: Project

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                HStack(spacing: 12) {
                    stat(l10n.memory, ByteFormat.short(project.memoryBytes), icon: "memorychip")
                    stat(l10n.ports, "\(project.ports.count)", icon: "point.3.connected.trianglepath.dotted")
                    stat(l10n.processes, "\(project.processCount)", icon: "cpu")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.ports).font(.system(size: 13, weight: .semibold))
                    ForEach(project.ports, id: \.self) { port in
                        HStack(spacing: 8) {
                            PortChip(port: port, large: true)
                            Text(port.loopbackOnly ? l10n.localOnly : l10n.allInterfaces)
                                .font(.system(size: 11))
                                .foregroundStyle(port.loopbackOnly ? Color.secondary : Color.orange)
                            Spacer()
                            Button(l10n.openInBrowser) { store.openInBrowser(port) }
                                .controlSize(.small)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.processes).font(.system(size: 13, weight: .semibold))
                    processTable
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(1)
                if let dir = project.directory {
                    Text(dir)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                PinButton(project: project, large: true)
                if project.directory != nil {
                    Button {
                        store.revealInFinder(project)
                    } label: {
                        Label(l10n.revealInFinder, systemImage: "folder")
                    }
                    .controlSize(.small)
                }
                StopButton(project: project)
            }
        }
    }

    private func stat(_ title: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .semibold).monospacedDigit())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }

    private var processTable: some View {
        let rows = project.listeners.map { ($0, true) } + project.helpers.map { ($0, false) }
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.0.pid) { index, row in
                let (p, isListener) = row
                HStack(spacing: 10) {
                    Text(String(p.pid))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 12, weight: .medium))
                        if !p.arguments.isEmpty {
                            Text(p.arguments.joined(separator: " "))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                                .help(p.arguments.joined(separator: " "))
                        }
                    }
                    Spacer(minLength: 8)
                    if isListener {
                        PortChips(ports: p.ports)
                            .frame(maxWidth: 160, alignment: .trailing)
                            .fixedSize()
                    } else {
                        Text(l10n.helper)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Text(ByteFormat.short(p.memoryBytes))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .frame(width: 52, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(index.isMultiple(of: 2) ? Color.primary.opacity(0.03) : .clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08)))
    }
}

struct MainSettingsView: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(l10n.settings)
                    .font(.system(size: 20, weight: .bold))
                GroupBox {
                    SettingsForm()
                        .padding(12)
                        .frame(maxWidth: 400, alignment: .leading)
                }
                Text(l10n.dataNotice)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
