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
        ZStack {
            if let editor = store.selectedEditor {
                AgentEditorDetailPage(
                    editor: editor,
                    customName: store.selectedCustomName,
                    customAppPath: store.selectedCustomAppPath
                )
                .id(store.selectedCustomName ?? editor.rawValue)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                ))
            } else {
                AgentOverviewPage()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.selectedEditor)
        .onAppear { store.scanIfNeeded() }
        .onExitCommand {
            withAnimation(.easeInOut(duration: 0.22)) {
                store.resetSelection()
            }
        }
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
                    if store.isOverviewFiltering {
                        searchResultsSection
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
                Button { store.addCustomApplication() } label: {
                    Label(l10n.agentAddCustomAppShort, systemImage: "plus.app")
                }
                .controlSize(.small)
                .help(l10n.agentAddCustomAppHelp)

                Button { store.scan() } label: {
                    Label(store.isScanning ? l10n.loading : l10n.refreshNow, systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(store.isScanning)
                .contextMenu {
                    Button {
                        store.scan(forceFull: true)
                    } label: {
                        Label(l10n.agentForceFullScan, systemImage: "arrow.triangle.2.circlepath")
                    }
                }

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
            HStack(alignment: .center, spacing: 8) {
                Label(l10n.agentEditorsHeader, systemImage: "square.grid.2x2")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { store.addCustomApplication() } label: {
                    Label(l10n.agentAddCustomAppShort, systemImage: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(l10n.agentAddCustomAppHelp)

                AgentSearchField(placeholder: l10n.searchDatabasesPlaceholder, text: $store.searchQuery)
                    .frame(minWidth: 160, maxWidth: 260)
            }

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
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        store.selectEditor(s)
                    }
                } label: { AgentEditorGridCard(summary: s) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var editorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.summaries) { s in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            store.selectEditor(s)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            AgentEditorIconView(editor: s.editor, customAppPath: s.customAppPath, size: 16)
                            Text(s.displayName).font(.system(size: 11)).lineLimit(1)
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
                    .help("\(s.displayName) · \(l10n.agentDbCount(s.databaseCount)) · \(s.conversationCount) \(l10n.conversationsCountLabel)")
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Cross-editor search results (shown only when searching)

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("\(l10n.agentSearchResults) (\(store.filteredEntries.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                AgentScopePicker(selection: $store.selectedScope)
                Toggle(l10n.onlyOrphaned, isOn: $store.showOnlyOrphaned)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundStyle(store.showOnlyOrphaned ? Color.red : Color.secondary)
                    .fixedSize()
                AgentSortPicker(selection: $store.sortOrder)
            }

            if store.filteredEntries.isEmpty {
                Text(l10n.agentDbNoMatch)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                AgentDatabaseList(entries: store.filteredEntries, showsEditor: true, query: store.searchQuery)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

private struct AgentEditorGridCard: View {
    let summary: AgentEditorSummary
    @ObservedObject private var l10n = L10n.shared
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AgentEditorIconView(editor: summary.editor, customAppPath: summary.customAppPath, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(summary.displayName).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
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
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            store.selectedEditor = s.editor
                        }
                    } label: {
                        Rectangle()
                            .fill(s.editor.themeColor.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .frame(width: max(4, (geo.size.width - CGFloat(summaries.count - 1) * 2) * (Double(s.totalBytes) / total)))
                    .help("\(s.editor.displayName): \(ByteFormat.disk(s.totalBytes)) (\(l10n.agentDbCount(s.databaseCount)))")
                }
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: summaries.map(\.totalBytes))
    }

    private func legend(_ summaries: [AgentEditorSummary]) -> some View {
        let total = Double(max(1, store.totalSize))
        return FlowLayout(spacing: 8) {
            ForEach(summaries) { s in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        store.selectedEditor = s.editor
                    }
                } label: {
                    HStack(spacing: 5) {
                        Circle().fill(s.editor.themeColor).frame(width: 7, height: 7)
                        Text(s.editor.displayName).font(.system(size: 10.5)).lineLimit(1)
                        Text("\(ByteFormat.short(s.totalBytes)) (\(Int((Double(s.totalBytes) / total * 100).rounded()))%)")
                            .font(.system(size: 9.5).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.04)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if let (_, editorName): (Double, String) = proxy.value(at: location) {
                            if let s = summaries.first(where: { $0.editor.displayName == editorName }) {
                                store.selectedEditor = s.editor
                            }
                        }
                    }
            }
        }
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
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if let (_, editorName): (Double, String) = proxy.value(at: location) {
                            if let s = summaries.first(where: { $0.editor.displayName == editorName }) {
                                store.selectedEditor = s.editor
                            }
                        }
                    }
            }
        }
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

