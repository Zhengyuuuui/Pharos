import AppKit
import SwiftUI
import PharosCore

// MARK: - Animated Spinning Fan Blade
private struct SpinningFanBlade: View {
    let rpm: Int
    @State private var isSpinning = false

    var body: some View {
        Image(systemName: "fanblades")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(rpm > 0 ? Color.accentColor : Color.secondary)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(
                rpm > 0
                    ? Animation.linear(duration: spinDuration).repeatForever(autoreverses: false)
                    : .default,
                value: isSpinning
            )
            .onAppear {
                if rpm > 0 { isSpinning = true }
            }
            .onChange(of: rpm) { _, newRPM in
                if newRPM > 0 && !isSpinning {
                    isSpinning = true
                } else if newRPM == 0 && isSpinning {
                    isSpinning = false
                }
            }
    }

    private var spinDuration: Double {
        guard rpm > 0 else { return 2.0 }
        // Scale speed between 1.8s (slow/idle) to 0.25s (max boost)
        let clamped = max(800, min(7000, rpm))
        let factor = 1.0 - (Double(clamped - 800) / 6200.0)
        return max(0.25, 0.25 + factor * 1.55)
    }
}

// MARK: - Automotive Speedometer Needle
private struct FanSpeedometerNeedle: View {
    let angle: Double
    let radius: CGFloat
    let isRedline: Bool

    var body: some View {
        let needleLength = radius * 0.72
        let needleTail = radius * 0.16

        ZStack {
            // Shadow behind the needle
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 3.5, height: needleLength)
                Rectangle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 4, height: needleTail)
            }
            .offset(x: 1.5, y: -needleLength / 2 + needleTail / 2 + 1.5)
            .rotationEffect(.degrees(angle), anchor: .center)

            // Dynamic Racing Needle
            VStack(spacing: 0) {
                // Illuminated needle body
                ZStack(alignment: .top) {
                    // Needle body with tapered gradient
                    Path { path in
                        let w: CGFloat = 3.2
                        let tipW: CGFloat = 1.2
                        path.move(to: CGPoint(x: -w / 2, y: needleLength))
                        path.addLine(to: CGPoint(x: -tipW / 2, y: 0))
                        path.addLine(to: CGPoint(x: tipW / 2, y: 0))
                        path.addLine(to: CGPoint(x: w / 2, y: needleLength))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: isRedline
                                ? [Color(red: 1.0, green: 0.1, blue: 0.1), Color(red: 1.0, green: 0.45, blue: 0.1)]
                                : [Color.orange, Color(red: 1.0, green: 0.25, blue: 0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: needleLength)

                    // Sharp center reflective highlight
                    Rectangle()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: 0.8, height: needleLength - 4)
                        .padding(.top, 2)
                }

                // Counterweight tail behind pivot
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.primary.opacity(0.7), Color.primary.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3.5, height: needleTail)
            }
            .offset(y: -needleLength / 2 + needleTail / 2)
            .rotationEffect(.degrees(angle), anchor: .center)
            .animation(.spring(response: 0.52, dampingFraction: 0.74), value: angle)

            // Machined Center Pivot Hub Cap
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.black.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1.5)

            // Inner Rivet
            Circle()
                .fill(isRedline ? Color.red : Color.orange)
                .frame(width: 7, height: 7)
                .shadow(color: (isRedline ? Color.red : Color.orange).opacity(0.6), radius: 3)
        }
    }
}

// MARK: - High-Precision Speedometer Dial View
public struct FanSpeedometerDialView: View {
    @ObservedObject private var l10n = L10n.shared
    public let fan: FanReading
    public let count: Int
    public let targetRPM: Int?

    public init(fan: FanReading, count: Int, targetRPM: Int? = nil) {
        self.fan = fan
        self.count = count
        self.targetRPM = targetRPM
    }

    private var scale: FanGaugeScale {
        FanGaugeScale(minRPM: fan.minRPM, maxRPM: fan.maxRPM)
    }

