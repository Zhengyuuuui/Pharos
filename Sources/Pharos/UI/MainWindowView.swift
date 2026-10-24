import SwiftUI
import PharosCore

struct MainWindowView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var workspaces = WorkspaceStore.shared
    @ObservedObject private var agentStore = AgentChatStore.shared
    @ObservedObject private var packageStore = PackageStore.shared
    @ObservedObject private var router = WindowRouter.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var selection: SidebarItem?
    @State private var sidebarScrollOffset: CGFloat = 0
    /// Entry point from the menu-bar popover (e.g. "Disk Cleanup").
    private let initialSelection: SidebarItem?

    init(initialSelection: SidebarItem? = nil) {
        self.initialSelection = initialSelection
    }

    enum SidebarItem: Hashable {
        case systemMemory
        case diskUsage
        case batteryAndThermals
        case portsOverview
        case diskCleanup
        case chrome
        case agentChats
        case packages
        case favorite(String)
        case project(String)
        case customize
        case settings
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // 1. Floating Sidebar Island (圆角矩形悬浮浮岛，内置交通灯)
            sidebarIsland
                .frame(width: 236)
                .frame(maxHeight: .infinity)
                .background(PharosColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PharosColor.separator.opacity(0.35), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 6)

            // 2. Detail Canvas
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
        .background(PharosColor.windowGradient)
        .ignoresSafeArea()
        .frame(minWidth: 940, minHeight: 620)
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

    private var sidebarScrollProgress: CGFloat {
        min(1.0, max(0.0, -sidebarScrollOffset / 16.0))
    }

    private var sidebarIsland: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: SidebarScrollOffsetKey.self,
                            value: geo.frame(in: .named("sidebarScroll")).minY
                        )
                    }
                    .frame(height: 0)

                    // Top: Dashboard Hero Item
                    PharosSidebarRow(
                        icon: "square.grid.2x2",
                        title: l10n.dashboard,
                        badge: store.totalPorts > 0 ? "\(store.totalPorts)" : nil,
                        isSelected: selection == .portsOverview
                    ) {
                        selection = .portsOverview
                    }

                    PharosListDivider()
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)

                    // Group 1: 系统与硬件 (System & Hardware)
                    PharosSidebarSectionHeader(title: l10n.systemAndHardware)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                        .padding(.bottom, 2)

                    PharosSidebarRow(
                        icon: "memorychip",
                        title: l10n.systemMemory,
                        badge: store.system.map { "\(Int(($0.usedFraction * 100).rounded()))%" },
                        isSelected: selection == .systemMemory
                    ) {
                        selection = .systemMemory
                    }

                    PharosSidebarRow(
                        icon: "internaldrive",
                        title: l10n.diskUsage,
                        badge: store.volumes.first(where: { $0.kind == .startup }).map { "\(Int(($0.usedFraction * 100).rounded()))%" },
                        extraBadge: {
                            let extra = store.volumes.filter { $0.kind == .external || $0.kind == .network }.count
                            return extra > 0 ? "+\(extra)" : nil
                        }(),
                        isSelected: selection == .diskUsage
                    ) {
                        selection = .diskUsage
                    }

                    BatteryAndThermalSidebarRow(isSelected: selection == .batteryAndThermals) {
                        selection = .batteryAndThermals
                    }

                    // Group 2: 环境与运行时 (Runtime & Services)
                    PharosSidebarSectionHeader(title: l10n.runtimeAndServices)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    PharosSidebarRow(
                        icon: "shippingbox",
                        title: l10n.packagesTitle,
                        badge: packageStore.globalCliCount > 0 ? "\(packageStore.globalCliCount)" : nil,
                        isSelected: selection == .packages
                    ) {
                        selection = .packages
                    }

                    PharosSidebarRow(
                        icon: "globe",
                        title: l10n.chromeTitle,
                        badge: {
                            let browserCount = store.chrome.filter { ChromeStore.shared.isVisible($0.config.browser) }.count
                            return browserCount > 0 ? "\(browserCount)" : nil
                        }(),
                        isSelected: selection == .chrome
                    ) {
                        selection = .chrome
                    }

                    PharosSidebarRow(
                        icon: "bubble.left.and.text.bubble.right",
                        title: l10n.agentChats,
                        badge: agentStore.totalDatabases > 0 ? "\(agentStore.totalDatabases)" : nil,
                        badgeIcon: agentStore.orphanedCount > 0 ? "exclamationmark.triangle.fill" : nil,
                        badgeColor: PharosColor.warning,
                        isSelected: selection == .agentChats
                    ) {
                        selection = .agentChats
                    }

                    // Group 3: 系统维护 (Maintenance)
                    PharosSidebarSectionHeader(title: l10n.systemMaintenance)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    PharosSidebarRow(
                        icon: "trash",
                        title: l10n.diskCleanup,
                        badge: cleanup.totalBytes > 0 ? ByteFormat.short(cleanup.totalBytes) : nil,
                        isSelected: selection == .diskCleanup
                    ) {
                        selection = .diskCleanup
                    }

                    // Group 4: 常用项目 (Favorites)
                    if !workspaces.favorites.isEmpty {
                        PharosSidebarSectionHeader(title: l10n.favorites) {
                            Button {
                                if let id = workspaces.addFolder() { selection = .favorite(id) }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.borderless)
                            .help(l10n.addWorkspace)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                        ForEach(workspaces.statuses(store.projects), id: \.favorite.id) { s in
                            FavoriteSidebarRow(
                                status: s,
                                isSelected: selection == .favorite(s.favorite.id)
                            ) {
                                selection = .favorite(s.favorite.id)
                            }
                            .contextMenu {
                                Button(l10n.openInTerminal) { workspaces.openInTerminal(s.favorite) }
                                    .disabled(s.favorite.command.isEmpty)
                                Button(l10n.revealInFinder) { workspaces.revealInFinder(s.favorite) }
                                Divider()
                                Button(l10n.removeFavorite) { workspaces.unpin(id: s.favorite.id) }
                            }
                        }
                    }

                    // Group 5: 运行中进程 (Running Projects)
                    if !store.projects.isEmpty {
                        PharosSidebarSectionHeader(title: l10n.runningProjects)
                            .padding(.horizontal, 10)
                            .padding(.top, 6)
                            .padding(.bottom, 2)

                        ForEach(store.projects) { project in
                            ProjectSidebarRow(
                                project: project,
                                isPinned: workspaces.isPinned(project),
                                isSelected: selection == .project(project.id)
                            ) {
                                selection = .project(project.id)
                            }
                        }
                    }

                    // Group 6: 外观与设置 (Appearance)
                    PharosSidebarSectionHeader(title: l10n.appearance)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    PharosSidebarRow(
                        icon: "slider.horizontal.3",
                        title: l10n.customizeTitle,
                        isSelected: selection == .customize
                    ) {
                        selection = .customize
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 38)
                .padding(.bottom, 12)
            }
            .coordinateSpace(name: "sidebarScroll")
            .onPreferenceChange(SidebarScrollOffsetKey.self) { offset in
                sidebarScrollOffset = offset
            }
            .overlay(alignment: .topLeading) {
                sidebarTrafficLightsBlurHeader
                    .allowsHitTesting(false)
            }

            sidebarBottomIsland
        }
    }

    private var sidebarTrafficLightsBlurHeader: some View {
        let p = sidebarScrollProgress
        return ZStack(alignment: .topLeading) {
            // 1. Progressive top blur & soft diffused shadow when scrolling text under traffic lights
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(PharosColor.surface.opacity(0.55))
            }
            .frame(height: 46)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black.opacity(0.92), location: 0.52),
                        .init(color: .black.opacity(0.38), location: 0.80),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Color.black.opacity(0.14 * p), radius: 8, x: 0, y: 4)
            .opacity(Double(max(0.2, p)))

            // 2. Frosted capsule & blurred shadow halo surrounding the 3 traffic lights
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(PharosColor.surface.opacity(0.45 + 0.25 * p))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(PharosColor.separator.opacity(0.16 + 0.34 * p), lineWidth: 0.5)
                )
                .frame(width: 68, height: 24)
                .shadow(color: Color.black.opacity(0.05 + 0.18 * p), radius: 3 + 7 * p, x: 0, y: 1 + 2 * p)
                .shadow(color: Color.black.opacity(0.10 * p), radius: 12 * p, x: 0, y: 4 * p)
                .offset(x: 2, y: 4)
        }
    }

    private var detailView: some View {
        Group {
            switch selection {
            case .systemMemory:
                SystemMemoryView()
            case .diskUsage:
                DiskUsageView()
            case .batteryAndThermals:
                BatteryAndThermalView()
            case .portsOverview:
                PortsOverviewView(onSelect: { selection = .project($0.id) },
                                  onSelectFavorite: { selection = .favorite($0.id) })
            case .favorite(let id):
                FavoriteDetailView(favoriteId: id) { selection = .portsOverview }
            case .diskCleanup:
                CleanupView()
            case .chrome:
                ChromeView()
            case .agentChats:
                AgentChatView()
            case .packages:
                PackageView()
            case .project(let id):
                if let project = store.project(id: id) {
                    ProjectDetailView(project: project)
                } else {
                    ContentUnavailableView(l10n.noProjects, systemImage: "network.slash",
                                           description: Text(l10n.noProjectsDesc))
                }
            case .customize:
                CustomizePopoverView()
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
        .buttonStyle(.pharos)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebarBottomIsland: some View {
        HStack(spacing: PharosSpacing.s) {
            // Circle button 1: Quick refresh
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PharosColor.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(PharosColor.fill))
                    .overlay(Circle().stroke(PharosColor.separator.opacity(0.35), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help(l10n.refreshNow)

            // Circle button 2: Settings
            Button {
                selection = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(selection == .settings ? PharosColor.accent : PharosColor.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(selection == .settings ? PharosColor.accent.opacity(0.14) : PharosColor.fill))
                    .overlay(Circle().stroke(selection == .settings ? PharosColor.accent.opacity(0.4) : PharosColor.separator.opacity(0.35), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help(l10n.settings)

            Spacer(minLength: 4)

            // Status Pill (inspired by the green pill in reference image)
            Button {
                Task { await store.refresh() }
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(store.projects.isEmpty ? Color.secondary.opacity(0.4) : Color.green)
                        .frame(width: 6, height: 6)
                    Text(store.projects.isEmpty
                         ? l10n.notRunning
                         : "\(store.projects.count) \(l10n.projects)")
                        .font(PharosFont.captionDigits)
                        .fontWeight(.medium)
                        .foregroundStyle(PharosColor.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(store.projects.isEmpty ? PharosColor.fill : Color.green.opacity(0.14))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(store.projects.isEmpty ? PharosColor.separator.opacity(0.3) : Color.green.opacity(0.35), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help(l10n.summary(projects: store.projects.count, memory: ByteFormat.short(store.totalMemory)))
        }
        .padding(.horizontal, PharosSpacing.m)
        .padding(.top, PharosSpacing.s)
        .padding(.bottom, PharosSpacing.s + 4)
        .background(
            VStack(spacing: 0) {
                PharosListDivider()
                PharosColor.surface
            }
        )
    }
}

struct ProjectDetailView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let project: Project

    var body: some View {
        PharosPage {
            header
        } content: {
            metricsGrid

            if !project.ports.isEmpty {
                portsSection
            }

            processesSection
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                Text(project.name)
                    .font(PharosFont.pageTitle)
                    .foregroundStyle(PharosColor.textPrimary)
                    .lineLimit(1)
                if let dir = project.directory {
                    Text(dir)
                        .font(PharosFont.technical)
                        .foregroundStyle(PharosColor.textSecondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            Spacer()
            HStack(spacing: PharosSpacing.s) {
                PinButton(project: project, large: true)
                if project.directory != nil {
                    Button {
                        store.revealInFinder(project)
                    } label: {
                        Label(l10n.revealInFinder, systemImage: "folder")
                    }
                    .buttonStyle(.pharos)
                    .controlSize(.small)
                }
                StopButton(project: project)
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: PharosSpacing.m),
            GridItem(.flexible(), spacing: PharosSpacing.m),
            GridItem(.flexible(), spacing: PharosSpacing.m)
        ], spacing: PharosSpacing.m) {
            PharosCard {
                PharosMetricValue(
                    title: l10n.memory,
                    value: ByteFormat.short(project.memoryBytes),
                    systemImage: "memorychip"
                )
            }
            PharosCard {
                PharosMetricValue(
                    title: l10n.ports,
                    value: "\(project.ports.count)",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            }
            PharosCard {
                PharosMetricValue(
                    title: l10n.processes,
                    value: "\(project.processCount)",
                    systemImage: "cpu"
                )
            }
        }
    }

    private var portsSection: some View {
        PharosSection(title: l10n.ports, systemImage: "point.3.connected.trianglepath.dotted") {
            VStack(spacing: 0) {
                ForEach(project.ports.indices, id: \.self) { index in
                    let port = project.ports[index]
                    if index > 0 {
                        PharosListDivider()
                    }
                    HStack(spacing: PharosSpacing.s) {
                        PortChip(port: port, large: true)
                        Text(port.loopbackOnly ? l10n.localOnly : l10n.allInterfaces)
                            .font(PharosFont.caption)
                            .foregroundStyle(port.loopbackOnly ? PharosColor.textSecondary : PharosColor.warning)
                        Spacer()
                        PharosActionButton(l10n.openInBrowser, systemImage: "safari", role: .standard) {
                            store.openInBrowser(port)
                        }
                        .controlSize(.small)
                    }
                    .padding(.vertical, PharosSpacing.s)
                }
            }
        }
    }

    private var processesSection: some View {
        let rows = project.listeners.map { ($0, true) } + project.helpers.map { ($0, false) }
        return PharosSection(title: l10n.processes, systemImage: "cpu") {
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    let (p, isListener) = rows[index]
                    if index > 0 {
                        PharosListDivider()
                    }
                    HStack(spacing: PharosSpacing.m) {
                        Text(String(p.pid))
                            .font(PharosFont.technical)
                            .foregroundStyle(PharosColor.textSecondary)
                            .frame(width: 56, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.name)
                                .font(PharosFont.rowLabel)
                            if !p.arguments.isEmpty {
                                Text(p.arguments.joined(separator: " "))
                                    .font(PharosFont.technical)
                                    .foregroundStyle(PharosColor.textTertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                                    .help(p.arguments.joined(separator: " "))
                            }
                        }
                        Spacer(minLength: PharosSpacing.s)
                        if isListener {
                            PortChips(ports: p.ports)
                                .frame(maxWidth: 160, alignment: .trailing)
                                .fixedSize()
                        } else {
                            Text(l10n.helper)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textTertiary)
                        }
                        Text(ByteFormat.short(p.memoryBytes))
                            .font(PharosFont.captionDigits)
                            .fontWeight(.medium)
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.vertical, PharosSpacing.s)
                }
            }
        }
    }
}

private struct SidebarScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PharosSidebarSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(PharosFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(PharosColor.textTertiary)
                .textCase(.none)
            Spacer()
            trailing
        }
        .padding(.top, PharosSpacing.xs)
    }
}

private extension PharosSidebarSectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

private struct PharosSidebarRow: View {
    let icon: String
    let title: String
    var badge: String? = nil
    var extraBadge: String? = nil
    var badgeIcon: String? = nil
    var badgeColor: Color? = nil
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: PharosSpacing.s) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? PharosColor.accent : PharosColor.textSecondary)
                    .frame(width: 20, alignment: .center)
                Text(title)
                    .font(PharosFont.rowLabel)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(PharosColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let badgeIcon {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 10))
                        .foregroundStyle(badgeColor ?? PharosColor.textSecondary)
                }
                if let badge {
                    Text(badge)
                        .font(PharosFont.captionDigits)
                        .foregroundStyle(PharosColor.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(isSelected ? PharosColor.surface : PharosColor.fill.opacity(0.8))
                        )
                }
                if let extraBadge {
                    Text(extraBadge)
                        .font(PharosFont.captionDigits)
                        .foregroundStyle(PharosColor.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(isSelected ? PharosColor.surface : PharosColor.fill.opacity(0.8))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected
                          ? PharosColor.fill
                          : (isHovered ? PharosColor.fill.opacity(0.4) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? PharosColor.separator.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct BatteryAndThermalSidebarRow: View {
    @ObservedObject private var battery = BatteryStore.shared
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    var isSelected: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        let r = battery.reading
        let thermals = store.thermals
        Button(action: action) {
            HStack(spacing: PharosSpacing.s) {
                Image(systemName: r.hasBattery ? "battery.100.bolt" : "fanblades")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? PharosColor.accent : PharosColor.textSecondary)
                    .frame(width: 20, alignment: .center)
                Text(r.hasBattery ? l10n.batteryAndThermalsTitle : l10n.thermalTitle)
                    .font(PharosFont.rowLabel)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(PharosColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if r.hasBattery {
                    if battery.isHolding {
                        Image(systemName: "powerplug.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.teal)
                    } else if r.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                    }
                    Text("\(r.currentPercent)%")
                        .font(PharosFont.captionDigits)
                        .foregroundStyle(PharosColor.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(isSelected ? PharosColor.surface : PharosColor.fill.opacity(0.8))
                        )
                }
                if let c = thermals?.peakChipTemperature {
                    if r.hasBattery {
                        Text("·")
                            .foregroundStyle(PharosColor.textTertiary)
                    }
                    Text(ThermalStyle.temp(c))
                        .font(PharosFont.captionDigits)
                        .foregroundStyle(c >= 85 ? ThermalStyle.color(c) : PharosColor.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(isSelected ? PharosColor.surface : PharosColor.fill.opacity(0.8))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected
                          ? PharosColor.fill
                          : (isHovered ? PharosColor.fill.opacity(0.4) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? PharosColor.separator.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct FavoriteSidebarRow: View {
    @ObservedObject private var l10n = L10n.shared
    let status: FavoriteStatus
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: PharosSpacing.s) {
                RunDot(running: status.isRunning)
                Text(status.favorite.name)
                    .font(PharosFont.rowLabel)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(PharosColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(status.isRunning
                     ? status.ports.prefix(2).map { ":\($0.port)" }.joined(separator: " ")
                     : l10n.stoppedShort)
                    .font(PharosFont.captionDigits)
                    .foregroundStyle(PharosColor.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(isSelected ? PharosColor.surface : PharosColor.fill.opacity(0.8))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected
                          ? PharosColor.fill
                          : (isHovered ? PharosColor.fill.opacity(0.4) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? PharosColor.separator.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct ProjectSidebarRow: View {
    let project: Project
    let isPinned: Bool
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: PharosSpacing.s) {
                Image(systemName: isPinned ? "star.fill" : "play.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? PharosColor.accent : (isPinned ? Color.yellow : PharosColor.textSecondary))
                    .frame(width: 20, alignment: .center)
                Text(project.name)
                    .font(PharosFont.rowLabel)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(PharosColor.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(ByteFormat.short(project.memoryBytes))
                    .font(PharosFont.captionDigits)
                    .foregroundStyle(PharosColor.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(isSelected ? PharosColor.surface : PharosColor.fill.opacity(0.8))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected
                          ? PharosColor.fill
                          : (isHovered ? PharosColor.fill.opacity(0.4) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? PharosColor.separator.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

