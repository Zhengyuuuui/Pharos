import Foundation

public struct ProjectSample: Hashable, Sendable {
    public let id: String
    public let name: String
    public let bytes: UInt64

    public init(id: String, name: String, bytes: UInt64) {
        self.id = id
        self.name = name
        self.bytes = bytes
    }
}

public struct MemorySample: Hashable, Sendable, Identifiable {
    public let date: Date
    public let systemUsed: UInt64
    public let projects: [ProjectSample]

    public var id: Date { date }
    public var devTotal: UInt64 { projects.reduce(0) { $0 + $1.bytes } }

    public init(date: Date, systemUsed: UInt64, projects: [ProjectSample]) {
        self.date = date
        self.systemUsed = systemUsed
        self.projects = projects
    }
}

/// Rolling time window of samples. Bursts (fast refresh while a window is open)
/// collapse into one point per `minInterval` so chart density stays bounded.
public struct MemoryHistory: Sendable {
    public private(set) var samples: [MemorySample] = []
    public let window: TimeInterval
    public let minInterval: TimeInterval

    public init(window: TimeInterval = 3600, minInterval: TimeInterval = 10) {
        self.window = window
        self.minInterval = minInterval
    }

    public mutating func append(_ sample: MemorySample) {
        if let last = samples.last, sample.date.timeIntervalSince(last.date) < minInterval {
            samples[samples.count - 1] = MemorySample(date: last.date,
                                                      systemUsed: sample.systemUsed,
                                                      projects: sample.projects)
        } else {
            samples.append(sample)
        }
        let cutoff = sample.date.addingTimeInterval(-window)
        if let firstKept = samples.firstIndex(where: { $0.date >= cutoff }), firstKept > 0 {
            samples.removeFirst(firstKept)
        }
    }

    public struct Point: Hashable, Sendable {
        public let date: Date
        public let series: String
        public let bytes: UInt64
    }

    /// Dense per-project series for stacked charts: the `limit` heaviest projects
    /// (by latest sample) get their own series, everything else folds into `otherName`.
    /// Every sample yields a value for every series (0 when absent) so stacking stays aligned.
    public func projectSeries(limit: Int, otherName: String) -> (names: [String], points: [Point]) {
        guard let latest = samples.last else { return ([], []) }
        let top = latest.projects.sorted { $0.bytes > $1.bytes }.prefix(limit)
        let topIDs = top.map(\.id)
        let names = top.map(\.name)
        let hasOther = samples.contains { s in s.projects.contains { !topIDs.contains($0.id) } }

        var points: [Point] = []
        for s in samples {
            var byID: [String: UInt64] = [:]
            var other: UInt64 = 0
            for p in s.projects {
                if topIDs.contains(p.id) { byID[p.id, default: 0] += p.bytes } else { other += p.bytes }
            }
            for (id, name) in zip(topIDs, names) {
                points.append(Point(date: s.date, series: name, bytes: byID[id] ?? 0))
            }
            if hasOther {
                points.append(Point(date: s.date, series: otherName, bytes: other))
            }
        }
        return (hasOther ? names + [otherName] : names, points)
    }
}
