import Foundation

/// Decides when to raise a local notification. Pure logic over successive
/// scans so it can be unit-tested; the app layer only delivers the result.
/// Each condition fires once when it starts, then re-arms only after it clears,
/// so a machine that stays under pressure isn't notified every poll.
public struct AlertState: Sendable {
    public enum Alert: Equatable, Sendable {
        case memoryPressure(used: UInt64, total: UInt64)
        case diskAlmostFull(name: String, path: String, available: UInt64)
        case favoriteStopped(id: String, name: String, ports: [UInt16])
    }

    public static let diskFullFraction = 0.95
    /// Re-arm a little below the trigger so a disk hovering at 95 % doesn't flap.
    public static let diskClearFraction = 0.93

    private var memoryHigh = false
    private var fullDisks: Set<String> = []
    private var runningFavorites: Set<String>?

    public init() {}

    public mutating func update(memory: SystemMemoryStats?, volumes: [DiskVolume],
                                favorites: [(id: String, name: String, ports: [UInt16])],
                                runningFavoriteIDs: Set<String>,
                                stoppedByUser: Set<String>) -> [Alert] {
        var out: [Alert] = []

        if let m = memory {
            let high = m.pressure != .normal
            if high && !memoryHigh { out.append(.memoryPressure(used: m.used, total: m.total)) }
            memoryHigh = high
        }

        // Read-only disk images report themselves as full; that's not actionable.
        for v in volumes where v.kind != .diskImage && !v.isReadOnly {
            if v.usedFraction >= Self.diskFullFraction {
                if !fullDisks.contains(v.path) {
                    fullDisks.insert(v.path)
                    out.append(.diskAlmostFull(name: v.name, path: v.path, available: v.available))
                }
            } else if v.usedFraction < Self.diskClearFraction {
                fullDisks.remove(v.path)
            }
        }
        fullDisks.formIntersection(volumes.map(\.path))

        // First scan only records the baseline: favorites already stopped at
        // launch didn't "stop unexpectedly".
        if let before = runningFavorites {
            for f in favorites where before.contains(f.id) && !runningFavoriteIDs.contains(f.id)
                && !stoppedByUser.contains(f.id) {
                out.append(.favoriteStopped(id: f.id, name: f.name, ports: f.ports))
            }
        }
        runningFavorites = runningFavoriteIDs
        return out
    }
}
