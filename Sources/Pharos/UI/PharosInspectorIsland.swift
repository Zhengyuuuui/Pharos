import SwiftUI
import PharosCore

/// Floating right-hand Ambient Context Rail container (fixed width 260pt).
struct PharosInspectorIsland: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let selection: MainWindowView.SidebarItem?
    let onCollapse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 1. Unobtrusive Control Header (Height 28pt)
            header
                .padding(.horizontal, 4)
                .frame(height: 28)
                .padding(.bottom, 6)

            // 2. Bento Modular Card Stack (8pt Gaps, Gradient shows through)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    inspectorBody
                }
                .padding(.bottom, 14) // Safe bottom buffer
            }
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PharosColor.accent)

            Text(l10n.inspectorTitle)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(PharosColor.textSecondary)

            Spacer()

            Button(action: onCollapse) {
                Image(systemName: "sidebar.trailing")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(PharosColor.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(l10n.toggleInspector)
        }
    }

    @ViewBuilder
    private var inspectorBody: some View {
        switch selection {
        case .portsOverview:
            PortsOverviewInspectorView()
        case .systemMemory:
            SystemMemoryInspectorView()
        case .diskUsage:
            DiskUsageInspectorView()
        case .batteryAndThermals:
            BatteryThermalInspectorView()
        case .packages:
            PackagesInspectorView()
        case .browsersAndNetwork:
            ChromeInspectorView()
        case .agentChats:
            AgentChatsInspectorView()
        case .diskCleanup:
            DiskCleanupInspectorView()
        case .project(let id):
            if let p = store.project(id: id) {
                ProjectDetailInspectorView(project: p)
            } else {
                PortsOverviewInspectorView()
            }
        case .favorite(let id):
            if let fav = WorkspaceStore.shared.favorites.first(where: { $0.id == id }),
               let p = store.projects.first(where: { $0.directory == fav.directory }) {
                ProjectDetailInspectorView(project: p)
            } else {
                PortsOverviewInspectorView()
            }
        case .customize:
            CustomizePopoverInspectorView()
        case .settings:
            SettingsInspectorView()
        case nil:
            PortsOverviewInspectorView()
        }
    }
}
