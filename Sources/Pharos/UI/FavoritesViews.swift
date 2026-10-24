import SwiftUI
import PharosCore

/// Live state of one favorite: the running projects inside its folder.
struct FavoriteStatus {
    let favorite: Favorite
    let running: [Project]

    var isRunning: Bool { !running.isEmpty }
    var ports: [ListeningPort] { ListeningPort.merged(running.flatMap(\.ports)) }
    var memoryBytes: UInt64 { running.reduce(0) { $0 + $1.memoryBytes } }
}

extension WorkspaceStore {
    func statuses(_ projects: [Project]) -> [FavoriteStatus] {
        let matches = running(in: projects)
        return favorites.map { FavoriteStatus(favorite: $0, running: matches[$0.id] ?? []) }
    }
}

/// Green dot when running, grey when stopped.
struct RunDot: View {
    let running: Bool
    var body: some View {
        Circle()
            .fill(running ? Color.green : Color.secondary.opacity(0.35))
            .frame(width: 7, height: 7)
    }
}

/// Star toggle used on running projects: pin to / remove from favorites.
struct PinButton: View {
    @ObservedObject private var workspaces = WorkspaceStore.shared
    @ObservedObject private var l10n = L10n.shared
    let project: Project
    var large = false

    var body: some View {
        let fav = workspaces.favorite(forDirectory: project.directory)
        if project.directory != nil {
            if large {
                Button {
                    if let fav { workspaces.unpin(id: fav.id) } else { workspaces.pin(project) }
                } label: {
                    Label(fav == nil ? l10n.pinToFavorites : l10n.pinned,
                          systemImage: fav == nil ? "star" : "star.fill")
                }
                .controlSize(.small)
                .help(fav == nil ? l10n.pinHelp : l10n.unpinHelp)
            } else {
                IconButton(systemImage: fav == nil ? "star" : "star.fill",
                           help: fav == nil ? l10n.pinHelp : l10n.unpinHelp,
                           tint: fav == nil ? .secondary : .yellow) {
                    if let fav { workspaces.unpin(id: fav.id) } else { workspaces.pin(project) }
                }
            }
        }
    }
}

/// Red banner for WorkspaceStore errors; dismissible.
struct WorkspaceErrorBanner: View {
    @ObservedObject private var workspaces = WorkspaceStore.shared

    var body: some View {
        if let message = workspaces.errorMessage {
            PharosBanner(kind: .error, text: message) {
                IconButton(systemImage: "xmark", help: L10n.shared.dismiss) { workspaces.errorMessage = nil }
            }
        }
    }
}

/// Favorites table on the Ports Overview page.
struct FavoritesTable: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var workspaces = WorkspaceStore.shared
    @ObservedObject private var l10n = L10n.shared
    var onSelect: (Favorite) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: PharosSpacing.titleToCard) {
            PharosSectionHeader(title: l10n.favorites, systemImage: "star") {
                PharosActionButton(l10n.addWorkspace, systemImage: "plus", role: .standard) {
                    if let id = workspaces.addFolder(), let fav = workspaces.favorite(id: id) { onSelect(fav) }
                }
                .controlSize(.small)
            }
            .padding(.horizontal, PharosSpacing.xs)

            WorkspaceErrorBanner()

            let statuses = workspaces.statuses(store.projects)
            if statuses.isEmpty {
                PharosCard {
                    Text(l10n.favoritesEmpty)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, PharosSpacing.s)
                }
            } else {
                PharosCard {
                    VStack(spacing: 0) {
                        ForEach(Array(statuses.enumerated()), id: \.element.favorite.id) { index, s in
                            if index > 0 {
                                PharosListDivider()
                            }
                            FavoriteTableRow(status: s, onSelect: onSelect)
                                .padding(.horizontal, PharosSpacing.xs)
                                .padding(.vertical, PharosSpacing.s)
                        }
                    }
                }
            }
        }
    }
}

private struct FavoriteTableRow: View {
    @ObservedObject private var workspaces = WorkspaceStore.shared
    @ObservedObject private var l10n = L10n.shared
    let status: FavoriteStatus
    let onSelect: (Favorite) -> Void

