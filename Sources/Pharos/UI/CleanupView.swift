import SwiftUI
import PharosCore

/// Main window cleanup hub.
/// Provides four specialized cleaning modules:
/// 1. System & Caches (Pinned temp + system logs, trash, browser caches, app caches, toolchains)
/// 2. App Leftovers (Uninstalled application data in Application Support, Containers, Saved State)
/// 3. Project Purge (Developer dependencies & build artifacts purge — npkill style)
/// 4. Dev & AI Tools (Homebrew deep clean, Local AI models & blob GC, Docker VM & Xcode simulators)
struct CleanupView: View {
    enum CleanupTab: String, CaseIterable, Identifiable {
        case caches, leftovers, purges, devAI
        var id: String { rawValue }
    }

    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = WindowRouter.shared

    @State private var activeTab: CleanupTab = .caches
    @State private var selectedGroup: DiskCleaner.Group? = nil
    private let otherGroups: [DiskCleaner.Group] = [
        .systemLogs, .trashBins, .browserCaches, .appCaches, .apple, .packages
    ]

    var body: some View {
        PharosPage {
            if let targetGroup = selectedGroup {
                groupFocusedHeader(targetGroup)
            } else {
                header
            }
        } content: {
            if let report = cleanup.report {
                ReportBanner(report: report)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }

            if cleanup.shouldShowFirstLaunchPermissionBanner {
                FirstLaunchPermissionCard()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }

            if let targetGroup = selectedGroup {
                groupFocusedContent(targetGroup)
            } else {
                // Tab Selection Bar
                tabPicker
                    .padding(.bottom, PharosSpacing.s)

                switch activeTab {
                case .caches:
                    cachesContent
                case .leftovers:
                    AppLeftoversView()
                case .purges:
                    ProjectPurgeView()
                case .devAI:
                    DevAndAIView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: cleanup.report != nil)
        .onAppear {
            cleanup.viewAppeared()
            if let target = router.cleanupTargetGroup {
                activeTab = .caches
                selectedGroup = target
                router.cleanupTargetGroup = nil
            }
        }
        .onChange(of: router.cleanupTargetGroup) { _, target in
            if let target {
                withAnimation(.easeInOut(duration: 0.2)) {
                    activeTab = .caches
                    selectedGroup = target
                }
                router.cleanupTargetGroup = nil
            }
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $activeTab) {
            Label(l10n.tabSystemCaches, systemImage: "archivebox").tag(CleanupTab.caches)
            Label(l10n.tabAppLeftovers, systemImage: "app.badge.xmark").tag(CleanupTab.leftovers)
            Label(l10n.tabProjectPurge, systemImage: "wrench.and.screwdriver").tag(CleanupTab.purges)
            Label(l10n.tabDevAndAI, systemImage: "cpu").tag(CleanupTab.devAI)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var cachesContent: some View {
        VStack(spacing: PharosSpacing.m) {
            PinnedTempSection(onSelectDetail: { group in
                withAnimation(.easeInOut(duration: 0.2)) { selectedGroup = group }
            })

            PharosSectionHeader(title: l10n.otherCaches, systemImage: "archivebox")
                .padding(.horizontal, PharosSpacing.xs)

            VStack(spacing: PharosSpacing.m) {
                ForEach(otherGroups, id: \.self) { group in
                    CacheGroupSection(group: group) { selected in
                        withAnimation(.easeInOut(duration: 0.2)) { selectedGroup = selected }
                    }
                }
            }
        }
    }

    private func groupFocusedHeader(_ group: DiskCleaner.Group) -> some View {
        let bytes = cleanup.bytes(in: group)
        let title: String
        let subtitle: String
        let cleanBtnTitle: String

        switch group {
        case .packages:
            title = l10n.languageCachesCleanupTitle
            subtitle = l10n.languageCachesCleanupSubtitle
            cleanBtnTitle = l10n.cleanLanguageCachesGroup
        case .appCaches:
            title = l10n.appCachesCleanupTitle
            subtitle = l10n.appCachesCleanupSubtitle
            cleanBtnTitle = l10n.cleanGroup
        case .apple:
            title = l10n.appleToolchainCleanupTitle
            subtitle = l10n.appleToolchainCleanupSubtitle
            cleanBtnTitle = l10n.cleanGroup
        case .temp:
            title = l10n.tempCleanupTitle
            subtitle = l10n.tempCleanupSubtitle
            cleanBtnTitle = l10n.cleanTemp
        case .systemLogs:
            title = l10n.systemLogsCleanupTitle
            subtitle = l10n.systemLogsCleanupSubtitle
            cleanBtnTitle = l10n.cleanGroup
        case .trashBins:
            title = l10n.trashBinsCleanupTitle
            subtitle = l10n.trashBinsCleanupSubtitle
            cleanBtnTitle = l10n.cleanGroup
        case .browserCaches:
            title = l10n.browserCachesCleanupTitle
            subtitle = l10n.browserCachesCleanupSubtitle
            cleanBtnTitle = l10n.cleanGroup
        }

        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedGroup = nil
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(l10n.allDiskCleanup)
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    cleanup.scan()
                } label: {
                    Label(cleanup.isScanning ? l10n.scanning : l10n.cleanupScan,
                          systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(cleanup.isBusy)

                ConfirmButton(title: cleanBtnTitle,
                              icon: "trash",
                              prominent: true,
                              busy: cleanup.cleaning == .group(group),
                              disabled: cleanup.isBusy || bytes == 0) {
                    cleanup.clean(group: group)
                }
            }
        }
    }

    private func groupFocusedContent(_ group: DiskCleaner.Group) -> some View {
        let rows = cleanup.rows(in: group)
        let bytes = cleanup.bytes(in: group)

        return VStack(alignment: .leading, spacing: PharosSpacing.m) {
            PharosCard {
                HStack(alignment: .center, spacing: PharosSpacing.m) {
                    Image(systemName: l10n.groupIcon(group))
                        .font(.system(size: 20))
                        .foregroundStyle(PharosColor.accent)
                        .frame(width: 40, height: 40)
                        .background(PharosColor.fill, in: RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous))

                    VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                        Text(l10n.groupTitle(group))
                            .font(PharosFont.rowLabel)
                        Text(l10n.locationCount(rows.count))
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: PharosSpacing.xxs) {
                        Text(cleanup.rows.isEmpty ? "–" : ByteFormat.short(bytes))
                            .font(PharosFont.metricValue)
                            .foregroundStyle(bytes == 0 ? PharosColor.textSecondary : PharosColor.textPrimary)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.25), value: bytes)
                        Text(l10n.cacheSize)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textTertiary)
                    }
                }
            }

