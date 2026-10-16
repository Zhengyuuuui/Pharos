import SwiftUI
import PharosCore

/// Main window page. The temp group (where AI agents and CLIs keep writing) is
/// pinned on top with its own clean button and retention setting; the
/// long-lived caches follow in collapsible groups.
struct CleanupView: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = WindowRouter.shared

    @State private var selectedGroup: DiskCleaner.Group? = nil
    private let otherGroups: [DiskCleaner.Group] = [.appCaches, .apple, .packages]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let targetGroup = selectedGroup {
                    groupFocusedHeader(targetGroup)
                    if let report = cleanup.report { ReportBanner(report: report) }
                    groupFocusedContent(targetGroup)
                } else {
                    header
                    if let report = cleanup.report { ReportBanner(report: report) }
                    PinnedTempSection(onSelectDetail: { group in
                        withAnimation(.easeInOut(duration: 0.2)) { selectedGroup = group }
                    })
                    Text(l10n.otherCaches)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 4)
                    ForEach(otherGroups, id: \.self) { group in
                        CacheGroupSection(group: group) { selected in
                            withAnimation(.easeInOut(duration: 0.2)) { selectedGroup = selected }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            cleanup.viewAppeared()
            if let target = router.cleanupTargetGroup {
                selectedGroup = target
                router.cleanupTargetGroup = nil
            }
        }
        .onChange(of: router.cleanupTargetGroup) { _, target in
            if let target {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedGroup = target
                }
                router.cleanupTargetGroup = nil
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

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: l10n.groupIcon(group))
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.groupTitle(group))
                        .font(.system(size: 14, weight: .semibold))
                    Text(l10n.locationCount(rows.count))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(cleanup.rows.isEmpty ? "–" : ByteFormat.short(bytes))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(bytes == 0 ? Color.secondary : Color.primary)
                    Text(l10n.cacheSize)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))

            if group == .temp {
                HStack(spacing: 10) {
                    Text(l10n.keepNewerThan).font(.system(size: 11)).foregroundStyle(.secondary)
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
                .padding(.vertical, 4)
            }

            RowList(rows: rows)
        }
    }

    private var header: some View {

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.diskCleanup).font(.system(size: 20, weight: .bold))
                Spacer()
                Button {
                    cleanup.scan()
                } label: {
                    Label(cleanup.isScanning ? l10n.scanning : l10n.cleanupScan,
                          systemImage: "arrow.clockwise")
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
            Text(l10n.cleanupIntro)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "pin.fill")
                    .foregroundStyle(Color.accentColor)
                    .rotationEffect(.degrees(45))
                VStack(alignment: .leading, spacing: 2) {
                    if let onSelectDetail {
                        Button {
                            onSelectDetail(.temp)
                        } label: {
                            HStack(spacing: 4) {
                                Text(l10n.groupTitle(.temp)).font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.secondary.opacity(0.6))
                            }
                        }
                        .buttonStyle(.plain)
                        .help(l10n.viewGroupDetailHelp(l10n.groupTitle(.temp)))
                    } else {
                        Text(l10n.groupTitle(.temp)).font(.system(size: 14, weight: .semibold))
                    }
                    Text(l10n.tempGroupHint)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(cleanup.rows.isEmpty ? "–" : ByteFormat.short(bytes))
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
            }

            HStack(spacing: 10) {
                Text(l10n.keepNewerThan).font(.system(size: 11)).foregroundStyle(.secondary)
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
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.25)))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Chevron button for inline expand/collapse
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
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
                    HStack(spacing: 6) {
                        Image(systemName: l10n.groupIcon(group))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentColor)
                        Text(l10n.groupTitle(group))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.secondary.opacity(0.6))
                        Text(l10n.locationCount(cleanup.rows(in: group).count))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(cleanup.rows.isEmpty ? "–" : ByteFormat.short(bytes))
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(bytes == 0 ? Color.secondary : Color.primary)
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
            if expanded { RowList(rows: cleanup.rows(in: group)) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
    }
}


private struct RowList: View {
    let rows: [CleanupStore.Row]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { (row: CleanupStore.Row) in
                CleanupRowView(row: row)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor).opacity(0.5)))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08)))
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
        HStack(spacing: 8) {
            Image(systemName: freedNothing ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(freedNothing ? Color.orange : Color.green)
            Text("\(scopeTitle): ")
                .font(.system(size: 11, weight: .semibold))
            + Text(freedNothing
                   ? l10n.nothingFreed(failed: r.failedCount)
                   : l10n.freedReport(ByteFormat.short(r.freedBytes), files: r.removedCount, failed: r.failedCount))
                .font(.system(size: 11))
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6)
            .fill((freedNothing ? Color.orange : Color.green).opacity(0.1)))
    }

    private var scopeTitle: String {
        switch report.scope {
        case .all: return l10n.cleanEverything
        case .group(let g): return l10n.groupTitle(g)
        case .row(let id): return l10n.cleanupTargetTitle(id)
        }
    }
}

/// One target row with its own clean button.
private struct CleanupRowView: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    let row: CleanupStore.Row

    private var bytes: UInt64 { row.bytes ?? 0 }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: bytes == 0 ? "circle.dashed" : "folder")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(l10n.cleanupTargetTitle(row.id))
                    .font(.system(size: 12, weight: .medium))
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
            ConfirmButton(title: l10n.cleanRow, icon: "trash", small: true,
                          busy: cleanup.cleaning == .row(row.id),
                          disabled: cleanup.isBusy || bytes == 0) {
                cleanup.cleanOne(id: row.id)
            }
            .frame(width: 96, alignment: .trailing)
        }
    }
}

/// Two-step destructive button: first click arms (turns red), second click
/// runs. Disarms after a few seconds or as soon as another operation starts.
private struct ConfirmButton: View {
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
                HStack(spacing: 5) {
                    ProgressView().controlSize(.mini)
                    Text(l10n.cleaning).font(.system(size: small ? 10 : 11)).foregroundStyle(.secondary)
                }
            } else if armed {
                HStack(spacing: 4) {
                    Button {
                        armed = false
                        action()
                    } label: {
                        Text(l10n.confirmClean).font(.system(size: small ? 10 : 11, weight: .semibold))
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
            } else if prominent {
                Button { armed = true } label: { Label(title, systemImage: icon) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(disabled)
            } else {
                Button { armed = true } label: {
                    Label(title, systemImage: icon).font(.system(size: small ? 10 : 11))
                }
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
