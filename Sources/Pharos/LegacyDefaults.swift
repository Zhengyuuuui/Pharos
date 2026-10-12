import Foundation

/// The app used to ship as UsageBar (bundle id `local.usagebar`). Changing the
/// bundle id gives it a fresh defaults domain, so copy the old settings over once.
enum LegacyDefaults {
    private static let legacyDomain = "local.usagebar"
    private static let doneKey = "migratedFromUsageBar"
    /// Only keys this app writes; the old domain also holds leftovers from the
    /// original project (provider configs, reminders) that must not come along.
    private static let keys: Set<String> = [
        "appLanguage", "refreshSeconds", "showSystemProcesses", "popoverTab",
        "tempRetentionHours", "favoriteWorkspaces.v1", "chromePresets.v1",
    ]
    private static let prefixes = ["cleanupGroupExpanded."]

    static func migrate() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        if let old = defaults.persistentDomain(forName: legacyDomain) {
            for (key, value) in old where defaults.object(forKey: key) == nil
                && (keys.contains(key) || prefixes.contains(where: key.hasPrefix)) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: doneKey)
    }
}