            if group == .temp {
                HStack(spacing: PharosSpacing.s) {
                    Text(l10n.keepNewerThan).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                    Picker("", selection: $cleanup.tempRetentionHours) {
                        ForEach(CleanupStore.tempRetentionChoices, id: \.self) {
                            Text(l10n.retentionLabel(hours: $0)).tag($0)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                    .disabled(cleanup.isBusy)
                    Spacer()
                }
                .padding(.vertical, PharosSpacing.xs)
            }

            RowList(rows: rows)
        }
    }

    private var header: some View {
        PharosPageHeader(title: l10n.diskCleanup, subtitle: l10n.cleanupIntro) {
            HStack(spacing: PharosSpacing.s) {
                // FDA Status Pill
                Button {
                    cleanup.openFullDiskAccessSettings()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: cleanup.hasFullDiskAccess ? "checkmark.shield.fill" : "shield")
                            .font(.system(size: 10))
                        Text(cleanup.hasFullDiskAccess ? l10n.fullDiskAccessGranted : l10n.fullDiskAccessNotGranted)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(cleanup.hasFullDiskAccess ? Color.green.opacity(0.12) : Color.secondary.opacity(0.1)))
                    .foregroundStyle(cleanup.hasFullDiskAccess ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(l10n.fullDiskAccessHelp)

                PharosActionButton(
                    cleanup.isScanning ? l10n.scanning : l10n.cleanupScan,
                    systemImage: "arrow.clockwise",
                    role: .standard
                ) {
                    cleanup.scan()
                }
                .controlSize(.small)
                .disabled(cleanup.isBusy)

                ConfirmButton(title: l10n.cleanEverything, icon: "trash",
                              busy: cleanup.cleaning == .all,
                              disabled: cleanup.isBusy || cleanup.totalBytes == 0) {
                    cleanup.cleanAll()
                }
                .help(l10n.cleanEverythingHelp(ByteFormat.short(cleanup.totalBytes)))
            }
        }
    }
}

/// One-time first-launch permission recommendation card (CleanMyMac style).
private struct FirstLaunchPermissionCard: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        PharosCard {
            HStack(alignment: .top, spacing: PharosSpacing.m) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 22))
                    .foregroundStyle(PharosColor.accent)
                    .frame(width: 38, height: 38)
                    .background(PharosColor.fill, in: RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous))

                VStack(alignment: .leading, spacing: PharosSpacing.xs) {
                    Text(l10n.permissionOnboardingTitle)
                        .font(PharosFont.rowLabel)
                    Text(l10n.permissionOnboardingMessage)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: PharosSpacing.s) {
                        Button {
                            cleanup.openFullDiskAccessSettings()
                        } label: {
                            Label(l10n.openSystemSettings, systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.pharosPrimary)
                        .controlSize(.small)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                cleanup.dismissFirstLaunchPermissionPrompt()
                            }
                        } label: {
                            Text(l10n.gotIt)
                        }
                        .buttonStyle(.pharos)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
                Spacer()
            }
        }
        .padding(.bottom, PharosSpacing.xs)
    }
}

