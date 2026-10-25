import Darwin
import Foundation

/// Helpers for probing macOS Full Disk Access (FDA) and privacy permissions
/// silently without triggering intrusive system permission dialogs.
public enum DiskPermissions {

    /// Detects whether the current process has been granted Full Disk Access (FDA).
    ///
    /// Industry-standard zero-prompt probe:
    /// In macOS TCC, `~/Library/Safari` is protected by the `SystemPolicyAllFiles` (FDA) policy.
    /// Attempting to list contents of `~/Library/Safari` does NOT trigger a user-facing TCC prompt.
    /// It silently succeeds when FDA is granted, and fails with `EPERM` when FDA is not granted.
    public static var hasFullDiskAccess: Bool {
        let testPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Safari")
        guard FileManager.default.fileExists(atPath: testPath) else {
            // Fallback probe: ~/.Trash
            let trashPath = (NSHomeDirectory() as NSString).appendingPathComponent(".Trash")
            guard FileManager.default.fileExists(atPath: trashPath) else { return true }
            return access(trashPath, R_OK | X_OK) == 0
        }
        return (try? FileManager.default.contentsOfDirectory(atPath: testPath)) != nil
    }

    /// Checks whether a given path is readable without raising unhandled permission faults.
    public static func isPathReadable(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        return access(path, R_OK) == 0
    }
}
