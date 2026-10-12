import Foundation

public enum ByteFormat {
    /// Compact binary units, e.g. "512K", "84M", "1.2G".
    public static func short(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.0fK", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.0fM", mb) }
        let gb = mb / 1024
        return gb < 10 ? String(format: "%.1fG", gb) : String(format: "%.0fG", gb)
    }

    /// Disk capacities in decimal units like Finder and the drive's label
    /// ("4 TB", not "3725G"), e.g. "388 GB", "1.5 TB".
    public static func disk(_ bytes: UInt64) -> String {
        let units = ["KB", "MB", "GB", "TB", "PB"]
        var v = Double(bytes) / 1000
        var i = 0
        while v >= 1000, i < units.count - 1 { v /= 1000; i += 1 }
        return (v < 10 ? String(format: "%.1f", v) : String(format: "%.0f", v)) + " " + units[i]
    }
}
