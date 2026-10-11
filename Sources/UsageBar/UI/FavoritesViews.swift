import SwiftUI
import UsageBarCore

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
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(message).font(.system(size: 11)).textSelection(.enabled)
                Spacer()
                IconButton(systemImage: "xmark", help: L10n.shared.dismiss) { workspaces.errorMessage = nil }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.1)))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.favorites).font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    if let id = workspaces.addFolder(), let fav = workspaces.favorite(id: id) { onSelect(fav) }
                } label: {
                    Label(l10n.addWorkspace, systemImage: "plus")
                }
                .controlSize(.small)
            }
            WorkspaceErrorBanner()
            let statuses = workspaces.statuses(store.projects)
            if statuses.isEmpty {
                Text(l10n.favoritesEmpty)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(statuses.enumerated()), id: \.element.favorite.id) { index, s in
                        FavoriteTableRow(status: s, onSelect: onSelect)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(index.isMultiple(of: 2) ? Color.primary.opacity(0.03) : .clear)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08)))
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(fav, status)
                    WorkspaceErrorBanner()
                    if !FileManager.default.fileExists(atPath: fav.directory) {
                        Label(l10n.folderMissing(fav.directory), systemImage: "folder.badge.questionmark")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }
                    commandSection(fav, status)
                    if !candidates.filter({ $0.command != fav.command }).isEmpty {
                        candidatesSection(fav)
                    }
                    runningSection(fav, status)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    RunDot(running: status.isRunning)
                    if editingName {
                        TextField("", text: $draftName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: 260)
                            .onSubmit {
                                workspaces.update(id: fav.id, name: draftName)
                                editingName = false
                            }
                    } else {
                        Text(fav.name).font(.system(size: 20, weight: .bold)).lineLimit(1)
                        IconButton(systemImage: "pencil", help: l10n.rename) {
                            draftName = fav.name
                            editingName = true
                        }
                    }
                }
                Text(fav.directory)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text(status.isRunning
                     ? l10n.runningSummary(ports: status.ports.count, memory: ByteFormat.short(status.memoryBytes))
                     : (fav.lastPorts.isEmpty ? l10n.notRunning
                        : l10n.notRunningLastPorts(fav.lastPorts.map { ":\($0)" }.joined(separator: " "))))
                    .font(.system(size: 11))
                    .foregroundStyle(status.isRunning ? Color.green : Color.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button { workspaces.revealInFinder(fav) } label: {
                    Label(l10n.revealInFinder, systemImage: "folder")
                }
                .controlSize(.small)
                if confirmRemove {
                    Button(l10n.removeFavorite) {
                        workspaces.unpin(id: fav.id)
                        onRemoved()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                    IconButton(systemImage: "xmark", help: l10n.cancel) { confirmRemove = false }
                } else {
                    Button { confirmRemove = true } label: {
                        Label(l10n.removeFavorite, systemImage: "star.slash")
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private func commandSection(_ fav: Favorite, _ status: FavoriteStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.startCommand).font(.system(size: 13, weight: .semibold))
                Text(l10n.commandSourceLabel(fav.commandSource))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            if editingCommand {
                HStack(spacing: 8) {
                    TextField(l10n.commandPlaceholder, text: $draftCommand)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit { commitCommand(fav) }
                    Button(l10n.save) { commitCommand(fav) }.controlSize(.small)
                    Button(l10n.cancel) { editingCommand = false }.controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Text(fav.command.isEmpty ? l10n.noCommandSet : fav.command)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(fav.command.isEmpty ? Color.orange : Color.primary)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                    IconButton(systemImage: "pencil", help: l10n.editCommand) {
                        draftCommand = fav.command
                        editingCommand = true
                    }
                    IconButton(systemImage: "doc.on.doc", help: l10n.copyCommand) { workspaces.copyCommand(fav) }
                        .disabled(fav.command.isEmpty)
                }
                HStack(spacing: 8) {
                    Button { workspaces.openInTerminal(fav) } label: {
                        Label(l10n.openInTerminal, systemImage: "terminal")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(fav.command.isEmpty)
                    if status.isRunning {
                        Text(l10n.alreadyRunningHint).font(.system(size: 10)).foregroundStyle(.secondary)
                    } else {
                        Text(l10n.openInTerminalHint).font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func candidatesSection(_ fav: Favorite) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.detectedCommands).font(.system(size: 12, weight: .semibold))
            ForEach(candidates.filter { $0.command != fav.command }, id: \.self) { c in
                HStack(spacing: 8) {
                    Text(c.command).font(.system(size: 11, design: .monospaced))
                    Text(c.origin).font(.system(size: 10)).foregroundStyle(.tertiary)
                    Spacer()
                    Button(l10n.useThis) { workspaces.useCandidate(id: fav.id, c) }.controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private func runningSection(_ fav: Favorite, _ status: FavoriteStatus) -> some View {
        if status.isRunning {
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.runningNow).font(.system(size: 13, weight: .semibold))
                ForEach(status.running) { p in
                    HStack(spacing: 10) {
                        Text(p.name).font(.system(size: 12, weight: .medium))
                        PortChips(ports: p.ports).fixedSize()
                        Text(p.listeners.first?.shortCommand ?? "")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                        Spacer()
                        Text(ByteFormat.short(p.memoryBytes))
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                        StopButton(project: p, compact: true)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                }
            }
        }
    }

    private func commitCommand(_ fav: Favorite) {
        workspaces.update(id: fav.id, command: draftCommand)
        editingCommand = false
    }
}
