import AppKit
import PharosCore
import UniformTypeIdentifiers

/// Export / import of favorites and browser presets via save / open panels.
/// Only touches the file the user picks.
@MainActor
enum BackupActions {
    /// Result message for the settings banner.
    static func export() -> String? {
        let l10n = L10n.shared
        let favorites = WorkspaceStore.shared.favorites
        let presets = ChromeStore.shared.presets
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let day = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        panel.nameFieldStringValue = "Pharos-backup-\(day).json"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try Backup(favorites: favorites, browserPresets: presets,
                       popoverLayout: PopoverLayoutStore.shared.layout).encoded().write(to: url, options: .atomic)
            return l10n.exported(favorites.count, presets.count)
        } catch {
            return l10n.backupFailed(error.localizedDescription)
        }
    }

    static func importFile() -> String? {
        let l10n = L10n.shared
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            let backup = try Backup.decode(Data(contentsOf: url))
            let m = backup.merge(into: WorkspaceStore.shared.favorites, presets: ChromeStore.shared.presets)
            WorkspaceStore.shared.add(m.favorites)
            ChromeStore.shared.add(m.presets)
            if let layout = backup.popoverLayout { PopoverLayoutStore.shared.update { $0 = layout } }
            return l10n.imported(m.favorites.count, m.presets.count, m.skipped)
        } catch let e as Backup.ReadError {
            switch e {
            case .notABackup: return l10n.backupInvalid
            case .newerVersion: return l10n.backupFailed(l10n.backupInvalid)
            }
        } catch {
            return l10n.backupFailed(error.localizedDescription)
        }
    }
}
