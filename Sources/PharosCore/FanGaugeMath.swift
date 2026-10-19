import Foundation

/// Pure mathematical scaling and geometry calculations for automotive-style
/// fan tachometer and speedometer gauges. Completely testable with no UI dependencies.
public struct FanGaugeScale: Sendable, Hashable, Equatable {
    public let minRPM: Int
    public let maxRPM: Int
    public let maxScale: Int
    public let redlineRPM: Int
    public let startAngle: Double
    public let sweepAngle: Double

    public init(
        minRPM: Int,
        maxRPM: Int,
        startAngle: Double = 135.0,
        sweepAngle: Double = 270.0
    ) {
        let safeMin = max(0, minRPM)
        let safeMax = max(safeMin + 100, maxRPM)
        self.minRPM = safeMin
        self.maxRPM = safeMax
        self.startAngle = startAngle
        self.sweepAngle = sweepAngle

        // Round maxScale up to the nearest 1000 RPM (minimum 6000)
        let roundedK = Int(ceil(Double(safeMax) / 1000.0)) * 1000
        self.maxScale = max(6000, roundedK)

        // Redline zone begins at 85% of maxRPM or at least maxRPM - 1200
        let redlineRaw = max(Int(Double(safeMax) * 0.85 / 100.0) * 100, safeMax - 1200)
        self.redlineRPM = min(safeMax, max(safeMin + 500, redlineRaw))
    }

    /// Normalized fraction between 0.0 and 1.0 against the dial's max scale.
    public func fraction(for rpm: Int) -> Double {
        guard maxScale > 0 else { return 0 }
        let clamped = max(0, min(maxScale, rpm))
        return Double(clamped) / Double(maxScale)
    }

    /// Exact rotation angle in degrees for the gauge needle or ribbon tip.
    public func angle(for rpm: Int) -> Double {
        let f = fraction(for: rpm)
        return startAngle + (f * sweepAngle)
    }

    /// Whether a given RPM falls into the high-rpm redline danger zone.
    public func isRedline(rpm: Int) -> Bool {
        rpm >= redlineRPM
    }

    /// Normalized starting fraction of the redline zone on the dial.
    public var redlineStartFraction: Double {
        fraction(for: redlineRPM)
    }

    /// Starting angle of the redline zone.
    public var redlineStartAngle: Double {
        angle(for: redlineRPM)
    }

    /// Values for major graduation marks (every 1000 RPM, e.g. [0, 1000, 2000, ...]).
    public var majorTicks: [Int] {
        stride(from: 0, through: maxScale, by: 1000).map { $0 }
    }

    /// Values for intermediate graduation marks (every 500 RPM, excluding major marks).
    public var mediumTicks: [Int] {
        stride(from: 500, through: maxScale - 500, by: 1000).map { $0 }
    }

    /// Total count of 100-RPM minor micro-graduations on the dial.
    public var minorTicksCount: Int {
        maxScale / 100
    }

    /// Exact RPM value for a minor micro-graduation index.
    public func minorTickRPM(at index: Int) -> Int {
        index * 100
    }
}