/// The temp dirs cleaned every day or two: /tmp, /var/tmp, var/folders T + C.
private struct PinnedTempSection: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    let onSelectDetail: ((DiskCleaner.Group) -> Void)?

    init(onSelectDetail: ((DiskCleaner.Group) -> Void)? = nil) {
        self.onSelectDetail = onSelectDetail
    }

    var body: some View {
        let bytes = cleanup.bytes(in: .temp)
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack(alignment: .center, spacing: PharosSpacing.s) {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(PharosColor.accent)
                        .rotationEffect(.degrees(45))
                    VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                        if let onSelectDetail {
                            Button {
                                onSelectDetail(.temp)
                            } label: {
                                HStack(spacing: PharosSpacing.xs) {
                                    Text(l10n.groupTitle(.temp))
                                        .font(PharosFont.rowLabel)
                                        .foregroundStyle(PharosColor.textPrimary)
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PharosColor.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .help(l10n.viewGroupDetailHelp(l10n.groupTitle(.temp)))
                        } else {
                            Text(l10n.groupTitle(.temp))
                                .font(PharosFont.rowLabel)
                        }
                        Text(l10n.tempGroupHint)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                    }
                    Spacer()
                    Text(cleanup.rows.isEmpty ? "–" : ByteFormat.short(bytes))
                        .font(PharosFont.metricValue)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.25), value: bytes)
                }

                HStack(spacing: PharosSpacing.s) {
                    Text(l10n.keepNewerThan)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                    Picker("", selection: $cleanup.tempRetentionHours) {
                        ForEach(CleanupStore.tempRetentionChoices, id: \.self) {
                            Text(l10n.retentionLabel(hours: $0)).tag($0)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                    .disabled(cleanup.isBusy)
                    Spacer()
                    ConfirmButton(title: l10n.cleanTemp, icon: "sparkles", prominent: true,
                                  busy: cleanup.cleaning == .group(.temp),
                                  disabled: cleanup.isBusy || bytes == 0) {
                        cleanup.clean(group: .temp)
                    }
                }

                RowList(rows: cleanup.rows(in: .temp))
            }
        }
    }
}

/// A collapsible group of long-lived caches with its own clean button.
private struct CacheGroupSection: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    let group: DiskCleaner.Group
    let onSelectDetail: (DiskCleaner.Group) -> Void
    @AppStorage private var expanded: Bool

    init(group: DiskCleaner.Group, onSelectDetail: @escaping (DiskCleaner.Group) -> Void) {
        self.group = group
        self.onSelectDetail = onSelectDetail
        _expanded = AppStorage(wrappedValue: group == .packages, "cleanupGroupExpanded.\(group.rawValue)")
    }

    var body: some View {
        let bytes = cleanup.bytes(in: group)
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack(spacing: PharosSpacing.s) {
                    // Chevron button for inline expand/collapse
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { expanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Title + Icon: Click to enter dedicated detail page!
                    Button {
                        onSelectDetail(group)
                    } label: {
                        HStack(spacing: PharosSpacing.xs + 2) {
                            Image(systemName: l10n.groupIcon(group))
                                .font(.system(size: 12))
                                .foregroundStyle(PharosColor.accent)
                            Text(l10n.groupTitle(group))
                                .font(PharosFont.rowLabel)
                                .foregroundStyle(PharosColor.textPrimary)
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10.5))
                                .foregroundStyle(PharosColor.textTertiary)
                            Text(l10n.locationCount(cleanup.rows(in: group).count))
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textTertiary)
                            Spacer()
                            Text(cleanup.rows.isEmpty ? "–" : ByteFormat.short(bytes))
                                .font(PharosFont.captionDigits)
                                .foregroundStyle(bytes == 0 ? PharosColor.textSecondary : PharosColor.textPrimary)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.25), value: bytes)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(l10n.viewGroupDetailHelp(l10n.groupTitle(group)))

                    ConfirmButton(title: l10n.cleanGroup, icon: "trash",
                                  busy: cleanup.cleaning == .group(group),
                                  disabled: cleanup.isBusy || bytes == 0) {
                        cleanup.clean(group: group)
                    }
                    .frame(width: 120, alignment: .trailing)
                }
                if expanded {
                    RowList(rows: cleanup.rows(in: group))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

private struct RowList: View {
    let rows: [CleanupStore.Row]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                if index > 0 {
                    PharosListDivider()
                }
                CleanupRowView(row: rows[index])
                    .padding(.horizontal, PharosSpacing.xs)
                    .padding(.vertical, PharosSpacing.s)
            }
        }
    }
}