    private var isRedline: Bool {
        scale.isRedline(rpm: fan.actualRPM)
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Top Fan Identity Header
            HStack(alignment: .center) {
                Label(l10n.fanName(fan.index, of: count), systemImage: "fanblades.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Mode Badge Pill
                Text(l10n.fanMode(fan.mode))
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(
                            fan.mode == .manual
                                ? Color.orange.opacity(0.18)
                                : (fan.mode == .system ? Color.blue.opacity(0.14) : Color.primary.opacity(0.08))
                        )
                    )
                    .foregroundStyle(
                        fan.mode == .manual
                            ? Color.orange
                            : (fan.mode == .system ? Color.blue : Color.secondary)
                    )
            }
            .padding(.horizontal, 4)

            // Cockpit Gauge Pod Dial
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let radius = side / 2

                ZStack {
                    // 1. Dial Face & Radial Shadow Backing
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.primary.opacity(0.04),
                                    Color.primary.opacity(0.10)
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: radius
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.primary.opacity(0.15),
                                            Color.primary.opacity(0.04),
                                            Color.primary.opacity(0.20)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)

                    // 2. Background Track Arc (270° Sweep from 135° to 405°)
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            Color.primary.opacity(0.08),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(scale.startAngle))
                        .frame(width: radius * 1.62, height: radius * 1.62)

                    // 3. Redline Danger Arc Segment (> 85% RPM)
                    let redlineStartFrac = scale.redlineStartFraction * 0.75
                    Circle()
                        .trim(from: redlineStartFrac, to: 0.75)
                        .stroke(
                            Color.red.opacity(0.28),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(scale.startAngle))
                        .frame(width: radius * 1.62, height: radius * 1.62)

                    // 4. Dynamic Speed Ribbon (Colored Progressive Active Sweep Arc)
                    let currentProgress = scale.fraction(for: fan.actualRPM) * 0.75
                    if currentProgress > 0 {
                        Circle()
                            .trim(from: 0, to: currentProgress)
                            .stroke(
                                LinearGradient(
                                    colors: speedGradientColors(actualRPM: fan.actualRPM),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(scale.startAngle))
                            .frame(width: radius * 1.62, height: radius * 1.62)
                            .shadow(
                                color: (isRedline ? Color.red : Color.cyan).opacity(0.35),
                                radius: 5,
                                x: 0,
                                y: 0
                            )
                            .animation(.spring(response: 0.52, dampingFraction: 0.74), value: fan.actualRPM)
                    }

                    // 5. High-Precision Graduation Tick Marks & Numerals
                    dialGraduations(radius: radius * 0.81)

                    // 6. Target RPM Notch Marker (when in Manual Mode)
                    if let target = targetRPM, target > 0, fan.mode == .manual {
                        targetMarker(targetRPM: target, radius: radius * 0.81)
                    }

                    // 7. High-Precision Racing Needle
                    FanSpeedometerNeedle(
                        angle: scale.angle(for: fan.actualRPM),
                        radius: radius * 0.81,
                        isRedline: isRedline
                    )

                    // 8. Digital HUD Cluster (Center Display)
                    VStack(spacing: 2) {
                        Text(fan.actualRPM > 0 ? "\(fan.actualRPM)" : "0")
                            .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(isRedline ? Color.red : Color.primary)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.15), value: fan.actualRPM)

