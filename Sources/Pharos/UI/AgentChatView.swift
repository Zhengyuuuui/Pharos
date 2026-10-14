import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers
import PharosCore

struct AgentChatView: View {
    @ObservedObject private var store = AgentChatStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var armedOrphanClean = false
    @State private var armedDeleteId: String? = nil
    @State private var displayLimit = 60

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                metricsCards

                if let msg = store.statusMessage {
                    statusBanner(msg, isSuccess: store.isSuccessMessage)
                }

                if let editor = store.selectedEditor {
                    EditorInspectorHeaderView(editor: editor)
                } else if !store.editorSummaries.isEmpty {
                    AgentStorageChartView()
                }

                filterBar

                if store.filteredEntries.isEmpty {
                    if store.isScanning {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(l10n.loading).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        ContentUnavailableView(
                            l10n.noAgentDbsFound,
                            systemImage: "bubble.left.and.text.bubble.right",
                            description: Text(l10n.noAgentDbsFoundDesc)
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }
                } else {
                    databaseList
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.agentChatTitle)
                    .font(.system(size: 20, weight: .bold))
                Text(l10n.agentChatSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    store.scan()
                } label: {
                    Label(store.isScanning ? l10n.loading : l10n.refreshNow, systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(store.isScanning)

                if store.orphanedCount > 0 {
                    if armedOrphanClean {
                        HStack(spacing: 4) {
                            Button {
                                armedOrphanClean = false
                                store.cleanAllOrphaned()
                            } label: {
                                Text(l10n.cleanOrphanedConfirm)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)

                            IconButton(systemImage: "xmark", help: l10n.cancel) {
                                armedOrphanClean = false
                            }
                        }
                    } else {
                        Button {
                            armedOrphanClean = true
                        } label: {
                            Label(l10n.cleanOrphaned, systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                        .help(l10n.cleanOrphanedHelp)
                    }
                }
            }
        }
    }

    // MARK: - Metrics Cards
    private var metricsCards: some View {
        HStack(spacing: 12) {
            stat(l10n.totalStorageSize, ByteFormat.disk(store.totalSize), icon: "internaldrive")
            stat(l10n.totalDatabases, "\(store.totalDatabases)", icon: "cylinder.split.1x2")
            stat(l10n.totalConversations, "\(store.totalConversations)", icon: "bubble.left.and.bubble.right")
            if store.orphanedCount > 0 {
                stat(l10n.orphanedWorkspaces, "\(store.orphanedCount) (\(ByteFormat.short(store.orphanedSize)))",
                     icon: "exclamationmark.triangle", color: .red)
            }
        }
    }

    private func stat(_ title: String, _ value: String, icon: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 11))
                .foregroundStyle(color ?? .secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                .foregroundStyle(color ?? .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color?.opacity(0.3) ?? Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Status Banner
    private func statusBanner(_ msg: String, isSuccess: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isSuccess ? Color.green : Color.red)
            Text(msg)
                .font(.system(size: 11))
                .textSelection(.enabled)
            Spacer()
            IconButton(systemImage: "xmark", help: l10n.dismiss) {
                store.statusMessage = nil
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSuccess ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
        )
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(
                        title: l10n.allEditors,
                        count: store.totalDatabases,
                        isSelected: store.selectedEditor == nil,
                        icon: "square.grid.2x2"
                    ) {
                        store.selectedEditor = nil
                    }
                    ForEach(store.activeEditorsWithData) { ed in
                        let count = store.count(for: ed)
                        filterChip(
                            title: ed.displayName,
                            count: count,
                            isSelected: store.selectedEditor == ed,
                            editor: ed,
                            installed: ed.isAppInstalled
                        ) {
                            store.selectedEditor = (store.selectedEditor == ed) ? nil : ed
                        }
                    }

                    if !store.inactiveEditors.isEmpty {
                        let isInactiveSelected = store.selectedEditor != nil && store.inactiveEditors.contains(store.selectedEditor!)
                        Menu {
                            ForEach(store.inactiveEditors) { ed in
                                Button {
                                    store.selectedEditor = (store.selectedEditor == ed) ? nil : ed
                                } label: {
                                    HStack {
                                        Text(ed.displayName)
                                        if !ed.isAppInstalled {
                                            Text("(\(l10n.uninstalledAppResidual))")
                                        }
                                        if store.selectedEditor == ed {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                if let selected = store.selectedEditor, store.inactiveEditors.contains(selected) {
                                    AgentEditorIconView(editor: selected, size: 14)
                                    Text(selected.displayName)
                                        .font(.system(size: 11, weight: .semibold))
                                } else {
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 10))
                                    Text(l10n.inactiveEditors)
                                        .font(.system(size: 11))
                                    Text("\(store.inactiveEditors.count)")
                                        .font(.system(size: 9.5).monospacedDigit())
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                                }
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isInactiveSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isInactiveSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField(l10n.searchDatabasesPlaceholder, text: $store.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !store.searchQuery.isEmpty {
                        Button {
                            store.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                .frame(minWidth: 150, maxWidth: 260)

                Picker("", selection: $store.selectedScope) {
                    Text(l10n.allScopes).tag(AgentDatabaseScope?.none)
                    Text(l10n.scopeWorkspace).tag(AgentDatabaseScope?.some(.workspace))
                    Text(l10n.scopeGlobal).tag(AgentDatabaseScope?.some(.global))
                    Text(l10n.scopeVectorCache).tag(AgentDatabaseScope?.some(.vectorCache))
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 125)

                Toggle(l10n.onlyOrphaned, isOn: $store.showOnlyOrphaned)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundStyle(store.showOnlyOrphaned ? Color.red : Color.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()

                Picker(l10n.sortBy, selection: $store.sortOrder) {
                    Text(l10n.sortBySize).tag(AgentChatStore.SortOrder.sizeDesc)
                    Text(l10n.sortByDate).tag(AgentChatStore.SortOrder.mtimeDesc)
                    Text(l10n.sortByName).tag(AgentChatStore.SortOrder.nameAsc)
                }
                .controlSize(.small)
                .frame(width: 135)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func filterChip(
        title: String,
        count: Int,
        isSelected: Bool,
        icon: String? = nil,
        editor: AgentEditorKind? = nil,
        installed: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let editor {
                    AgentEditorIconView(editor: editor, size: 14)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9.5).monospacedDigit())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(isSelected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.08)))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                } else if installed {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Database List
    private var databaseList: some View {
        let items = store.filteredEntries
        let count = items.count
        let visibleItems = items.prefix(displayLimit)

        return LazyVStack(spacing: 8) {
            ForEach(visibleItems) { entry in
                DatabaseCard(
                    entry: entry,
                    isArmedDelete: armedDeleteId == entry.id,
                    onArmDelete: { armedDeleteId = entry.id },
                    onDisarmDelete: { armedDeleteId = nil },
                    onConfirmDelete: {
                        armedDeleteId = nil
                        store.deleteEntry(entry)
                    },
                    onBackup: { store.backupEntry(entry) },
                    onReveal: { store.revealInFinder(entry) },
                    onOpenTerminal: { store.openProjectInTerminal(entry) }
                )
                .id(entry.id)
            }

            if count > displayLimit {
                HStack(spacing: 12) {
                    Text(l10n.showingCount(shown: min(displayLimit, count), total: count))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Button {
                        displayLimit += 60
                    } label: {
                        Text(l10n.loadMore)
                    }
                    .controlSize(.small)

                    Button {
                        displayLimit = count
                    } label: {
                        Text(l10n.showAll)
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Database Card
private struct DatabaseCard: View {
    let entry: AgentDatabaseEntry
    let isArmedDelete: Bool
    let onArmDelete: () -> Void
    let onDisarmDelete: () -> Void
    let onConfirmDelete: () -> Void
    let onBackup: () -> Void
    let onReveal: () -> Void
    let onOpenTerminal: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card header row
            HStack(alignment: .center, spacing: 10) {
                AgentEditorIconView(editor: entry.editor, size: 26, isOrphaned: entry.isOrphaned)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.workspaceName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Text(entry.editor.displayName)
                            .font(.system(size: 9.5, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.secondary)

                        scopeBadge(entry.scope)

                        if entry.isOrphaned {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                Text(l10n.orphanedWorkspaces)
                                    .font(.system(size: 9.5, weight: .semibold))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.red.opacity(0.15)))
                            .foregroundStyle(.red)
                            .help(l10n.orphanedWarning)
                        }
                    }

                    if let path = entry.workspacePath {
                        Text(path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(entry.isOrphaned ? Color.red.opacity(0.8) : Color.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text(entry.filePath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()

                // Stats: size, conversations, modified
                HStack(spacing: 12) {
                    if entry.conversationCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 9))
                            Text("\(entry.conversationCount)")
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                        }
                        .foregroundStyle(Color.accentColor)
                    }

                    Text(ByteFormat.disk(entry.fileSizeBytes))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .frame(minWidth: 54, alignment: .trailing)

                    Text(Format.relativeAge(entry.lastModified))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(width: 50, alignment: .trailing)
                }

                Divider().frame(height: 18)

                // Actions
                HStack(spacing: 4) {
                    if entry.workspacePath != nil && !entry.isOrphaned {
                        IconButton(systemImage: "terminal", help: l10n.openInTerminal) {
                            onOpenTerminal()
                        }
                    }

                    IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                        onReveal()
                    }

                    IconButton(systemImage: "arrow.down.doc", help: l10n.backupDatabase) {
                        onBackup()
                    }

                    if isArmedDelete {
                        HStack(spacing: 2) {
                            Button {
                                onConfirmDelete()
                            } label: {
                                Text(l10n.confirmCleanDb)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.mini)

                            IconButton(systemImage: "xmark", help: l10n.cancel) {
                                onDisarmDelete()
                            }
                        }
                    } else {
                        IconButton(systemImage: "trash", help: l10n.cleanDatabase, tint: .red) {
                            onArmDelete()
                        }
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Expanded conversation details
            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(l10n.conversationsInDb)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(entry.filePath)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }

                    if entry.conversations.isEmpty {
                        Text(l10n.noConversationsParsed)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(entry.conversations.prefix(20)) { conv in
                                HStack(spacing: 8) {
                                    if let mode = conv.mode {
                                        Text(mode.uppercased())
                                            .font(.system(size: 8.5, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(mode == "agent" ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15))
                                            )
                                            .foregroundStyle(mode == "agent" ? Color.purple : Color.blue)
                                    }

                                    Text(conv.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                        .textSelection(.enabled)

                                    if let snippet = conv.snippet {
                                        Text(snippet)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    if let d = conv.createdAt {
                                        Text(Format.relativeAge(d))
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.02)))
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.02))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(entry.isOrphaned ? Color.red.opacity(0.25) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func scopeBadge(_ scope: AgentDatabaseScope) -> some View {
        let (title, color) = switch scope {
        case .global: (l10n.scopeGlobal, Color.indigo)
        case .workspace: (l10n.scopeWorkspace, Color.blue)
        case .vectorCache: (l10n.scopeVectorCache, Color.teal)
        }
        return Text(title)
            .font(.system(size: 9.5))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.12)))
            .foregroundStyle(color)
    }
}

// MARK: - Editor Inspector Header View
struct EditorInspectorHeaderView: View {
    let editor: AgentEditorKind
    @ObservedObject private var store = AgentChatStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            editorSummaryCard
            pathsCard
            conversationsCard
        }
    }

    private var editorSummaryCard: some View {
        HStack(spacing: 12) {
            AgentEditorIconView(editor: editor, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(editor.displayName)
                        .font(.system(size: 16, weight: .bold))

                    if editor.isAppInstalled {
                        HStack(spacing: 3) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text(l10n.appInstalled).font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.12)))
                        .foregroundStyle(Color.green)
                    } else {
                        Text(l10n.appNotInstalled)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(store.count(for: editor)) \(l10n.databasesCountLabel) · \(store.conversationCount(for: editor)) \(l10n.conversationsCountLabel) · \(ByteFormat.disk(store.size(for: editor)))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.selectedEditor = nil
            } label: {
                Label(l10n.allEditors, systemImage: "xmark")
                    .font(.system(size: 11))
            }
            .controlSize(.small)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(editor.themeColor.opacity(0.25), lineWidth: 1))
    }

    private var pathsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(l10n.configuredDbPaths, systemImage: "externaldrive.badge.timemachine")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(l10n.configuredDbPathsDesc)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(editor.knownStoragePaths()) { path in
                    HStack(alignment: .center, spacing: 10) {
                        scopeBadge(path.scope)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(path.label)
                                .font(.system(size: 11.5, weight: .medium))
                            Text(path.fullPath)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }

                        Spacer()

                        if path.exists {
                            HStack(spacing: 6) {
                                Text(ByteFormat.short(path.sizeBytes))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Button {
                                    store.revealPath(path.fullPath)
                                } label: {
                                    Label(l10n.revealInFinder, systemImage: "folder")
                                        .font(.system(size: 10.5))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        } else {
                            Text(l10n.dbPathNotCreated)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.primary.opacity(0.04)))
                        }
                    }
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.02)))
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.02)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
    }

    private var conversationsCard: some View {
        let convs = store.conversations(for: editor)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(l10n.loadedConversations) (\(convs.count))", systemImage: "bubble.left.and.bubble.right")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            if convs.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text(l10n.noConversationsForEditor)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.02)))
            } else {
                VStack(spacing: 6) {
                    ForEach(convs.prefix(20)) { c in
                        conversationRow(c)
                    }

                    if convs.count > 20 {
                        Text(l10n.showingCount(shown: 20, total: convs.count))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.02)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
    }

    private func conversationRow(_ c: AgentConversationSummary) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if let mode = c.mode {
                Text(mode.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(c.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)

                if let snip = c.snippet, !snip.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 9))
                        Text(snip)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let count = c.messageCount {
                Text("\(count) msg")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if let date = c.updatedAt ?? c.createdAt {
                Text(date, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.02)))
    }

    private func scopeBadge(_ scope: AgentDatabaseScope) -> some View {
        let (title, color): (String, Color) = switch scope {
        case .global: ("Global", .indigo)
        case .workspace: ("Workspace", .blue)
        case .vectorCache: ("Cache", .teal)
        }
        return Text(title)
            .font(.system(size: 9.5, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(color.opacity(0.12)))
            .foregroundStyle(color)
    }
}

// MARK: - AI Editor Storage Chart View
struct AgentStorageChartView: View {
    @ObservedObject private var store = AgentChatStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var mode: Mode = .total

    enum Mode: String, CaseIterable, Identifiable {
        case total
        case breakdown
        var id: String { rawValue }
    }

    private struct ScopeSegment: Identifiable {
        let editor: AgentEditorKind
        let scope: AgentDatabaseScope
        let scopeName: String
        let bytes: UInt64
        var id: String { "\(editor.rawValue)_\(scope.rawValue)" }
    }

    var body: some View {
        let summaries = store.editorSummaries
        guard !summaries.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                // Header with Mode switch
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(l10n.editorStorageChart, systemImage: "chart.bar.xaxis")
                            .font(.system(size: 13, weight: .semibold))
                        Text(l10n.editorStorageDesc)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $mode) {
                        Text(l10n.chartModeTotal).tag(Mode.total)
                        Text(l10n.chartModeBreakdown).tag(Mode.breakdown)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .controlSize(.small)
                }

                // Composition strip bar
                compositionBar(summaries: summaries)

                // Chart
                if mode == .total {
                    totalChart(summaries: summaries)
                } else {
                    breakdownChart(summaries: summaries)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        )
    }

    private func compositionBar(summaries: [AgentChatStore.EditorStorageSummary]) -> some View {
        let total = Double(max(1, store.totalSize))
        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(summaries) { s in
                        let w = max(3, geo.size.width * (Double(s.totalBytes) / total))
                        Button {
                            toggleEditor(s.editor)
                        } label: {
                            Rectangle()
                                .fill(s.editor.themeColor.opacity(store.selectedEditor == nil || store.selectedEditor == s.editor ? 0.9 : 0.25))
                                .frame(width: w)
                        }
                        .buttonStyle(.plain)
                        .help("\(s.editor.displayName): \(ByteFormat.disk(s.totalBytes))")
                    }
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            // Mini legend
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(summaries) { s in
                        let pct = Int((Double(s.totalBytes) / total * 100).rounded())
                        Button {
                            toggleEditor(s.editor)
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(s.editor.themeColor)
                                    .frame(width: 7, height: 7)
                                Text(s.editor.displayName)
                                    .font(.system(size: 11, weight: store.selectedEditor == s.editor ? .bold : .medium))
                                    .lineLimit(1)
                                Text("\(ByteFormat.short(s.totalBytes)) (\(pct)%)")
                                    .font(.system(size: 9.5).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(store.selectedEditor == s.editor ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(store.selectedEditor == s.editor ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func totalChart(summaries: [AgentChatStore.EditorStorageSummary]) -> some View {
        let maxMB = summaries.map { Double($0.totalBytes) / 1_048_576.0 }.max() ?? 10.0
        let domainMax = max(10.0, maxMB * 1.35)

        return Chart(summaries) { s in
            BarMark(
                x: .value("Size", Double(s.totalBytes) / 1_048_576.0),
                y: .value("Editor", s.editor.displayName)
            )
            .foregroundStyle(s.editor.themeColor.gradient.opacity(store.selectedEditor == nil || store.selectedEditor == s.editor ? 1.0 : 0.4))
            .cornerRadius(4)
            .annotation(position: .trailing, spacing: 8) {
                HStack(spacing: 4) {
                    Text(ByteFormat.disk(s.totalBytes))
                        .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        .lineLimit(1)
                    Text("(\(s.databaseCount) dbs)")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: 0 ... domainMax)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { v in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(anchor: .top) {
                    if let d = v.as(Double.self) {
                        Text(formatMB(d))
                            .font(.system(size: 9.5).monospacedDigit())
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { v in
                AxisValueLabel {
                    if let str = v.as(String.self) {
                        Text(str)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .frame(height: max(120, CGFloat(summaries.count) * 32 + 50))
    }

    private func breakdownChart(summaries: [AgentChatStore.EditorStorageSummary]) -> some View {
        let maxMB = summaries.map { Double($0.totalBytes) / 1_048_576.0 }.max() ?? 10.0
        let domainMax = max(10.0, maxMB * 1.15)

        let segments = summaries.flatMap { s -> [ScopeSegment] in
            var list: [ScopeSegment] = []
            if s.workspaceBytes > 0 {
                list.append(ScopeSegment(editor: s.editor, scope: .workspace, scopeName: l10n.scopeWorkspace, bytes: s.workspaceBytes))
            }
            if s.globalBytes > 0 {
                list.append(ScopeSegment(editor: s.editor, scope: .global, scopeName: l10n.scopeGlobal, bytes: s.globalBytes))
            }
            if s.cacheBytes > 0 {
                list.append(ScopeSegment(editor: s.editor, scope: .vectorCache, scopeName: l10n.scopeVectorCache, bytes: s.cacheBytes))
            }
            return list
        }

        return Chart(segments) { seg in
            BarMark(
                x: .value("Size", Double(seg.bytes) / 1_048_576.0),
                y: .value("Editor", seg.editor.displayName)
            )
            .foregroundStyle(by: .value("Scope", seg.scopeName))
            .opacity(store.selectedEditor == nil || store.selectedEditor == seg.editor ? 1.0 : 0.4)
        }
        .chartForegroundStyleScale([
            l10n.scopeWorkspace: Color.blue,
            l10n.scopeGlobal: Color.indigo,
            l10n.scopeVectorCache: Color.teal
        ])
        .chartLegend(position: .top, alignment: .trailing, spacing: 12)
        .chartXScale(domain: 0 ... domainMax)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { v in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(anchor: .top) {
                    if let d = v.as(Double.self) {
                        Text(formatMB(d))
                            .font(.system(size: 9.5).monospacedDigit())
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { v in
                AxisValueLabel {
                    if let str = v.as(String.self) {
                        Text(str)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .frame(height: max(130, CGFloat(summaries.count) * 32 + 60))
    }

    private func toggleEditor(_ editor: AgentEditorKind) {
        if store.selectedEditor == editor {
            store.selectedEditor = nil
        } else {
            store.selectedEditor = editor
        }
    }

    private func formatMB(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return "\(Int(mb)) MB"
        }
    }
}

extension AgentEditorKind {
    var themeColor: Color {
        switch self {
        case .cursor: return Color.purple
        case .trae: return Color.orange
        case .vscode: return Color.blue
        case .antigravity: return Color.indigo
        case .qoder: return Color.red
        case .cherryStudio: return Color.pink
        case .codeBuddy: return Color.cyan
        case .kiro: return Color.mint
        case .openCode: return Color.green
        case .claudeCode: return Color(red: 0.85, green: 0.42, blue: 0.30)
        case .windsurf: return Color.teal
        case .zed: return Color.yellow
        case .workBuddy: return Color(red: 0.15, green: 0.55, blue: 0.95)
        case .miniMax: return Color(red: 0.75, green: 0.25, blue: 0.85)
        case .zCode: return Color(red: 0.95, green: 0.55, blue: 0.2)
        case .continueExt: return Color(red: 0.2, green: 0.7, blue: 0.7)
        case .aider: return Color(red: 0.55, green: 0.75, blue: 0.3)
        case .doubao: return Color(red: 0.2, green: 0.6, blue: 0.95)
        case .chatgpt: return Color(red: 0.1, green: 0.65, blue: 0.5)
        case .marvis: return Color(red: 0.05, green: 0.5, blue: 0.9)
        case .wechatDevTools: return Color(red: 0.08, green: 0.75, blue: 0.35)
        case .hbuilder: return Color(red: 0.15, green: 0.7, blue: 0.45)
        case .deepseek: return Color(red: 0.3, green: 0.45, blue: 0.95)
        }
    }
}

// MARK: - Local App Icon Provider & Cache
@MainActor
final class AgentEditorIconProvider {
    static let shared = AgentEditorIconProvider()
    private var cache: [AgentEditorKind: NSImage] = [:]
    private var didSearch: Set<AgentEditorKind> = []

    private init() {}

    func icon(for editor: AgentEditorKind) -> NSImage? {
        if let img = cache[editor] {
            return img
        }
        if didSearch.contains(editor) {
            return cache[editor]
        }
        didSearch.insert(editor)

        // 1. Direct path lookup from installedAppPath
        if let path = editor.installedAppPath {
            let img = NSWorkspace.shared.icon(forFile: path)
            cache[editor] = img
            return img
        }

        // 2. LaunchServices bundle identifier query
        for bid in editor.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                let img = NSWorkspace.shared.icon(forFile: url.path)
                cache[editor] = img
                return img
            }
        }

        // 3. Fallback for uninstalled app: macOS system package icon
        let pkgIcon: NSImage
        if #available(macOS 12.0, *) {
            pkgIcon = NSWorkspace.shared.icon(for: UTType.package)
        } else {
            pkgIcon = NSWorkspace.shared.icon(forFileType: "pkg")
        }
        cache[editor] = pkgIcon
        return pkgIcon
    }
}

// MARK: - Native App Icon View
struct AgentEditorIconView: View {
    let editor: AgentEditorKind
    var size: CGFloat = 20
    var isOrphaned: Bool = false

    var body: some View {
        if let nsImage = AgentEditorIconProvider.shared.icon(for: editor) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: max(3, size * 0.22), style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: max(3, size * 0.22), style: .continuous)
                        .stroke(isOrphaned ? Color.red.opacity(0.6) : Color.primary.opacity(0.12), lineWidth: 0.5)
                )
        } else {
            Image(systemName: editor.systemImage)
                .font(.system(size: max(8, size * 0.52)))
                .foregroundStyle(isOrphaned ? Color.red : editor.themeColor)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: max(3, size * 0.22), style: .continuous)
                        .fill(isOrphaned ? Color.red.opacity(0.12) : editor.themeColor.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: max(3, size * 0.22), style: .continuous)
                        .stroke(isOrphaned ? Color.red.opacity(0.4) : editor.themeColor.opacity(0.25), lineWidth: 0.5)
                )
        }
    }
}

