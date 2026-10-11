import AppKit
import UsageBarCore

/// Saved workspaces ("favorites"): add a folder or pin a running project, keep
/// its start command, open it in Terminal. Persisted as JSON in UserDefaults.
@MainActor
final class WorkspaceStore: ObservableObject {
    static let shared = WorkspaceStore()

    @Published private(set) var favorites: [Favorite] = []
    /// Last failure (save, launch). Shown as a banner; never silent.
    @Published var errorMessage: String?

    private static let key = "favoriteWorkspaces.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key) {
            do {
                favorites = try JSONDecoder().decode([Favorite].self, from: data)
            } catch {
                errorMessage = L10n.shared.favoritesLoadFailed
            }
        }
    }

    func favorite(id: String) -> Favorite? { favorites.first { $0.id == id } }

    func favorite(forDirectory dir: String?) -> Favorite? {
        dir.flatMap { WorkspaceMatcher.favorite(for: $0, in: favorites) }
    }

    func isPinned(_ project: Project) -> Bool { favorite(forDirectory: project.directory) != nil }

    /// Running projects grouped under the favorite that contains them.
    func running(in projects: [Project]) -> [String: [Project]] {
        WorkspaceMatcher.match(favorites, projects)
    }

    // MARK: - Adding

    /// Folder picker → favorite with the best detected command. Returns its id.
    @discardableResult
    func addFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = L10n.shared.addWorkspace
        panel.message = L10n.shared.addWorkspaceMessage
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return nil }
        var lastId: String?
        for url in panel.urls {
            let dir = WorkspaceMatcher.normalize(url.path)
            if let existing = favorite(forDirectory: dir) { lastId = existing.id; continue }
            let candidate = LaunchDetector.candidates(in: dir).first
            let fav = Favorite(name: url.lastPathComponent, directory: dir,
                               command: candidate?.command ?? "",
                               commandSource: candidate == nil ? .custom : .detected)
            favorites.append(fav)
            lastId = fav.id
        }
        save()
        return lastId
    }

    /// Pin a running project with the command it's actually running with.
    func pin(_ project: Project) {
        guard let dir = project.directory, !isPinned(project) else { return }
        let running = project.listeners.first.flatMap {
            LaunchDetector.command(forRunning: $0.arguments, in: dir)
        }
        let detected = LaunchDetector.candidates(in: dir).first?.command
        let command = running ?? detected ?? ""
        favorites.append(Favorite(
            name: project.name, directory: dir, command: command,
            commandSource: running != nil ? .running : (detected != nil ? .detected : .custom),
            lastPorts: project.ports.map(\.port)
        ))
        save()
    }

    // MARK: - Editing

    func unpin(id: String) {
        favorites.removeAll { $0.id == id }
        save()
    }

    func update(id: String, name: String? = nil, command: String? = nil) {
        guard let i = favorites.firstIndex(where: { $0.id == id }) else { return }
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { favorites[i].name = name }
        if let command {
            let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != favorites[i].command {
                favorites[i].command = trimmed
                favorites[i].commandSource = .custom
            }
        }
        save()
    }

    func useCandidate(id: String, _ candidate: LaunchCandidate) {
        guard let i = favorites.firstIndex(where: { $0.id == id }) else { return }
        favorites[i].command = candidate.command
        favorites[i].commandSource = .detected
        save()
    }

    /// Keep "last seen ports" current while a favorite is running.
    func recordPorts(_ matches: [String: [Project]]) {
        var changed = false
        for (id, projects) in matches {
            guard let i = favorites.firstIndex(where: { $0.id == id }) else { continue }
            let ports = Array(Set(projects.flatMap { $0.ports.map(\.port) })).sorted()
            if !ports.isEmpty, ports != favorites[i].lastPorts {
                favorites[i].lastPorts = ports
                changed = true
            }
        }
        if changed { save() }
    }

    // MARK: - Actions

    /// Writes a small `.command` script and opens it with the user's default
    /// handler (Terminal.app unless changed). The process then belongs to that
    /// terminal window: output is visible and Ctrl-C stops it.
    func openInTerminal(_ fav: Favorite) {
        let l10n = L10n.shared
        guard !fav.command.isEmpty else { errorMessage = l10n.noCommandSet; return }
        guard FileManager.default.fileExists(atPath: fav.directory) else {
            errorMessage = l10n.folderMissing(fav.directory)
            return
        }
        let url = Self.scriptDirectory.appendingPathComponent("\(fav.id).command")
        do {
            try LaunchScript.write(
                LaunchScript.contents(directory: fav.directory, command: fav.command, title: fav.name),
                to: url)
        } catch {
            errorMessage = l10n.launchFailed(error.localizedDescription)
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: Self.terminalURL,
                                configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor in self?.errorMessage = L10n.shared.launchFailed(error.localizedDescription) }
        }
    }

    func revealInFinder(_ fav: Favorite) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: fav.directory)
    }

    func copyCommand(_ fav: Favorite) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("cd \(ShellQuote.quote(fav.directory)) && \(fav.command)", forType: .string)
    }

    // MARK: - Private

    private static var scriptDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UsageBar/launch", isDirectory: true)
    }

    private static var terminalURL: URL {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
            ?? URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
    }

    private func save() {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(favorites), forKey: Self.key)
        } catch {
            errorMessage = L10n.shared.favoritesSaveFailed
        }
    }
}
