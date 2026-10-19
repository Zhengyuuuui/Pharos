import AppKit
import SwiftUI
import PharosCore

// MARK: - Animated Spinning Fan Blade
private struct SpinningFanBlade: View {
    let rpm: Int
    var hardware3D: Bool = true
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
        let clamped = max(800, min(7000, rpm))
        let factor = 1.0 - (Double(clamped - 800) / 6200.0)
        return max(0.25, 0.25 + factor * 1.55)
    }
}

// MARK: - Animatable Rolling RPM HUD Text (Smooth Digits with Optional Gaussian Blur)
private struct RollingRPMText: View, Animatable {
    var rpm: Double
    var isRedline: Bool
    var blurRadius: CGFloat

    var animatableData: Double {
        get { rpm }
        set { rpm = newValue }
    }

    var body: some View {
        let displayInt = max(0, Int(rpm.rounded()))
        Text(displayInt > 0 ? "\(displayInt)" : "0")
            .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(isRedline ? Color.red : Color.primary)
            .blur(radius: blurRadius)
    }
}

// MARK: - Centered Aerodynamic Needle Path
private struct NeedleShape: Shape {
    let needleLength: CGFloat
    let needleTail: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let w: CGFloat = 3.6
        let tipW: CGFloat = 1.2
        let topY = cy - needleLength
        let bottomY = cy + needleTail

