import Foundation

/// Paths and the launchd plist for the optional `pharos-battd` root helper.
/// Pure (no side effects) so the install script it produces can be tested.
public enum BatteryHelperInstall {
    public static let label = "local.pharos.battd"
    public static let binaryPath = "/Library/PrivilegedHelperTools/local.pharos.battd"
    public static let plistPath = "/Library/LaunchDaemons/local.pharos.battd.plist"
    public static let logPath = "/var/log/pharos-battd.log"

    public static func plist(uid: uid_t) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
                <string>\(uid)</string>
            </array>
            <key>RunAtLoad</key><true/>
            <key>KeepAlive</key><true/>
            <key>StandardOutPath</key><string>\(logPath)</string>
            <key>StandardErrorPath</key><string>\(logPath)</string>
        </dict>
        </plist>

        """
    }

    /// Shell script run once with administrator privileges. Every path is fixed
    /// or quoted; the helper binary is copied (not linked) so the app can be moved.
    public static func installScript(helperSource: String, plistSource: String) -> String {
        let src = ShellQuote.quote(helperSource)
        let plist = ShellQuote.quote(plistSource)
        return [
            "set -e",
            "/bin/launchctl bootout system/\(label) 2>/dev/null || true",
            "/bin/mkdir -p /Library/PrivilegedHelperTools",
            "/usr/bin/install -o root -g wheel -m 0755 \(src) \(binaryPath)",
            "/usr/bin/install -o root -g wheel -m 0644 \(plist) \(plistPath)",
            "/usr/bin/xattr -c \(binaryPath) 2>/dev/null || true",
            "/bin/launchctl bootstrap system \(plistPath)",
        ].joined(separator: "\n")
    }

    public static let statePath = "/Library/PrivilegedHelperTools/local.pharos.battd.state"

    /// launchd sends SIGTERM on bootout; the helper hands charging control back before exiting.
    public static let uninstallScript = [
        "/bin/launchctl bootout system/\(label) 2>/dev/null || true",
        "/bin/rm -f \(plistPath) \(binaryPath) \(BatteryProtocol.socketPath) \(statePath)",
    ].joined(separator: "\n")
}
