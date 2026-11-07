import AppKit
import SwiftUI
import PharosCore

struct AgentOptimizationView: View {
    let entry: AgentDatabaseEntry
    @ObservedObject private var store = AgentChatStore.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLevel: CompactionLevel = .level1StreamEvents
    @State private var autoBackup: Bool = true
    @State private var vacuumAfter: Bool = true
    @State private var showConfirmAlert: Bool = false
    @State private var restoreTargetBackup: AgentBackupSnapshot? = nil
    @State private var showRestoreAlert: Bool = false

    private var profile: AgentDatabaseProfile? {
        store.profiles[entry.id]
    }

    private var isProfiling: Bool {
        store.isProfiling[entry.id] ?? false
    }

    private var isCompacting: Bool {
        store.isCompacting[entry.id] ?? false
    }

    private var exclusivity: (isRunning: Bool, pids: [Int32]) {
        ProcessExclusivityGuard.check(editor: entry.editor)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: PharosSpacing.m) {
                    if exclusivity.isRunning {
                        exclusivityWarningBanner
                    }

                    if let err = store.optimizationErrorMessage {
                        errorBanner(err)
                    }

                    if let result = store.compactionResult {
                        successBanner(result)
                    }

                    if isProfiling && profile == nil {
                        loadingProfileView
                    } else if entry.isEncrypted {
                        encryptedDatabaseView
                    } else if let prof = profile {
                        healthScoreAndMetrics(prof)
                        tableBreakdownSection(prof)
                        compactionOptionsSection(prof)
                        if !store.backupsForOptimizing.isEmpty {
                            backupsSection
                        }
                        if !prof.topHeavySessions.isEmpty {
                            topSessionsSection(prof)
                        }
                    } else {
                        profileFailedView
                    }
                }
                .padding(PharosSpacing.l)
                .pharosSlimScroller()
            }

            Divider()
            bottomActionBar
        }
        .frame(minWidth: 700, idealWidth: 760, maxWidth: 840, minHeight: 600, idealHeight: 700, maxHeight: 860)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(l10n.agentStartCompaction, isPresented: $showConfirmAlert) {
            Button(l10n.cancel, role: .cancel) {}
            Button(l10n.agentStartCompaction, role: .destructive) {
                let options = CompactionOptions(
                    level: selectedLevel,
                    autoBackup: autoBackup,
                    vacuumAfter: vacuumAfter
                )
                store.compact(entry: entry, options: options)
            }
        } message: {
            if let prof = profile {
                Text("\(entry.workspaceName)\n\n" + l10n.agentCompactionMessage(level: selectedLevel, reclaimable: ByteFormat.disk(prof.reclaimableBytes)))
            } else {
                Text(entry.workspaceName)
            }
        }
        .alert(l10n.agentRestoreConfirmTitle, isPresented: $showRestoreAlert) {
            Button(l10n.cancel, role: .cancel) { restoreTargetBackup = nil }
            Button(l10n.agentRestoreBackupButton, role: .destructive) {
                if let target = restoreTargetBackup {
                    store.restoreBackup(entry: entry, backupPath: target.backupPath)
                    restoreTargetBackup = nil
                }
            }
        } message: {
            if let target = restoreTargetBackup {
                Text(l10n.agentRestoreConfirmMsg(target.backupPath))
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: PharosSpacing.m) {
            AgentEditorIconView(editor: entry.editor, customAppPath: entry.customAppPath, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(entry.workspaceName)
                        .font(PharosFont.sectionTitle)
                        .lineLimit(1)
                    Text(entry.editor.displayName)
                        .font(PharosFont.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                        .foregroundStyle(.secondary)
                    AgentScopeBadge(scope: entry.scope)
                }
                HStack(spacing: 6) {
                    Text(entry.filePath)
                        .font(PharosFont.technical)
                        .foregroundStyle(PharosColor.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                        store.revealInFinder(entry)
                    }
                }
            }
            Spacer()
            IconButton(systemImage: "xmark", help: l10n.back) {
                dismiss()
            }
        }
        .padding(.horizontal, PharosSpacing.l)
        .padding(.vertical, PharosSpacing.m)
    }

    // MARK: - Exclusivity Warning Banner

    private var exclusivityWarningBanner: some View {
        HStack(alignment: .top, spacing: PharosSpacing.s) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(PharosColor.error)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.agentEditorRunningWarning)
                    .font(PharosFont.rowLabel)
                    .foregroundStyle(PharosColor.error)
                Text(l10n.agentEditorRunningDesc(entry.editor.displayName, pids: exclusivity.pids))
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
            }
            Spacer()
            Text(l10n.agentProcessBlocked)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(PharosColor.error.opacity(0.15)))
                .foregroundStyle(PharosColor.error)
        }
        .padding(PharosSpacing.m)
        .background(RoundedRectangle(cornerRadius: 8).fill(PharosColor.error.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PharosColor.error.opacity(0.3), lineWidth: 1))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: PharosSpacing.s) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(PharosColor.error)
            Text(message)
                .font(PharosFont.caption)
                .foregroundStyle(PharosColor.textPrimary)
            Spacer()
            IconButton(systemImage: "xmark", help: l10n.back) {
                store.optimizationErrorMessage = nil
            }
        }
        .padding(PharosSpacing.m)
        .background(RoundedRectangle(cornerRadius: 8).fill(PharosColor.error.opacity(0.08)))
    }

    private func successBanner(_ res: CompactionResult) -> some View {
        HStack(spacing: PharosSpacing.s) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(PharosColor.success)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.agentCompactionSuccess(
                    orig: ByteFormat.disk(res.initialSizeBytes),
                    final: ByteFormat.disk(res.finalSizeBytes),
                    saved: ByteFormat.disk(res.bytesReclaimed)
                ))
                .font(PharosFont.rowLabel)
                .foregroundStyle(PharosColor.textPrimary)

                if res.deletedCount > 0 {
                    Text(l10n.isZh
                        ? "清理详情：共删除 \(res.deletedCount) 条冗余记录，耗时 \(String(format: "%.2f", res.duration)) 秒，已完成原生 VACUUM 收缩"
                        : "Details: \(res.deletedCount) rows pruned in \(String(format: "%.2f", res.duration))s, native VACUUM completed.")
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                }
            }
            Spacer()
        }
        .padding(PharosSpacing.m)
        .background(RoundedRectangle(cornerRadius: 8).fill(PharosColor.success.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PharosColor.success.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Health Score & Capacity Hero Cards

    private func healthScoreAndMetrics(_ prof: AgentDatabaseProfile) -> some View {
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.agentHealthScore)
                            .font(PharosFont.rowLabel)
                            .foregroundStyle(PharosColor.textSecondary)
                        HStack(spacing: 8) {
                            Text("\(prof.healthScore)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(healthColor(prof.healthScore))
                            Text("/ 100")
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textTertiary)
                            healthBadge(prof.healthScore)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(l10n.agentReclaimableSpace)
                            .font(PharosFont.rowLabel)
                            .foregroundStyle(PharosColor.textSecondary)
                        Text(ByteFormat.disk(prof.reclaimableBytes))
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(prof.reclaimableBytes > 50_000_000 ? PharosColor.accent : PharosColor.success)
                    }
                }

                Divider()

                HStack(spacing: PharosSpacing.l) {
                    metricItem(
                        title: l10n.agentTotalStorage,
                        value: ByteFormat.disk(prof.totalPhysicalBytes),
                        sub: "\(prof.pageCount) pages",
                        icon: "internaldrive"
                    )
                    metricItem(
                        title: l10n.agentCoreStorage,
                        value: ByteFormat.disk(prof.totalPhysicalBytes > prof.reclaimableBytes ? prof.totalPhysicalBytes - prof.reclaimableBytes : 0),
                        sub: l10n.agentCoreStorage,
                        icon: "bubble.left.and.bubble.right.fill"
                    )
                    metricItem(
                        title: l10n.agentRedundantStorage,
                        value: ByteFormat.disk(prof.reclaimableBytes),
                        sub: "\(Int((Double(prof.reclaimableBytes) / Double(max(1, prof.totalPhysicalBytes)) * 100).rounded()))%",
                        icon: "sparkles",
                        accent: prof.reclaimableBytes > 100_000_000
                    )
                    metricItem(
                        title: l10n.agentFreelistHoles,
                        value: ByteFormat.disk(prof.freelistBytes),
                        sub: "\(prof.freelistCount) holes (\(String(format: "%.1f", prof.fragmentationRatio))%)",
                        icon: "circle.grid.cross"
                    )
                }
            }
        }
    }

    private func metricItem(title: String, value: String, sub: String, icon: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(accent ? PharosColor.accent : PharosColor.textTertiary)
                Text(title)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(accent ? PharosColor.accent : PharosColor.textPrimary)
            Text(sub)
                .font(PharosFont.technical)
                .foregroundStyle(PharosColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func healthColor(_ score: Int) -> Color {
        if score >= 80 { return PharosColor.success }
        if score >= 60 { return Color.orange }
        return PharosColor.error
    }

    private func healthBadge(_ score: Int) -> some View {
        let label: String = {
            if score >= 80 { return l10n.agentHealthHealthy }
            if score >= 60 { return l10n.agentHealthModerate }
            if score >= 40 { return l10n.agentHealthBloated }
            return l10n.agentHealthCritical
        }()
        let color = healthColor(score)
        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
            .foregroundStyle(color)
    }

    // MARK: - Table Space Breakdown

    private func tableBreakdownSection(_ prof: AgentDatabaseProfile) -> some View {
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                HStack {
                    Label(l10n.tableSpaceBreakdown, systemImage: "tablecells")
                        .font(PharosFont.rowLabel)
                    Spacer()
                    Text(l10n.agentDeepDiagnosticsDesc)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textTertiary)
                }

                Divider()

                let total = Double(max(1, prof.totalPhysicalBytes))
                VStack(spacing: 6) {
                    ForEach(prof.tableBreakdown, id: \.name) { tbl in
                        HStack(spacing: 10) {
                            Text(tbl.name)
                                .font(PharosFont.technical)
                                .frame(width: 150, alignment: .leading)
                                .lineLimit(1)

                            if tbl.isBloatCandidate {
                                HStack(spacing: 3) {
                                    Image(systemName: "flame.fill").font(.system(size: 8))
                                    Text(l10n.agentBloatCandidateBadge).font(.system(size: 9, weight: .bold))
                                }
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(PharosColor.error.opacity(0.12)))
                                .foregroundStyle(PharosColor.error)
                            }

                            Spacer()

                            Text("\(tbl.rowCount) \(l10n.agentTableRows)")
                                .font(PharosFont.captionDigits)
                                .foregroundStyle(PharosColor.textTertiary)
                                .frame(width: 90, alignment: .trailing)

                            // Visual bar
                            GeometryReader { geo in
                                let fraction = min(1.0, Double(tbl.payloadBytes) / total)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.primary.opacity(0.04))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(tbl.isBloatCandidate ? PharosColor.error.opacity(0.8) : PharosColor.accent.opacity(0.6))
                                        .frame(width: max(2, geo.size.width * fraction))
                                }
                            }
                            .frame(width: 120, height: 8)

                            Text(ByteFormat.disk(tbl.payloadBytes))
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .frame(width: 70, alignment: .trailing)

                            Text("\(String(format: "%.1f", tbl.percentage))%")
                                .font(PharosFont.captionDigits)
                                .foregroundStyle(PharosColor.textTertiary)
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - Compaction Options & Level Selector

    private func compactionOptionsSection(_ prof: AgentDatabaseProfile) -> some View {
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                Label(l10n.agentCompactionTitle, systemImage: "slider.horizontal.3")
                    .font(PharosFont.rowLabel)

                VStack(spacing: 8) {
                    levelCard(
                        level: .level1StreamEvents,
                        title: l10n.agentCompactionLevel1,
                        desc: l10n.agentCompactionLevel1Desc,
                        isRecommended: true
                    )
                    levelCard(
                        level: .level2Checkpoints,
                        title: l10n.agentCompactionLevel2,
                        desc: l10n.agentCompactionLevel2Desc
                    )
                    levelCard(
                        level: .level3OrphanedAndArchive,
                        title: l10n.agentCompactionLevel3,
                        desc: l10n.agentCompactionLevel3Desc
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $autoBackup) {
                        Text(l10n.agentOptionPreflightBackup)
                            .font(PharosFont.caption)
                    }
                    .toggleStyle(.checkbox)

                    Toggle(isOn: $vacuumAfter) {
                        Text(l10n.agentOptionRunVacuum)
                            .font(PharosFont.caption)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    private func levelCard(level: CompactionLevel, title: String, desc: String, isRecommended: Bool = false) -> some View {
        let isSelected = selectedLevel == level
        return Button {
            selectedLevel = level
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? PharosColor.accent : PharosColor.textTertiary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(PharosFont.rowLabel)
                            .foregroundStyle(isSelected ? PharosColor.textPrimary : PharosColor.textSecondary)
                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 8.5, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(PharosColor.accent.opacity(0.15)))
                                .foregroundStyle(PharosColor.accent)
                        }
                    }
                    Text(desc)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? PharosColor.accent.opacity(0.06) : Color.primary.opacity(0.02)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? PharosColor.accent.opacity(0.4) : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Backups Section

    private var backupsSection: some View {
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                HStack {
                    Label(l10n.agentBackupsListTitle, systemImage: "clock.arrow.circlepath")
                        .font(PharosFont.rowLabel)
                    Spacer()
                    Text(l10n.retainLatestRestorePoints)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textTertiary)
                }

                Divider()

                ForEach(store.backupsForOptimizing, id: \.backupPath) { bk in
                    HStack(spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 13))
                            .foregroundStyle(PharosColor.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text((bk.backupPath as NSString).lastPathComponent)
                                .font(PharosFont.technical)
                                .lineLimit(1)
                            Text(Format.relativeAge(bk.createdAt))
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textTertiary)
                        }
                        Spacer()
                        Text(ByteFormat.disk(bk.fileSizeBytes))
                            .font(PharosFont.captionDigits)
                            .foregroundStyle(PharosColor.textSecondary)
                        Button(l10n.agentRestoreBackupButton) {
                            restoreTargetBackup = bk
                            showRestoreAlert = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(exclusivity.isRunning || isCompacting)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    // MARK: - Top Heavy Sessions Section

    private func topSessionsSection(_ prof: AgentDatabaseProfile) -> some View {
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                HStack {
                    Label(l10n.agentTopHeavySessions, systemImage: "chart.bar.doc.horizontal")
                        .font(PharosFont.rowLabel)
                    Spacer()
                    Button(l10n.agentExportAllMarkdown) {
                        store.exportAllSessionsMarkdown(entry: entry)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider()

                ForEach(prof.topHeavySessions, id: \.id) { s in
                    HStack(spacing: 8) {
                        Text(s.title.isEmpty ? s.id : s.title)
                            .font(PharosFont.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(l10n.agentMessages(s.messageCount))
                            .font(PharosFont.captionDigits)
                            .foregroundStyle(PharosColor.textTertiary)
                        Text(ByteFormat.disk(s.sizeBytes))
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .frame(width: 60, alignment: .trailing)
                        Button(l10n.agentExportMarkdown) {
                            store.exportSessionMarkdown(entry: entry, sessionId: s.id, defaultTitle: s.title)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: PharosSpacing.m) {
            Button(l10n.back) {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Spacer()

            if entry.isEncrypted {
                Button {
                    store.backupEntry(entry)
                } label: {
                    Label(l10n.backupDatabase, systemImage: "arrow.down.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else if isCompacting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(l10n.agentCompacting)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                }
            } else {
                Button {
                    showConfirmAlert = true
                } label: {
                    Label(l10n.agentStartCompaction, systemImage: "sparkles")
                        .font(PharosFont.rowLabel)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(exclusivity.isRunning || isProfiling)
                .help(exclusivity.isRunning ? l10n.agentEditorRunningWarning : "")
            }
        }
        .padding(.horizontal, PharosSpacing.l)
        .padding(.vertical, PharosSpacing.m)
    }

    // MARK: - Placeholders & Special States

    private var encryptedDatabaseView: some View {
        VStack(spacing: PharosSpacing.m) {
            PharosCard {
                VStack(alignment: .leading, spacing: PharosSpacing.m) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.purple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(l10n.agentDbEncryptedTitle(for: entry.editor))
                                .font(PharosFont.sectionTitle)
                            Text(l10n.agentDbEncryptedDesc(for: entry.editor))
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()

                    HStack(spacing: PharosSpacing.l) {
                        metricItem(
                            title: l10n.agentTotalStorage,
                            value: ByteFormat.disk(entry.fileSizeBytes),
                            sub: entry.fileName,
                            icon: "internaldrive"
                        )
                        metricItem(
                            title: l10n.conversationsInDb,
                            value: "\(entry.conversationCount)",
                            sub: l10n.sidecarSynced,
                            icon: "bubble.left.and.bubble.right.fill"
                        )
                        metricItem(
                            title: l10n.cipherAlgorithm,
                            value: "SQLCipher",
                            sub: "AES-256-CBC",
                            icon: "key.fill"
                        )
                    }

                    HStack(spacing: 10) {
                        Button {
                            store.backupEntry(entry)
                        } label: {
                            Label(l10n.backupDatabase, systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                            store.revealInFinder(entry)
                        }
                    }
                }
            }

            if !entry.conversations.isEmpty {
                PharosCard {
                    VStack(alignment: .leading, spacing: PharosSpacing.s) {
                        Label(l10n.loadedConversations, systemImage: "list.bullet")
                            .font(PharosFont.rowLabel)
                        Divider()
                        ForEach(entry.conversations.prefix(15), id: \.id) { conv in
                            HStack(spacing: 8) {
                                Text(conv.title)
                                    .font(PharosFont.caption)
                                    .lineLimit(1)
                                Spacer()
                                if let n = conv.messageCount {
                                    Text(l10n.agentMessages(n))
                                        .font(PharosFont.captionDigits)
                                        .foregroundStyle(PharosColor.textTertiary)
                                }
                                if let d = conv.updatedAt ?? conv.createdAt {
                                    Text(Format.relativeAge(d))
                                        .font(PharosFont.caption)
                                        .foregroundStyle(PharosColor.textTertiary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    private var loadingProfileView: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(l10n.loading).font(PharosFont.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var profileFailedView: some View {
        ContentUnavailableView(
            l10n.unableToProfileDb,
            systemImage: "exclamationmark.triangle",
            description: Text(l10n.invalidSqliteFileDesc)
        )
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Project Relocation Sheet

struct AgentRelocationView: View {
    let entry: AgentDatabaseEntry
    @ObservedObject private var store = AgentChatStore.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: PharosSpacing.m) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 24))
                    .foregroundStyle(PharosColor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.agentProjectRelocation)
                        .font(PharosFont.sectionTitle)
                    Text(l10n.agentProjectRelocationDesc)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                }
                Spacer()
                IconButton(systemImage: "xmark", help: l10n.back) {
                    dismiss()
                }
            }
            .padding(.horizontal, PharosSpacing.l)
            .padding(.vertical, PharosSpacing.m)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: PharosSpacing.m) {
                    if store.missingProjects.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(PharosColor.success)
                            Text(l10n.agentNoMissingProjects)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                        .padding(PharosSpacing.l)
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text(l10n.agentMissingProjectsFound(store.missingProjects.count))
                            .font(PharosFont.rowLabel)
                            .foregroundStyle(PharosColor.error)

                        ForEach(store.missingProjects, id: \.originalDirectory) { proj in
                            missingProjectCard(proj)
                        }
                    }
                }
                .padding(PharosSpacing.l)
                .pharosSlimScroller()
            }

            Divider()

            HStack {
                Spacer()
                Button(l10n.back) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(.horizontal, PharosSpacing.l)
            .padding(.vertical, PharosSpacing.m)
        }
        .frame(minWidth: 620, minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func missingProjectCard(_ proj: MissingProjectItem) -> some View {
        PharosCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(proj.originalDirectory)
                            .font(PharosFont.technical)
                            .foregroundStyle(PharosColor.error)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack(spacing: 8) {
                            Text(l10n.agentSessions(proj.sessionCount))
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textTertiary)
                            if let act = proj.lastActiveDate {
                                Text("\(l10n.agentLastActive): \(Format.relativeAge(act))")
                                    .font(PharosFont.caption)
                                    .foregroundStyle(PharosColor.textTertiary)
                            }
                        }
                    }
                    Spacer()
                    Button(l10n.agentSelectNewProjectFolder) {
                        chooseAndRemap(proj)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }

    private func chooseAndRemap(_ proj: MissingProjectItem) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = l10n.agentRemapButton
        panel.title = l10n.agentSelectNewProjectFolder

        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.remapProject(entry: entry, oldDir: proj.originalDirectory, newDir: url.path)
    }
}