        path.move(to: CGPoint(x: cx - w / 2, y: cy))
        path.addLine(to: CGPoint(x: cx - tipW / 2, y: topY))
        path.addLine(to: CGPoint(x: cx + tipW / 2, y: topY))
        path.addLine(to: CGPoint(x: cx + w / 2, y: cy))
        path.addLine(to: CGPoint(x: cx + w / 2, y: bottomY))
        path.addLine(to: CGPoint(x: cx - w / 2, y: bottomY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Needle Center Reflective Highlight Spine
private struct NeedleSpineShape: Shape {
    let needleLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let topY = cy - needleLength + 4
        let bottomY = cy - 2

        path.move(to: CGPoint(x: cx - 0.45, y: bottomY))
        path.addLine(to: CGPoint(x: cx - 0.45, y: topY))
        path.addLine(to: CGPoint(x: cx + 0.45, y: topY))
        path.addLine(to: CGPoint(x: cx + 0.45, y: bottomY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Automotive Speedometer Needle with Motion Blur & Co-axial Pivot
private struct FanSpeedometerNeedle: View {
    let angle: Double
    let radius: CGFloat
    let isRedline: Bool
    var motionBlur: CGFloat = 0
    var hardware3D: Bool = true

    var body: some View {
        let needleLength = radius * 0.86
        let needleTail = radius * 0.16

        ZStack {
            // 1. Aerodynamic Motion Blur Ghost Trail (Only in 3D acceleration mode when moving fast)
            if hardware3D && motionBlur > 0.8 {
                NeedleShape(needleLength: needleLength, needleTail: needleTail)
                    .fill(
                        LinearGradient(
                            colors: isRedline
                                ? [Color.red.opacity(0.40), Color.orange.opacity(0.12)]
                                : [Color.orange.opacity(0.40), Color.cyan.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blur(radius: motionBlur * 1.3)
                    .rotationEffect(.degrees(angle - (angle > 360 ? 3.5 : -3.5)), anchor: .center)
            }

            // 2. Co-rotating Drop Shadow (Rotated with angle, cast down-right)
            NeedleShape(needleLength: needleLength, needleTail: needleTail)
                .fill(Color.black.opacity(0.38))
                .blur(radius: 2.0)
                .rotationEffect(.degrees(angle), anchor: .center)
                .offset(x: 1.5, y: 1.5)

            // 3. Dynamic Illuminated Racing Needle
            ZStack {
                // Tapered illuminated body
                NeedleShape(needleLength: needleLength, needleTail: needleTail)
                    .fill(
                        LinearGradient(
                            colors: isRedline
                                ? [Color(red: 1.0, green: 0.1, blue: 0.1), Color(red: 1.0, green: 0.45, blue: 0.1)]
                                : [Color.orange, Color(red: 1.0, green: 0.25, blue: 0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: (isRedline ? Color.red : Color.orange).opacity(0.55),
                        radius: 4,
                        x: 0,
                        y: 0
                    )

                // Sharp center reflective highlight spine
                NeedleSpineShape(needleLength: needleLength)
                    .fill(Color.white.opacity(0.85))
            }
            .blur(radius: hardware3D ? motionBlur * 0.7 : 0)
            .rotationEffect(.degrees(angle), anchor: .center)

            // 4. Machined Dual-Concentric Pivot Hub Cap
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.black.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 3, x: 0, y: 1.5)

            // Inner Rivet Core
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
    @AppStorage("pharos.gauge3DAcceleration") private var gauge3DAcceleration: Bool = true

    public let fan: FanReading
    public let count: Int
    public let targetRPM: Int?

    // Smooth physics & Gaussian blur states
    @State private var animatedRPM: Double = 0
    @State private var motionBlur: CGFloat = 0
    @State private var hasAppeared: Bool = false

    public init(fan: FanReading, count: Int, targetRPM: Int? = nil) {
        self.fan = fan
        self.count = count
        self.targetRPM = targetRPM
    }

    private var scale: FanGaugeScale {
        FanGaugeScale(minRPM: fan.minRPM, maxRPM: fan.maxRPM)
    }

    private var currentRPM: Int {
        Int(animatedRPM.rounded())
    }

    private var isRedline: Bool {
        scale.isRedline(rpm: currentRPM)
    }

    private var currentFraction: Double {
        scale.fraction(for: currentRPM)
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

                    // 2. Background Track Arc (270° Sweep starting at 225° / 7:30 position)
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            Color.primary.opacity(0.08),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(scale.circleRotationAngle))
                        .frame(width: radius * 1.62, height: radius * 1.62)

                    // 3. Redline Danger Arc Segment (> 85% RPM)
                    let redlineStartFrac = scale.redlineStartFraction * 0.75
                    Circle()
                        .trim(from: redlineStartFrac, to: 0.75)
                        .stroke(
                            Color.red.opacity(0.28),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(scale.circleRotationAngle))
                        .frame(width: radius * 1.62, height: radius * 1.62)

                    // 4. Dynamic Speed Ribbon (Always in tree, smooth trim + optional Gaussian blur)
                    let progress = currentFraction * 0.75
                    Circle()
                        .trim(from: 0, to: max(0.0001, progress))
                        .stroke(
                            LinearGradient(
                                colors: speedGradientColors(actualRPM: currentRPM),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(scale.circleRotationAngle))
                        .frame(width: radius * 1.62, height: radius * 1.62)
                        .shadow(
                            color: (isRedline ? Color.red : Color.cyan).opacity(0.35),
                            radius: 5,
                            x: 0,
                            y: 0
                        )
                        .blur(radius: gauge3DAcceleration ? motionBlur * 0.65 : 0)
                        .opacity(progress > 0.001 ? 1 : 0)

                    // 5. High-Precision Graduation Tick Marks & Numerals
                    dialGraduations(radius: radius * 0.81)

                    // 6. Target RPM Notch Marker (when in Manual Mode)
                    if let target = targetRPM, target > 0, fan.mode == .manual {
                        targetMarker(targetRPM: target, radius: radius * 0.81)
                    }

                    // 7. High-Precision Racing Needle (Co-axial with pivot and tick marks)
                    FanSpeedometerNeedle(
                        angle: scale.angle(for: currentRPM),
                        radius: radius * 0.81,
                        isRedline: isRedline,
                        motionBlur: motionBlur,
                        hardware3D: gauge3DAcceleration
                    )
                    .frame(width: side, height: side)

                    // 8. Digital HUD Cluster (Rolling Number + Optional Gaussian Blur)
                    VStack(spacing: 2) {
                        RollingRPMText(
                            rpm: animatedRPM,
                            isRedline: isRedline,
                            blurRadius: gauge3DAcceleration ? motionBlur * 0.45 : 0
                        )

                        HStack(spacing: 4) {
                            SpinningFanBlade(rpm: currentRPM, hardware3D: gauge3DAcceleration)
                            Text("RPM")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.secondary)
                        }

                        // Duty Cycle & Health Tag
                        Text(currentRPM == 0 ? l10n.fanStopped : "\(Int(currentFraction * 100))%")
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
                        Text("\(l10n.fanDutyCycle): \(String(format: "%.1f%%", currentFraction * 100))")
                            .font(.system(size: 10.5).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                // Mini horizontal linear progress bar
                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: speedGradientColors(actualRPM: currentRPM), startPoint: .leading, endPoint: .trailing))
                            .frame(width: barGeo.size.width * CGFloat(currentFraction))
                            .blur(radius: gauge3DAcceleration ? motionBlur * 0.4 : 0)
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
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                let targetVal = Double(fan.actualRPM)
                if targetVal > 0 {
                    if gauge3DAcceleration {
                        // Smooth self-check ignition sweep
                        animatedRPM = max(0, targetVal - 800)
                        withAnimation(.easeOut(duration: 0.12)) {
                            motionBlur = 2.0
                        }
                        withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                            animatedRPM = targetVal
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                motionBlur = 0
                            }
                        }
                    } else {
                        // Reduced motion: lightweight spring without blur
                        animatedRPM = targetVal
                    }
                } else {
                    animatedRPM = 0
                }
            } else {
                animatedRPM = Double(fan.actualRPM)
            }
        }
        .onChange(of: fan.actualRPM) { _, newRPM in
            let delta = abs(Double(newRPM) - animatedRPM)
            if gauge3DAcceleration && delta > 75 {
                // High delta transition with 3D motion blur
                let blurTarget = min(4.8, max(1.2, CGFloat(delta) / 450.0))
                withAnimation(.easeOut(duration: 0.10)) {
                    motionBlur = blurTarget
                }
                withAnimation(.spring(response: 0.58, dampingFraction: 0.76)) {
                    animatedRPM = Double(newRPM)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        motionBlur = 0
                    }
                }
            } else {
                // Reduced motion / small delta: standard lightweight spring
                motionBlur = 0
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    animatedRPM = Double(newRPM)
                }
            }
        }
    }

    // MARK: - Tick Marks & Upright Numerals
    @ViewBuilder
    private func dialGraduations(radius: CGFloat) -> some View {
        ZStack {
            // A. Minor micro-ticks every 100 RPM
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

            // C. Major ticks every 1000 RPM + Upright Numerals
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
        } else if currentFraction >= 0.65 {
            return [Color.cyan, Color.yellow, Color.orange]
        } else {
            return [Color(red: 0.1, green: 0.85, blue: 0.95), Color.blue, Color(red: 0.3, green: 0.5, blue: 1.0)]
        }
    }

    private var statusColor: Color {
        if currentRPM == 0 { return .secondary }
        if isRedline { return .red }
        if currentFraction >= 0.70 { return .orange }
        return .green
    }
}

// MARK: - Automotive Dual/Single Fan Cockpit Cluster View
public struct FanSpeedometerClusterView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var fanStore = FanStore.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("pharos.fanViewMode") private var viewMode: String = "gauge"
    @AppStorage("pharos.gauge3DAcceleration") private var gauge3DAcceleration: Bool = true

    // View switching state
    @State private var isSwitchingMode: Bool = false

    public init() {}

    public var body: some View {
        let fans = store.thermals?.fans ?? []
        VStack(alignment: .leading, spacing: 12) {
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

                // View Mode Switcher
                Picker("", selection: Binding(
                    get: { viewMode },
                    set: { newMode in
                        guard newMode != viewMode else { return }
                        if gauge3DAcceleration {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                isSwitchingMode = true
                            }
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                viewMode = newMode
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    isSwitchingMode = false
                                }
                            }
                        } else {
                            withAnimation(.default) {
                                viewMode = newMode
                            }
                        }
                    }
                )) {
                    Label(l10n.fanViewModeGauge, systemImage: "gauge.with.needle")
                        .tag("gauge")
                    Label(l10n.fanViewModeBars, systemImage: "chart.bar.fill")
                        .tag("bar")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            // 3D Motion Notice Banner (Prompting GPU performance / energy consumption)
            if viewMode == "gauge" {
                if gauge3DAcceleration {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.orange)
                        Text(l10n.gaugeMotionNoticeBanner)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Button(l10n.gaugeReduceMotionAction) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                gauge3DAcceleration = false
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.08))
                    )
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.green)
                        Text(l10n.gaugeReducedMotionNotice)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Button(l10n.gaugeEnable3DAction) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                gauge3DAcceleration = true
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.08))
                    )
                }
            }

            Group {
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
            .blur(radius: (gauge3DAcceleration && isSwitchingMode) ? 6.5 : 0)
            .scaleEffect((gauge3DAcceleration && isSwitchingMode) ? 0.985 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: isSwitchingMode)
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

// MARK: - Classic Fan Bar Card (Preserved with Smooth Animations)
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
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: fan.actualRPM)
                Text("rpm").font(.system(size: 11)).foregroundStyle(.secondary)
                if fan.actualRPM == 0 {
                    Text(l10n.fanStopped).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.primary.opacity(0.08))
                    Rectangle().fill(Color.blue)
                        .frame(width: geo.size.width * CGFloat(fan.fraction))
                        .animation(.spring(response: 0.52, dampingFraction: 0.78), value: fan.fraction)
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
