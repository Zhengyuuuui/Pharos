import Foundation

public enum LogRotation {
    public static let defaultMaxBytes: Int = 512 * 1024
    public static let defaultKeepBytes: Int = 256 * 1024

    /// Truncates the log file at `path` if its size exceeds `maxBytes`, retaining only the trailing `keepBytes`.
    /// Returns true if rotation/truncation occurred, false otherwise.
    @discardableResult
    public static func rotateLogIfNeeded(
        path: String,
        maxBytes: Int = defaultMaxBytes,
        keepBytes: Int = defaultKeepBytes
    ) -> Bool {
        guard maxBytes > 0, keepBytes > 0, maxBytes >= keepBytes else { return false }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64,
              size > UInt64(maxBytes) else {
            return false
        }

        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        let offset = size - UInt64(keepBytes)
        do {
            try handle.seek(toOffset: offset)
            let rawData = handle.readDataToEndOfFile()
            try handle.close()

            // Find the first newline so we don't start with a severed/truncated line
            var dataToKeep = rawData
            if let firstNL = dataToKeep.firstIndex(of: 0x0A), firstNL < dataToKeep.startIndex + 2048 {
                dataToKeep = dataToKeep.suffix(from: dataToKeep.index(after: firstNL))
            }

            if let writeHandle = FileHandle(forWritingAtPath: path) {
                try writeHandle.truncate(atOffset: 0)
                try writeHandle.write(contentsOf: dataToKeep)
                try writeHandle.close()
                return true
            } else {
                try dataToKeep.write(to: URL(fileURLWithPath: path), options: .atomic)
                return true
            }
        } catch {
            return false
        }
    }
}

@discardableResult
public func rotateLogIfNeeded(
    path: String,
    maxBytes: Int = LogRotation.defaultMaxBytes,
    keepBytes: Int = LogRotation.defaultKeepBytes
) -> Bool {
    LogRotation.rotateLogIfNeeded(path: path, maxBytes: maxBytes, keepBytes: keepBytes)
}
