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
}