    var body: some View {
        let fav = status.favorite
        HStack(spacing: 10) {
            RunDot(running: status.isRunning)
            Button { onSelect(fav) } label: {
                Text(fav.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
            }
            .buttonStyle(.plain)
            .frame(width: 140, alignment: .leading)
            if status.isRunning {
                PortChips(ports: status.ports).fixedSize()
            } else {
                Text(l10n.notRunning).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            Text(fav.command.isEmpty ? l10n.noCommandSet : fav.command)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(fav.command.isEmpty ? Color.orange : Color.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 240, alignment: .trailing)
                .help(fav.command)
            Text(status.isRunning ? ByteFormat.short(status.memoryBytes) : "")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .frame(width: 44, alignment: .trailing)
            if status.isRunning {
                ForEach(status.running) { StopButton(project: $0, compact: true) }
            } else {
                IconButton(systemImage: "play.fill", help: l10n.openInTerminal, tint: .green) {
                    workspaces.openInTerminal(fav)
                }
                .disabled(fav.command.isEmpty)
            }
        }
    }
}

/// Detail page for one favorite: status, command (editable), detected
/// alternatives, and the running projects inside it.
struct FavoriteDetailView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var workspaces = WorkspaceStore.shared
    @ObservedObject private var l10n = L10n.shared
    let favoriteId: String
    var onRemoved: () -> Void = {}

    @State private var editingCommand = false
    @State private var draftCommand = ""
    @State private var draftName = ""
    @State private var editingName = false
    @State private var candidates: [LaunchCandidate] = []
    @State private var confirmRemove = false

    var body: some View {
        if let fav = workspaces.favorite(id: favoriteId) {
            let status = FavoriteStatus(favorite: fav, running: workspaces.running(in: store.projects)[fav.id] ?? [])
            PharosPage {
                header(fav, status)
            } content: {
                WorkspaceErrorBanner()
                if !FileManager.default.fileExists(atPath: fav.directory) {
                    PharosBanner(kind: .warning, text: l10n.folderMissing(fav.directory))
                }
                commandSection(fav, status)
                if !candidates.filter({ $0.command != fav.command }).isEmpty {
                    candidatesSection(fav)
                }
                runningSection(fav, status)
            }
            .task(id: fav.directory) {
                let dir = fav.directory
                candidates = await Task.detached(priority: .utility) {
                    LaunchDetector.candidates(in: dir)
                }.value
            }
        } else {
            ContentUnavailableView(l10n.favorites, systemImage: "star")
        }
    }

    private func header(_ fav: Favorite, _ status: FavoriteStatus) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: PharosSpacing.xs) {
                HStack(spacing: PharosSpacing.s) {
                    RunDot(running: status.isRunning)
                    if editingName {
                        TextField("", text: $draftName)
                            .textFieldStyle(.roundedBorder)
                            .font(PharosFont.pageTitle)
                            .frame(maxWidth: 260)
                            .onSubmit {
                                workspaces.update(id: fav.id, name: draftName)
                                editingName = false
                            }
                    } else {
                        Text(fav.name).font(PharosFont.pageTitle).lineLimit(1)
                        IconButton(systemImage: "pencil", help: l10n.rename) {
                            draftName = fav.name
                            editingName = true
                        }
                    }
                }
                Text(fav.directory)
                    .font(PharosFont.technical)
                    .foregroundStyle(PharosColor.textSecondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text(status.isRunning
                     ? l10n.runningSummary(ports: status.ports.count, memory: ByteFormat.short(status.memoryBytes))
                     : (fav.lastPorts.isEmpty ? l10n.notRunning
                        : l10n.notRunningLastPorts(fav.lastPorts.map { ":\($0)" }.joined(separator: " "))))
                    .font(PharosFont.caption)
                    .foregroundStyle(status.isRunning ? PharosColor.success : PharosColor.textSecondary)
            }
            Spacer()
            HStack(spacing: PharosSpacing.s) {
                Button { workspaces.revealInFinder(fav) } label: {
                    Label(l10n.revealInFinder, systemImage: "folder")
                }
                .buttonStyle(.pharos)
                .controlSize(.small)
                if confirmRemove {
                    Button(l10n.removeFavorite) {
                        workspaces.unpin(id: fav.id)
                        onRemoved()
                    }
                    .buttonStyle(.pharosDestructive)
                    .controlSize(.small)
                    IconButton(systemImage: "xmark", help: l10n.cancel) { confirmRemove = false }
                } else {
                    Button { confirmRemove = true } label: {
                        Label(l10n.removeFavorite, systemImage: "star.slash")
                    }
                    .buttonStyle(.pharos)
                    .controlSize(.small)
                }
            }
        }
    }

    private func commandSection(_ fav: Favorite, _ status: FavoriteStatus) -> some View {
        PharosSection(title: l10n.startCommand, systemImage: "terminal") {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.commandSourceLabel(fav.commandSource))
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textTertiary)
                    Spacer()
                }

                if editingCommand {
                    HStack(spacing: PharosSpacing.s) {
                        TextField(l10n.commandPlaceholder, text: $draftCommand)
                            .textFieldStyle(.roundedBorder)
                            .font(PharosFont.technical)
                            .onSubmit { commitCommand(fav) }
                        PharosActionButton(l10n.save, role: .primary) { commitCommand(fav) }
                            .controlSize(.small)
                        PharosActionButton(l10n.cancel, role: .standard) { editingCommand = false }
                            .controlSize(.small)
                    }
                } else {
                    HStack(spacing: PharosSpacing.s) {
                        Text(fav.command.isEmpty ? l10n.noCommandSet : fav.command)
                            .font(PharosFont.technical)
                            .foregroundStyle(fav.command.isEmpty ? PharosColor.warning : PharosColor.textPrimary)
                            .textSelection(.enabled)
                            .padding(PharosSpacing.s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                                    .fill(PharosColor.fill)
                            )
                        IconButton(systemImage: "pencil", help: l10n.editCommand) {
                            draftCommand = fav.command
                            editingCommand = true
                        }
                        IconButton(systemImage: "doc.on.doc", help: l10n.copyCommand) { workspaces.copyCommand(fav) }
                            .disabled(fav.command.isEmpty)
                    }

                    HStack(spacing: PharosSpacing.s) {
                        PharosActionButton(l10n.openInTerminal, systemImage: "terminal", role: .primary) {
                            workspaces.openInTerminal(fav)
                        }
                        .disabled(fav.command.isEmpty)

                        if status.isRunning {
                            Text(l10n.alreadyRunningHint)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        } else {
                            Text(l10n.openInTerminalHint)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textTertiary)
                        }
                    }
                }
            }
        }
    }

    private func candidatesSection(_ fav: Favorite) -> some View {
        let activeCandidates = candidates.filter { $0.command != fav.command }
        return PharosSection(title: l10n.detectedCommands, systemImage: "sparkles") {
            VStack(spacing: 0) {
                ForEach(activeCandidates.indices, id: \.self) { index in
                    let c = activeCandidates[index]
                    if index > 0 {
                        PharosListDivider()
                    }
                    HStack(spacing: PharosSpacing.s) {
                        Text(c.command)
                            .font(PharosFont.technical)
                            .foregroundStyle(PharosColor.textPrimary)
                        Text(c.origin)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textTertiary)

                        if c.destructive {
                            Label(l10n.destructiveScript, systemImage: "exclamationmark.triangle.fill")
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.warning)
                                .help(l10n.destructiveScriptHelp)
                        } else if c.confidence == .script {
                            Text(l10n.reviewScript)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }

                        Spacer()

                        Button(l10n.useThis) { workspaces.useCandidate(id: fav.id, c) }
                            .buttonStyle(.pharos)
                            .controlSize(.small)
                            .disabled(c.destructive)
                            .help(c.destructive ? l10n.destructiveScriptHelp : "")
                    }
                    .padding(.vertical, PharosSpacing.s)
                }
            }
        }
    }

    @ViewBuilder
    private func runningSection(_ fav: Favorite, _ status: FavoriteStatus) -> some View {
        if status.isRunning {
            PharosSection(title: l10n.runningNow, systemImage: "play.circle") {
                VStack(spacing: 0) {
                    ForEach(status.running.indices, id: \.self) { index in
                        let p = status.running[index]
                        if index > 0 {
                            PharosListDivider()
                        }
                        HStack(spacing: PharosSpacing.s) {
                            Text(p.name)
                                .font(PharosFont.rowLabel)
                            PortChips(ports: p.ports).fixedSize()
                            Text(p.listeners.first?.shortCommand ?? "")
                                .font(PharosFont.technical)
                                .foregroundStyle(PharosColor.textTertiary)
                                .lineLimit(1)
                            Spacer()
                            Text(ByteFormat.short(p.memoryBytes))
                                .font(PharosFont.captionDigits)
                                .fontWeight(.medium)
                            StopButton(project: p, compact: true)
                        }
                        .padding(.vertical, PharosSpacing.s)
                    }
                }
            }
        }
    }

    private func commitCommand(_ fav: Favorite) {
        workspaces.update(id: fav.id, command: draftCommand)
        editingCommand = false
    }
}
