import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers
import PharosCore

/// Overview (all editors) and detail (one editor) are separate pages: the detail page
/// replaces the overview entirely, so other editors' cards never appear below it.
struct AgentChatView: View {
    @ObservedObject private var store = AgentChatStore.shared

    var body: some View {
        Group {
            if let editor = store.selectedEditor {
                AgentEditorDetailPage(editor: editor)
                    .id(editor)
            } else {
                AgentOverviewPage()
            }
        }
        .onAppear { store.scanIfNeeded() }
        .onExitCommand { store.selectedEditor = nil }
    }
}

// MARK: - Overview Page

private struct AgentOverviewPage: View {
    @ObservedObject private var store = AgentChatStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var armedOrphanClean = false
    @State private var showInactive = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                metricsCards
                if let msg = store.statusMessage {
                    AgentStatusBanner(message: msg, isSuccess: store.isSuccessMessage) { store.statusMessage = nil }
                }

                if store.summaries.isEmpty {
                    emptyOrLoading
                } else {
                    AgentStorageChartView()
                    editorsSection
                    filterBar
                    if store.isOverviewFiltering {
                        searchResults
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.agentChatTitle).font(.system(size: 20, weight: .bold))
                Text(l10n.agentChatSubtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button { store.scan() } label: {
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
                                Text(l10n.cleanOrphanedConfirm).font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                            IconButton(systemImage: "xmark", help: l10n.cancel) { armedOrphanClean = false }
                        }
                    } else {
                        Button { armedOrphanClean = true } label: {
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

    private var metricsCards: some View {
        HStack(spacing: 12) {
            AgentStatCard(title: l10n.totalStorageSize, value: ByteFormat.disk(store.totalSize), icon: "internaldrive")
            AgentStatCard(title: l10n.totalDatabases, value: "\(store.totalDatabases)", icon: "cylinder.split.1x2")
            AgentStatCard(title: l10n.totalConversations, value: "\(store.totalConversations)", icon: "bubble.left.and.bubble.right")
            if store.orphanedCount > 0 {
                AgentStatCard(title: l10n.orphanedWorkspaces,
                              value: "\(store.orphanedCount) (\(ByteFormat.short(store.orphanedSize)))",
                              icon: "exclamationmark.triangle", color: .red)
            }
        }
    }

    @ViewBuilder
    private var emptyOrLoading: some View {
        if store.isScanning {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(l10n.loading).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            ContentUnavailableView(l10n.noAgentDbsFound, systemImage: "bubble.left.and.text.bubble.right",
                                   description: Text(l10n.noAgentDbsFoundDesc))
                .frame(maxWidth: .infinity, minHeight: 180)
        }
    }

    // MARK: Editors (grid or strip, chosen in Settings)

    private var editorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(l10n.agentEditorsHeader, systemImage: "square.grid.2x2")
                .font(.system(size: 13, weight: .semibold))

            switch store.editorLayout {
            case .grid: editorGrid
            case .strip: editorStrip
            }

            if !store.inactiveEditors.isEmpty {
                DisclosureGroup(isExpanded: $showInactive) {
                    FlowLayout(spacing: 6) {
                        ForEach(store.inactiveEditors) { ed in
                            HStack(spacing: 5) {
                                AgentEditorIconView(editor: ed, size: 14)
                                Text(ed.displayName).font(.system(size: 11))
                                if ed.isAppInstalled {
                                    Circle().fill(Color.green).frame(width: 5, height: 5).help(l10n.appInstalled)
                                }
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.04)))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text(l10n.agentInactiveEditorsHeader(store.inactiveEditors.count))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var editorGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
            ForEach(store.summaries) { s in
                Button { store.selectedEditor = s.editor } label: { AgentEditorGridCard(summary: s) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var editorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.summaries) { s in
                    Button { store.selectedEditor = s.editor } label: {
                        HStack(spacing: 5) {
                            AgentEditorIconView(editor: s.editor, size: 16)
                            Text(s.editor.displayName).font(.system(size: 11)).lineLimit(1)
                            Text(ByteFormat.short(s.totalBytes))
                                .font(.system(size: 9.5).monospacedDigit())
                                .foregroundStyle(.secondary)
                            if s.orphanedCount > 0 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 8)).foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(s.editor.themeColor.opacity(0.25), lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help("\(s.editor.displayName) · \(l10n.agentDbCount(s.databaseCount)) · \(s.conversationCount) \(l10n.conversationsCountLabel)")
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Cross-editor search

    private var filterBar: some View {
        HStack(spacing: 10) {
            AgentSearchField(placeholder: l10n.searchDatabasesPlaceholder, text: $store.searchQuery)
                .frame(minWidth: 150, maxWidth: 260)
            AgentScopePicker(selection: $store.selectedScope)
            Toggle(l10n.onlyOrphaned, isOn: $store.showOnlyOrphaned)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundStyle(store.showOnlyOrphaned ? Color.red : Color.secondary)
                .fixedSize()
            Spacer()
            if store.isOverviewFiltering { AgentSortPicker(selection: $store.sortOrder) }
        }
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(l10n.agentSearchResults) (\(store.filteredEntries.count))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if store.filteredEntries.isEmpty {
                Text(l10n.agentConvNoMatch).font(.system(size: 11)).foregroundStyle(.tertiary)
            } else {
                AgentDatabaseList(entries: store.filteredEntries, showsEditor: true, query: store.searchQuery)
            }
        }
    }
}

private struct AgentEditorGridCard: View {
    let summary: AgentEditorSummary
    @ObservedObject private var l10n = L10n.shared
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AgentEditorIconView(editor: summary.editor, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(summary.editor.displayName).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                    Text(ByteFormat.disk(summary.totalBytes))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(summary.editor.themeColor)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }
            HStack(spacing: 10) {
                Label(l10n.agentDbCount(summary.databaseCount), systemImage: "cylinder")
                Label("\(summary.conversationCount)", systemImage: "bubble.left")
                if summary.orphanedCount > 0 {
                    Label("\(summary.orphanedCount)", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
                Spacer(minLength: 0)
                if summary.editor.isAppInstalled {
                    Circle().fill(Color.green).frame(width: 6, height: 6).help(l10n.appInstalled)
                }
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.secondary)
            .labelStyle(TightLabelStyle())
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(hovering ? 0.07 : 0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(summary.editor.themeColor.opacity(hovering ? 0.5 : 0.2), lineWidth: 1))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - Editor Detail Page

private struct AgentEditorDetailPage: View {
    let editor: AgentEditorKind
    @ObservedObject private var store = AgentChatStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var tab: Tab = .databases
    @State private var showMissingPaths = false

    enum Tab: Hashable { case databases, conversations }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                backBar
                summaryCard
                if let msg = store.statusMessage {
                    AgentStatusBanner(message: msg, isSuccess: store.isSuccessMessage) { store.statusMessage = nil }
                }
                Picker("", selection: $tab) {
                    Text("\(l10n.agentTabDatabases) (\(store.summary(for: editor)?.databaseCount ?? 0))").tag(Tab.databases)
                    Text("\(l10n.agentTabConversations) (\(store.summary(for: editor)?.conversationCount ?? 0))").tag(Tab.conversations)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)

                switch tab {
                case .databases: databasesTab
                case .conversations: conversationsTab
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var backBar: some View {
        Button { store.selectedEditor = nil } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                Text(l10n.agentBackToAll).font(.system(size: 12))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .keyboardShortcut("[", modifiers: .command)
    }

    private var summaryCard: some View {
        let s = store.summary(for: editor)
        return HStack(spacing: 12) {
            AgentEditorIconView(editor: editor, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(editor.displayName).font(.system(size: 16, weight: .bold))
                    if editor.isAppInstalled {
                        HStack(spacing: 3) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text(l10n.appInstalled).font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.12)))
                        .foregroundStyle(Color.green)
                    } else {
                        Text(l10n.appNotInstalled).font(.system(size: 10))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(s?.databaseCount ?? 0) \(l10n.databasesCountLabel) · \(s?.conversationCount ?? 0) \(l10n.conversationsCountLabel) · \(ByteFormat.disk(s?.totalBytes ?? 0))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let last = s?.lastModified {
                    Text("\(l10n.agentLastActive): \(Format.relativeAge(last))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(editor.themeColor.opacity(0.25), lineWidth: 1))
    }

    // MARK: Databases tab

    private var databasesTab: some View {
        let missing = editor.knownStoragePaths().filter { !$0.exists }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AgentSearchField(placeholder: l10n.searchDatabasesPlaceholder, text: $store.searchQuery)
                    .frame(minWidth: 150, maxWidth: 260)
                AgentScopePicker(selection: $store.selectedScope)
                Spacer()
                AgentSortPicker(selection: $store.sortOrder)
            }

            if store.filteredEntries.isEmpty {
                Text(l10n.agentConvNoMatch).font(.system(size: 11)).foregroundStyle(.tertiary)
            } else {
                AgentDatabaseList(entries: store.filteredEntries, showsEditor: false, query: store.searchQuery)
            }

            if !missing.isEmpty {
                DisclosureGroup(isExpanded: $showMissingPaths) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(missing) { path in
                            HStack(spacing: 8) {
                                AgentScopeBadge(scope: path.scope)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(path.label).font(.system(size: 11))
                                    Text(path.fullPath)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1).truncationMode(.middle)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text(l10n.agentPathsNotCreated(missing.count)).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Conversations tab

    private var conversationsTab: some View {
        let refs = store.conversationRefs(for: editor)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AgentSearchField(placeholder: l10n.agentSearchConversations, text: $store.detailSearch)
                    .frame(minWidth: 150, maxWidth: 300)
                Spacer()
                if store.isTruncated(editor) {
                    Label(l10n.agentTruncatedNote, systemImage: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            if refs.isEmpty {
                HStack {
                    Image(systemName: "info.circle").foregroundStyle(.secondary)
                    Text(store.detailSearch.isEmpty ? l10n.noConversationsForEditor : l10n.agentConvNoMatch)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.02)))
            } else {
                AgentConversationList(rows: refs.map { .init(ref: $0, showsDatabase: true) })
            }
        }
    }
}

// MARK: - Database list & card

private struct AgentDatabaseList: View {
    let entries: [AgentDatabaseEntry]
    let showsEditor: Bool
    let query: String
    @ObservedObject private var l10n = L10n.shared
    @State private var displayLimit = 60
    @State private var armedDeleteId: String?

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(entries.prefix(displayLimit)) { entry in
                AgentDatabaseCard(
                    entry: entry,
                    showsEditor: showsEditor,
                    query: query,
                    isArmedDelete: armedDeleteId == entry.id,
                    onArmDelete: { armedDeleteId = entry.id },
                    onDisarmDelete: { armedDeleteId = nil }
                )
            }
            if entries.count > displayLimit {
                HStack(spacing: 12) {
                    Text(l10n.showingCount(shown: displayLimit, total: entries.count))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Button(l10n.loadMore) { displayLimit += 60 }.controlSize(.small)
                    Button(l10n.showAll) { displayLimit = entries.count }.controlSize(.small)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct AgentDatabaseCard: View {
    let entry: AgentDatabaseEntry
    let showsEditor: Bool
    let query: String
    let isArmedDelete: Bool
    let onArmDelete: () -> Void
    let onDisarmDelete: () -> Void

    @ObservedObject private var store = AgentChatStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 10)
                        AgentEditorIconView(editor: entry.editor, size: 24, isOrphaned: entry.isOrphaned)
                        titleBlock
                        Spacer(minLength: 8)
                        stats
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().frame(height: 18)
                actions
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            if isExpanded {
                Divider()
                expandedBody
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(entry.isOrphaned ? Color.red.opacity(0.25) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(entry.workspaceName).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                if showsEditor {
                    Text(entry.editor.displayName)
                        .font(.system(size: 9.5, weight: .medium))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                        .foregroundStyle(.secondary)
                }
                AgentScopeBadge(scope: entry.scope)
                if entry.isOrphaned {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 8))
                        Text(l10n.orphanedWorkspaces).font(.system(size: 9.5, weight: .semibold))
                    }
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
                    .foregroundStyle(.red)
                    .help(l10n.orphanedWarning)
                }
            }
            Text(entry.workspacePath ?? entry.filePath)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(entry.isOrphaned ? Color.red.opacity(0.8) : Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var stats: some View {
        HStack(spacing: 12) {
            if entry.conversationCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "bubble.left.fill").font(.system(size: 9))
                    Text("\(entry.conversationCount)").font(.system(size: 11, weight: .medium).monospacedDigit())
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
    }

    private var actions: some View {
        let verdict = store.deleteVerdict(entry)
        let deletable: Bool = { if case .allowed = verdict { return true } else { return false } }()
        return HStack(spacing: 4) {
            if entry.workspacePath != nil && !entry.isOrphaned {
                IconButton(systemImage: "terminal", help: l10n.openInTerminal) { store.openProjectInTerminal(entry) }
            }
            IconButton(systemImage: "folder", help: l10n.revealInFinder) { store.revealInFinder(entry) }
            IconButton(systemImage: "arrow.down.doc", help: l10n.backupDatabase) { store.backupEntry(entry) }
            if isArmedDelete && deletable {
                HStack(spacing: 2) {
                    Button {
                        onDisarmDelete()
                        store.deleteEntry(entry)
                    } label: {
                        Text(l10n.confirmCleanDb).font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.mini)
                    IconButton(systemImage: "xmark", help: l10n.cancel) { onDisarmDelete() }
                }
            } else if deletable {
                IconButton(systemImage: "trash", help: l10n.cleanDatabase, tint: .red) { onArmDelete() }
            } else {
                Image(systemName: "lock")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20, height: 20)
                    .help(l10n.agentDeleteDisabledHelp(verdict))
            }
        }
    }

    private var expandedBody: some View {
        // Narrow to matching sessions only when the search hit sessions; a name/path hit shows them all.
        let hits = entry.conversations.filter { AgentChatCatalog.matches($0, query: query) }
        let convs = hits.isEmpty ? entry.conversations : hits
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(l10n.conversationsInDb).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(entry.filePath)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
                    .textSelection(.enabled)
            }
            if convs.isEmpty {
                Text(l10n.noConversationsParsed).font(.system(size: 11)).foregroundStyle(.tertiary).padding(.vertical, 4)
            } else {
                AgentConversationList(rows: convs.map {
                    .init(ref: AgentConversationRef(conversation: $0, entryId: entry.id, databaseName: entry.workspaceName,
                                                    databasePath: entry.filePath, scope: entry.scope),
                          showsDatabase: false)
                })
                if entry.conversations.count >= AgentChatCatalog.readerConversationCap {
                    Label(l10n.agentTruncatedNote, systemImage: "info.circle")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.02))
    }
}

// MARK: - Conversation list (metadata only)

private struct AgentConversationList: View {
    struct Row: Identifiable {
        let ref: AgentConversationRef
        let showsDatabase: Bool
        var id: String { ref.id }
    }

    let rows: [Row]
    @ObservedObject private var l10n = L10n.shared
    @State private var limit = 30
    @State private var expanded: Set<String> = []

    var body: some View {
        LazyVStack(spacing: 4) {
            ForEach(rows.prefix(limit)) { row in
                AgentConversationRow(
                    ref: row.ref,
                    showsDatabase: row.showsDatabase,
                    isExpanded: expanded.contains(row.id)
                ) {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        if expanded.contains(row.id) { expanded.remove(row.id) } else { expanded.insert(row.id) }
                    }
                }
            }
            if rows.count > limit {
                HStack(spacing: 12) {
                    Text(l10n.showingCount(shown: limit, total: rows.count))
                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                    Button(l10n.loadMore) { limit += 60 }.controlSize(.small)
                    Button(l10n.showAll) { limit = rows.count }.controlSize(.small)
                }
                .padding(.top, 6)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct AgentConversationRow: View {
    let ref: AgentConversationRef
    let showsDatabase: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    @ObservedObject private var l10n = L10n.shared

    private var c: AgentConversationSummary { ref.conversation }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 8)
                    if let mode = c.mode { AgentModeBadge(mode: mode) }
                    Text(c.title).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                    if showsDatabase {
                        Text(ref.databaseName)
                            .font(.system(size: 9.5))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if let n = c.messageCount {
                        Text(l10n.agentMessages(n)).font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
                    }
                    if let d = ref.sortDate {
                        Text(Format.relativeAge(d)).font(.system(size: 10)).foregroundStyle(.tertiary)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded { details }
        }
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(isExpanded ? 0.05 : 0.02)))
    }

    private var details: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            field(l10n.agentConvTitle, c.title)
            if let mode = c.mode { field(l10n.agentConvMode, mode) }
            if let n = c.messageCount { field(l10n.agentConvMessages, "\(n)") }
            if let d = c.createdAt { field(l10n.agentConvCreated, d.formatted(date: .abbreviated, time: .shortened)) }
            if let d = c.updatedAt { field(l10n.agentConvUpdated, d.formatted(date: .abbreviated, time: .shortened)) }
            field(l10n.agentConvDatabase, "\(ref.databaseName) — \(ref.databasePath)", mono: true)
            if let s = c.snippet, !s.isEmpty { field(l10n.agentConvSnippet, s, mono: true) }
            field(l10n.agentConvId, c.id, mono: true)
        }
        .padding(.leading, 24)
        .padding(.trailing, 8)
        .padding(.bottom, 8)
    }

    private func field(_ label: String, _ value: String, mono: Bool = false) -> some View {
        GridRow {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value)
                .font(.system(size: 10.5, design: mono ? .monospaced : .default))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Shared small components

private struct AgentStatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.system(size: 11)).foregroundStyle(color ?? .secondary).lineLimit(1)
            Text(value)
                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                .foregroundStyle(color ?? .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color?.opacity(0.3) ?? Color.clear, lineWidth: 1))
    }
}

private struct AgentStatusBanner: View {
    let message: String
    let isSuccess: Bool
    let onDismiss: () -> Void
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isSuccess ? Color.green : Color.red)
            Text(message).font(.system(size: 11)).textSelection(.enabled)
            Spacer()
            IconButton(systemImage: "xmark", help: l10n.dismiss, action: onDismiss)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(isSuccess ? Color.green.opacity(0.08) : Color.red.opacity(0.08)))
    }
}

private struct AgentSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
            TextField(placeholder, text: $text).textFieldStyle(.plain).font(.system(size: 12))
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
    }
}

private struct AgentScopePicker: View {
    @Binding var selection: AgentDatabaseScope?
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Picker("", selection: $selection) {
            Text(l10n.allScopes).tag(AgentDatabaseScope?.none)
            Text(l10n.scopeWorkspace).tag(AgentDatabaseScope?.some(.workspace))
            Text(l10n.scopeGlobal).tag(AgentDatabaseScope?.some(.global))
            Text(l10n.scopeVectorCache).tag(AgentDatabaseScope?.some(.vectorCache))
        }
        .labelsHidden()
        .controlSize(.small)
        .frame(width: 125)
    }
}

private struct AgentSortPicker: View {
    @Binding var selection: AgentChatSortOrder
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Picker(l10n.sortBy, selection: $selection) {
            Text(l10n.sortBySize).tag(AgentChatSortOrder.sizeDesc)
            Text(l10n.sortByDate).tag(AgentChatSortOrder.mtimeDesc)
            Text(l10n.sortByName).tag(AgentChatSortOrder.nameAsc)
        }
        .controlSize(.small)
        .fixedSize()
    }
}

struct AgentScopeBadge: View {
    let scope: AgentDatabaseScope
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let (title, color): (String, Color) = switch scope {
        case .global: (l10n.agentScopeShortGlobal, .indigo)
        case .workspace: (l10n.agentScopeShortWorkspace, .blue)
        case .vectorCache: (l10n.agentScopeShortCache, .teal)
        }
        Text(title)
            .font(.system(size: 9.5, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.12)))
            .foregroundStyle(color)
    }
}

