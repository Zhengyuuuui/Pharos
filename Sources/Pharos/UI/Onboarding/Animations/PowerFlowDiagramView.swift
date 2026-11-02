import SwiftUI
import PharosCore

/// Adapter → logic board → battery cell, with dashed conduits whose dashes travel in the energy
/// direction. Dashes only move for a short window after each state change, then the timeline pauses
/// so an idle step draws no frames.
struct PowerFlowDiagramView: View {
    let flow: PowerDemoFlow
    let level: OnboardingMotionLevel
    @ObservedObject private var l10n = L10n.shared

    /// Seconds of dash motion after a state change before going still.
    static let motionWindow: Double = 3.0

    @State private var flowing = false
    @State private var motionToken = 0

    var body: some View {
        HStack(spacing: 0) {
            node(l10n.onboardingPowerNodeAdapter, "powerplug", active: flow.adapterConnected, tint: PharosColor.textPrimary)
            conduit(active: flow.adapterConnected, forward: true, label: nil)
            node(l10n.onboardingPowerNodeLogicBoard, "cpu", active: true, tint: PharosColor.textPrimary)
            conduit(active: flow.cellBranchActive, forward: flow.cellFlowsIntoBattery, label: milliampsText)
            node(l10n.onboardingPowerNodeBattery, cellIcon, active: flow.cellBranchActive || flow == .passthrough, tint: cellTint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PharosSpacing.s)
        .onAppear { kick() }
        .onChange(of: flow) { _, _ in kick() }
    }

    private func kick() {
        guard level.allowsContinuousFrames else { flowing = false; return }
        motionToken &+= 1
        let token = motionToken
        flowing = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.motionWindow))
            if token == motionToken { flowing = false }
        }
    }

    private var milliampsText: String {
        let mA = flow.cellMilliamps
        return mA > 0 ? "+\(mA) mA" : "\(mA) mA"
    }

    private var cellIcon: String {
        switch flow {
        case .charging: "bolt.fill"
        case .passthrough: "powerplug.fill"
        case .onBattery: "battery.75"
        }
    }

    private var cellTint: Color {
        switch flow {
        case .charging: PharosColor.success
        case .passthrough: .teal
        case .onBattery: PharosColor.textSecondary
        }
    }

    private func node(_ title: String, _ icon: String, active: Bool, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(active ? tint : PharosColor.textTertiary)
                .contentTransition(level == .minimal ? .identity : .symbolEffect(.replace))
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous).fill(PharosColor.fill))
            Text(title)
                .font(PharosFont.caption)
                .foregroundStyle(PharosColor.textSecondary)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: 96)
    }

    private func conduit(active: Bool, forward: Bool, label: String?) -> some View {
        VStack(spacing: 4) {
            Text(label ?? " ")
                .font(PharosFont.captionDigits)
                .foregroundStyle(active ? PharosColor.textSecondary : PharosColor.textTertiary)
                .contentTransition(level == .minimal ? .identity : .numericText(value: Double(flow.cellMilliamps)))
            Group {
                if flowing && active {
                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !flowing)) { ctx in
                        DashedConduit(active: true, forward: forward,
                                      phase: ctx.date.timeIntervalSinceReferenceDate)
                    }
                } else {
                    DashedConduit(active: active, forward: forward, phase: 0)
                }
            }
            .frame(height: 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.bottom, 18)
        .animation(.easeInOut(duration: 0.3), value: active)
    }
}

private struct DashedConduit: View {
    let active: Bool
    let forward: Bool
    let phase: Double

    var body: some View {
        Canvas { ctx, size in
            let y = size.height / 2
            var line = Path()
            line.move(to: CGPoint(x: forward ? 0 : 6, y: y))
            line.addLine(to: CGPoint(x: forward ? size.width - 6 : size.width, y: y))
            let dashPeriod = 10.0
            let offset = (phase * 24).truncatingRemainder(dividingBy: dashPeriod)
            let color = active ? Color.primary.opacity(0.75) : Color.primary.opacity(0.15)
            ctx.stroke(line, with: .color(color),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5],
                                          dashPhase: forward ? -offset : offset))
            // Arrow head shows direction even when still.
            var head = Path()
            if forward {
                head.move(to: CGPoint(x: size.width - 8, y: y - 4))
                head.addLine(to: CGPoint(x: size.width - 2, y: y))
                head.addLine(to: CGPoint(x: size.width - 8, y: y + 4))
            } else {
                head.move(to: CGPoint(x: 8, y: y - 4))
                head.addLine(to: CGPoint(x: 2, y: y))
                head.addLine(to: CGPoint(x: 8, y: y + 4))
            }
            ctx.stroke(head, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