                        HStack(spacing: 4) {
                            SpinningFanBlade(rpm: fan.actualRPM)
                            Text("RPM")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.secondary)
                        }

                        // Duty Cycle & Health Tag
                        Text(fan.actualRPM == 0 ? l10n.fanStopped : "\(Int(fan.fraction * 100))%")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule().fill(statusColor.opacity(0.14))
                            )
                            .foregroundStyle(statusColor)
                            .padding(.top, 4)
                    }
                    .offset(y: radius * 0.28)
                }
                .frame(width: side, height: side)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .frame(height: 220)

            // Bottom Sub-Telemetry Bar
            VStack(spacing: 4) {
                HStack {
                    Text(l10n.fanRange(fan.minRPM, fan.maxRPM))
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let target = targetRPM, target > 0, fan.mode == .manual {
                        Text("\(l10n.fanTargetSpeed): \(target) rpm")
                            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(l10n.fanDutyCycle): \(String(format: "%.1f%%", fan.fraction * 100))")
                            .font(.system(size: 10.5).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                // Mini horizontal linear progress bar
                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: speedGradientColors(actualRPM: fan.actualRPM), startPoint: .leading, endPoint: .trailing))
                            .frame(width: barGeo.size.width * CGFloat(fan.fraction))
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isRedline
                        ? Color.red.opacity(0.35)
                        : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Tick Marks & Upright Numerals
    @ViewBuilder
    private func dialGraduations(radius: CGFloat) -> some View {
        ZStack {
            // A. Minor micro-ticks every 100 RPM (up to 70-80 ticks)
            ForEach(0...scale.minorTicksCount, id: \.self) { idx in
                let rpmVal = scale.minorTickRPM(at: idx)
                let isMinorRed = scale.isRedline(rpm: rpmVal)
                let angle = scale.angle(for: rpmVal)

                Rectangle()
                    .fill(isMinorRed ? Color.red.opacity(0.55) : Color.primary.opacity(0.20))
                    .frame(width: 1.0, height: 4.5)
                    .offset(y: -radius + 3)
                    .rotationEffect(.degrees(angle))
            }

            // B. Medium ticks at 500 RPM intervals
            ForEach(scale.mediumTicks, id: \.self) { rpmVal in
                let isMedRed = scale.isRedline(rpm: rpmVal)
                let angle = scale.angle(for: rpmVal)

                Rectangle()
                    .fill(isMedRed ? Color.red.opacity(0.85) : Color.primary.opacity(0.45))
                    .frame(width: 1.6, height: 7.5)
                    .offset(y: -radius + 4)
                    .rotationEffect(.degrees(angle))
            }

            // C. Major ticks every 1000 RPM + Numbers
            ForEach(scale.majorTicks, id: \.self) { rpmVal in
                let isMajRed = scale.isRedline(rpm: rpmVal)
                let angle = scale.angle(for: rpmVal)
                let thousands = rpmVal / 1000

                // Major Tick Line
                Rectangle()
                    .fill(isMajRed ? Color.red : Color.primary.opacity(0.88))
                    .frame(width: 2.5, height: 11)
                    .offset(y: -radius + 6)
                    .rotationEffect(.degrees(angle))

                // Upright Chrono Number (e.g. 0, 1, 2, ... 7)
                Text("\(thousands)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isMajRed ? Color.red : Color.primary.opacity(0.85))
                    .offset(y: -radius + 22)
                    .rotationEffect(.degrees(angle))
                    // Counter-rotate so text stays upright and readable
                    .rotationEffect(.degrees(-angle))
            }
        }
    }

    // MARK: - Target RPM Marker
    @ViewBuilder
    private func targetMarker(targetRPM: Int, radius: CGFloat) -> some View {
        let angle = scale.angle(for: targetRPM)
        Image(systemName: "arrowtriangle.down.fill")
            .font(.system(size: 8))
            .foregroundStyle(Color.orange)
            .shadow(color: Color.orange.opacity(0.8), radius: 3)
            .offset(y: -radius - 7)
            .rotationEffect(.degrees(angle))
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: targetRPM)
    }

    // MARK: - Color Calculations
    private func speedGradientColors(actualRPM: Int) -> [Color] {
        if isRedline {
            return [Color(red: 1.0, green: 0.4, blue: 0.1), Color.red, Color(red: 0.9, green: 0.0, blue: 0.2)]
        } else if fan.fraction >= 0.65 {
            return [Color.cyan, Color.yellow, Color.orange]
        } else {
            return [Color(red: 0.1, green: 0.85, blue: 0.95), Color.blue, Color(red: 0.3, green: 0.5, blue: 1.0)]
        }
    }

    private var statusColor: Color {
        if fan.actualRPM == 0 { return .secondary }
        if isRedline { return .red }
        if fan.fraction >= 0.70 { return .orange }
        return .green
    }
}

// MARK: - Automotive Dual/Single Fan Cockpit Cluster View
public struct FanSpeedometerClusterView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var fanStore = FanStore.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("pharos.fanViewMode") private var viewMode: String = "gauge"

    public init() {}

    public var body: some View {
        let fans = store.thermals?.fans ?? []
        VStack(alignment: .leading, spacing: 14) {
            // Cluster Header Toolbar
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.needle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                    Text(l10n.fansTitle)
                        .font(.system(size: 14, weight: .bold))
                }

                Spacer()

                // View Mode Switcher: Gauge (Speedometer) vs Classic Bars
                Picker("", selection: $viewMode) {
                    Label(l10n.fanViewModeGauge, systemImage: "gauge.with.needle")
                        .tag("gauge")
                    Label(l10n.fanViewModeBars, systemImage: "chart.bar.fill")
                        .tag("bar")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if fans.isEmpty {
                // Fanless Mac Notification (MacBook Air / passive cooling)
                HStack(spacing: 12) {
                    Image(systemName: "wind.snow")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.fanNoFansInstalled)
                            .font(.system(size: 12, weight: .medium))
                        Text(l10n.fanStopped)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
            } else if viewMode == "gauge" {
                // Automotive Speedometer Gauge Cockpit
                if fans.count == 2 {
                    // Twin Cockpit Gauge Cluster (Symmetrical Dual Dials)
                    HStack(spacing: 16) {
                        FanSpeedometerDialView(
                            fan: fans[0],
                            count: 2,
                            targetRPM: targetRPM(for: fans[0])
                        )
                        .frame(maxWidth: .infinity)

                        // Central Cockpit Telemetry Bridge
                        cockpitTelemetryBridge(fan0: fans[0], fan1: fans[1])
                            .frame(width: 140)

                        FanSpeedometerDialView(
                            fan: fans[1],
                            count: 2,
                            targetRPM: targetRPM(for: fans[1])
                        )
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // Single Cockpit Speedometer Pod
                    HStack(spacing: 14) {
                        ForEach(fans) { f in
                            FanSpeedometerDialView(
                                fan: f,
                                count: fans.count,
                                targetRPM: targetRPM(for: f)
                            )
                        }
                    }
                }
            } else {
                // Classic Bar Cards (100% Preserved)
                HStack(spacing: 12) {
                    ForEach(fans) { f in
                        ClassicFanBarCard(fan: f, count: fans.count)
                    }
                }
            }
        }
    }

    private func targetRPM(for fan: FanReading) -> Int? {
        if case .fixed(let rpm) = fanStore.request {
            return rpm
        }
        return fan.targetRPM > 0 ? fan.targetRPM : nil
    }

    // MARK: - Central Cockpit Telemetry Bridge
    @ViewBuilder
    private func cockpitTelemetryBridge(fan0: FanReading, fan1: FanReading) -> some View {
        let delta = abs(fan0.actualRPM - fan1.actualRPM)
        let peakTemp = store.thermals?.peakChipTemperature

        VStack(spacing: 12) {
            // Speed Difference Readout
            VStack(spacing: 3) {
                Text(l10n.fanSpeedDifferential)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("Δ \(delta)")
                        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(delta > 300 ? Color.orange : Color.primary)
                    Text("rpm")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Text(delta <= 100 ? l10n.fanBalanced : (fan0.actualRPM > fan1.actualRPM ? "◀ L" : "R ▶"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(delta <= 100 ? Color.green : Color.orange)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

            // Live Peak Temperature Core
            if let temp = peakTemp {
                VStack(spacing: 3) {
                    Text("PEAK CORE")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f°C", temp))
                        .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(ThermalStyle.color(temp))
                    Label(l10n.thermalStateName(store.thermalState), systemImage: "thermometer.medium")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(ThermalStyle.stateColor(store.thermalState))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
            }
        }
    }
}

// MARK: - Classic Fan Bar Card (Preserved)
public struct ClassicFanBarCard: View {
    @ObservedObject private var l10n = L10n.shared
    public let fan: FanReading
    public let count: Int

    public init(fan: FanReading, count: Int) {
        self.fan = fan
        self.count = count
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(l10n.fanName(fan.index, of: count), systemImage: "fanblades")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(l10n.fanMode(fan.mode))
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(fan.mode == .manual ? Color.orange.opacity(0.15) : Color.primary.opacity(0.07)))
                    .foregroundStyle(fan.mode == .manual ? .orange : .secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(fan.actualRPM > 0 ? "\(fan.actualRPM)" : "0")
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                Text("rpm").font(.system(size: 11)).foregroundStyle(.secondary)
                if fan.actualRPM == 0 {
                    Text(l10n.fanStopped).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.primary.opacity(0.08))
                    Rectangle().fill(Color.blue).frame(width: geo.size.width * CGFloat(fan.fraction))
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            Text(l10n.fanRange(fan.minRPM, fan.maxRPM)).font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}