private struct AgentModeBadge: View {
    let mode: String

    var body: some View {
        let isAgent = mode.lowercased() == "agent"
        Text(mode.uppercased())
            .font(.system(size: 8.5, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 3).fill((isAgent ? Color.purple : Color.blue).opacity(0.15)))
            .foregroundStyle(isAgent ? Color.purple : Color.blue)
    }
}

private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.system(size: 9))
            configuration.title
        }
    }
}

// MARK: - Storage chart (collapsible; composition strip always visible)

struct AgentStorageChartView: View {
    @ObservedObject private var store = AgentChatStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var mode: Mode = .total

    enum Mode: Hashable { case total, breakdown }

    private struct ScopeSegment: Identifiable {
        let editor: AgentEditorKind
        let scopeName: String
        let bytes: UInt64
        var id: String { "\(editor.rawValue)_\(scopeName)" }
    }

    var body: some View {
        let summaries = store.summaries
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(l10n.editorStorageChart, systemImage: "chart.bar.xaxis").font(.system(size: 13, weight: .semibold))
                    if !store.chartCollapsed {
                        Text(l10n.editorStorageDesc).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !store.chartCollapsed {
                    Picker("", selection: $mode) {
                        Text(l10n.chartModeTotal).tag(Mode.total)
                        Text(l10n.chartModeBreakdown).tag(Mode.breakdown)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .controlSize(.small)
                }
                IconButton(
                    systemImage: store.chartCollapsed ? "chevron.down" : "chevron.up",
                    help: store.chartCollapsed ? l10n.agentChartExpand : l10n.agentChartCollapse
                ) {
                    withAnimation(.easeInOut(duration: 0.18)) { store.chartCollapsed.toggle() }
                }
            }

            compositionBar(summaries)

            if !store.chartCollapsed {
                legend(summaries)
                if mode == .total { totalChart(summaries) } else { breakdownChart(summaries) }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private func compositionBar(_ summaries: [AgentEditorSummary]) -> some View {
        let total = Double(max(1, store.totalSize))
        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(summaries) { s in
                    Rectangle()
                        .fill(s.editor.themeColor.opacity(0.9))
                        .frame(width: max(3, (geo.size.width - CGFloat(summaries.count - 1) * 2) * (Double(s.totalBytes) / total)))
                        .help("\(s.editor.displayName): \(ByteFormat.disk(s.totalBytes))")
                }
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func legend(_ summaries: [AgentEditorSummary]) -> some View {
        let total = Double(max(1, store.totalSize))
        return FlowLayout(spacing: 8) {
            ForEach(summaries) { s in
                HStack(spacing: 5) {
                    Circle().fill(s.editor.themeColor).frame(width: 7, height: 7)
                    Text(s.editor.displayName).font(.system(size: 10.5)).lineLimit(1)
                    Text("\(ByteFormat.short(s.totalBytes)) (\(Int((Double(s.totalBytes) / total * 100).rounded()))%)")
                        .font(.system(size: 9.5).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func totalChart(_ summaries: [AgentEditorSummary]) -> some View {
        let maxMB = summaries.map { Double($0.totalBytes) / 1_048_576.0 }.max() ?? 10.0
        return Chart(summaries) { s in
            BarMark(x: .value("Size", Double(s.totalBytes) / 1_048_576.0), y: .value("Editor", s.editor.displayName))
                .foregroundStyle(s.editor.themeColor.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Text(ByteFormat.disk(s.totalBytes)).font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                        Text("(\(l10n.agentDbCount(s.databaseCount)))").font(.system(size: 9.5)).foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }
        }
        .chartLegend(.hidden)
        .chartXScale(domain: 0 ... max(10.0, maxMB * 1.35))
        .chartXAxis { mbAxis }
        .chartYAxis { editorAxis }
        .frame(height: max(120, CGFloat(summaries.count) * 28 + 40))
    }

    private func breakdownChart(_ summaries: [AgentEditorSummary]) -> some View {
        let maxMB = summaries.map { Double($0.totalBytes) / 1_048_576.0 }.max() ?? 10.0
        let segments = summaries.flatMap { s -> [ScopeSegment] in
            [(l10n.scopeWorkspace, s.workspaceBytes), (l10n.scopeGlobal, s.globalBytes), (l10n.scopeVectorCache, s.cacheBytes)]
                .filter { $0.1 > 0 }
                .map { ScopeSegment(editor: s.editor, scopeName: $0.0, bytes: $0.1) }
        }
        return Chart(segments) { seg in
            BarMark(x: .value("Size", Double(seg.bytes) / 1_048_576.0), y: .value("Editor", seg.editor.displayName))
                .foregroundStyle(by: .value("Scope", seg.scopeName))
        }
        .chartForegroundStyleScale([
            l10n.scopeWorkspace: Color.blue,
            l10n.scopeGlobal: Color.indigo,
            l10n.scopeVectorCache: Color.teal,
        ])
        .chartLegend(position: .top, alignment: .trailing, spacing: 12)
        .chartXScale(domain: 0 ... max(10.0, maxMB * 1.15))
        .chartXAxis { mbAxis }
        .chartYAxis { editorAxis }
        .frame(height: max(130, CGFloat(summaries.count) * 28 + 50))
    }

    private var mbAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) { v in
            AxisGridLine()
            AxisTick()
            AxisValueLabel(anchor: .top) {
                if let d = v.as(Double.self) {
                    Text(d >= 1024 ? String(format: "%.1f GB", d / 1024.0) : "\(Int(d)) MB")
                        .font(.system(size: 9.5).monospacedDigit())
                        .fixedSize()
                }
            }
        }
    }

    private var editorAxis: some AxisContent {
        AxisMarks { v in
            AxisValueLabel {
                if let str = v.as(String.self) {
                    Text(str).font(.system(size: 11)).lineLimit(1).fixedSize()
                }
            }
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
        case .autoClaw: return Color(red: 0.95, green: 0.45, blue: 0.15)
        case .ccSwitch: return Color(red: 0.35, green: 0.65, blue: 0.85)
        case .yDevSphere: return Color(red: 0.45, green: 0.35, blue: 0.85)
        case .devin: return Color(red: 0.25, green: 0.75, blue: 0.65)
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

    private static func downsample(_ source: NSImage, targetSize: NSSize = NSSize(width: 20, height: 20)) -> NSImage {
        let pixelWidth = 40
        let pixelHeight = 40
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return source }
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return source
        }

        var proposedRect = NSRect(origin: .zero, size: targetSize)
        guard let cgImage = source.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return source
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        guard let downscaledCG = context.makeImage() else { return source }
        let rep = NSBitmapImageRep(cgImage: downscaledCG)
        rep.size = targetSize
        let downsampled = NSImage(size: targetSize)
        downsampled.addRepresentation(rep)
        return downsampled
    }

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
            let img = Self.downsample(NSWorkspace.shared.icon(forFile: path))
            cache[editor] = img
            return img
        }

        // 2. LaunchServices bundle identifier query
        for bid in editor.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                let img = Self.downsample(NSWorkspace.shared.icon(forFile: url.path))
                cache[editor] = img
                return img
            }
        }

        // 3. Fallback for uninstalled app: macOS system package icon
        let pkgIcon: NSImage
        if #available(macOS 12.0, *) {
            pkgIcon = Self.downsample(NSWorkspace.shared.icon(for: UTType.package))
        } else {
            pkgIcon = Self.downsample(NSWorkspace.shared.icon(forFileType: "pkg"))
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