/// Result of the last clean. Orange when nothing could be freed, so a no-op
/// clean is never silent.
private struct ReportBanner: View {
    @ObservedObject private var l10n = L10n.shared
    let report: CleanupStore.Report

    var body: some View {
        let r = report.result
        let freedNothing = r.freedBytes == 0
        let msg = freedNothing
            ? l10n.nothingFreed(failed: r.failedCount)
            : l10n.freedReport(ByteFormat.short(r.freedBytes), files: r.removedCount, failed: r.failedCount)
        PharosBanner(
            kind: freedNothing ? .warning : .success,
            text: "\(scopeTitle): \(msg)"
        )
    }

    private var scopeTitle: String {
        switch report.scope {
        case .all: return l10n.cleanEverything
        case .group(let g): return l10n.groupTitle(g)
        case .row(let id): return l10n.cleanupTargetTitle(id)
        case .subItem(let path): return (path as NSString).lastPathComponent
        case .leftovers: return l10n.tabAppLeftovers
        case .projectPurge: return l10n.tabProjectPurge
        case .homebrew: return l10n.homebrewSectionTitle
        case .aiModel(let name): return name
        case .toolchain(let name): return name
        }
    }
}

/// One target row with expandable sub-item inspection and its own clean button.
private struct CleanupRowView: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    let row: CleanupStore.Row

    private var bytes: UInt64 { row.bytes ?? 0 }
    private var isExpanded: Bool { cleanup.expandedRowIds.contains(row.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if bytes > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            cleanup.toggleSubItems(for: row.target)
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundStyle(PharosColor.accent)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? l10n.hideSubItems : l10n.viewSubItems)
                } else {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(l10n.cleanupTargetTitle(row.id))
                            .font(.system(size: 12, weight: .medium))

                        if bytes > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    cleanup.toggleSubItems(for: row.target)
                                }
                            } label: {
                                Text(isExpanded ? l10n.hideSubItems : l10n.viewSubItems)
                                    .font(.system(size: 9))
                                    .foregroundStyle(PharosColor.accent.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(row.target.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 8)

                Text(row.bytes.map { ByteFormat.short($0) } ?? "–")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(bytes == 0 ? Color.secondary : Color.primary)
                    .frame(width: 48, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.25), value: bytes)

                ConfirmButton(title: l10n.cleanRow, icon: "trash", small: true,
                              busy: cleanup.cleaning == .row(row.id),
                              disabled: cleanup.isBusy || bytes == 0) {
                    cleanup.cleanOne(id: row.id)
                }
                .frame(width: 96, alignment: .trailing)
            }

            if isExpanded {
                SubItemsListView(target: row.target)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Two-step destructive button: first click arms (turns red), second click
/// runs. Disarms after a few seconds or as soon as another operation starts.
struct ConfirmButton: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    let title: String
    let icon: String
    var prominent = false
    var small = false
    let busy: Bool
    let disabled: Bool
    let action: () -> Void
    @State private var armed = false

    var body: some View {
        Group {
            if busy {
                HStack(spacing: PharosSpacing.xs) {
                    ProgressView().controlSize(.mini)
                    Text(l10n.cleaning).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                }
            } else if armed {
                HStack(spacing: PharosSpacing.xs) {
                    Button {
                        armed = false
                        action()
                    } label: {
                        Text(l10n.confirmClean).font(PharosFont.caption)
                    }
                    .buttonStyle(.pharosDestructive)
                    .controlSize(.small)
                    IconButton(systemImage: "xmark", help: l10n.cancel) { armed = false }
                }
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    armed = false
                }
            } else if prominent {
                Button { armed = true } label: { Label(title, systemImage: icon) }
                    .buttonStyle(.pharosPrimary)
                    .controlSize(.regular)
                    .disabled(disabled)
            } else {
                Button { armed = true } label: {
                    Label(title, systemImage: icon).font(PharosFont.caption)
                }
                .buttonStyle(.pharos)
                .controlSize(.small)
                .disabled(disabled)
            }
        }
        .onChange(of: cleanup.isBusy) { _, nowBusy in if nowBusy { armed = false } }
    }
}

/// One shared instance so the popover entry and main window see the same rows.
@MainActor
enum CleanupStoreHolder {
    static let shared = CleanupStore()
}
