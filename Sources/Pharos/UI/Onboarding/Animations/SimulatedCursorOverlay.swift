import SwiftUI
import PharosCore

// MARK: - Anchors

/// Click targets report their bounds as anchors, so the cursor lands on the real control
/// whatever the language, font size or layout.
struct OnboardingCursorTargetKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func onboardingCursorTarget(_ id: String) -> some View {
        anchorPreference(key: OnboardingCursorTargetKey.self, value: .bounds) { [id: $0] }
    }

    /// "Pressed" look shared by the real click and the simulated one.
    func onboardingCursorPressed(_ pressed: Bool, level: OnboardingMotionLevel) -> some View {
        scaleEffect(pressed && level.allowsScale ? 0.95 : 1)
            .brightness(pressed ? -0.06 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: pressed)
    }
}

// MARK: - Controller

/// Drives one cursor tour. Owned by the step view (`@StateObject`); the tour itself runs inside the
/// stage's `.task`, so leaving the page cancels it. A human hover/click cancels it immediately.
@MainActor
final class OnboardingCursorController: ObservableObject {
    @Published private(set) var position: CGPoint = .zero
    @Published private(set) var visible = false
    @Published private(set) var pressed = false
    @Published private(set) var moving = false
    @Published private(set) var rippleTick = 0
    @Published private(set) var pressedTargetID: String?

    /// Latest target centers in stage space. Not published: only the running tour reads them.
    var targets: [String: CGPoint] = [:]
    var stageSize: CGSize = .zero
    private var runner: Task<Void, Never>?
    private(set) var finished = false

    func isPressed(_ id: String) -> Bool { pressedTargetID == id }

    func play(_ script: OnboardingCursorScript, perform: @escaping @MainActor (String) -> Void) async {
        guard !finished else { return }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.run(script, perform: perform)
        }
        runner = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        runner = nil
        finished = true
        hide()
    }

    func cancelByUser() {
        guard !finished else { return }
        finished = true
        runner?.cancel()
        hide()
    }

    private func hide() {
        pressedTargetID = nil
        pressed = false
        moving = false
        withAnimation(.easeOut(duration: OnboardingCursorScript.fadeOutDuration)) { visible = false }
    }

    private func run(_ script: OnboardingCursorScript, perform: @MainActor (String) -> Void) async {
        guard await pause(script.initialDelay) else { return }
        position = CGPoint(x: stageSize.width * 0.82, y: stageSize.height * 0.92)
        withAnimation(.easeOut(duration: 0.18)) { visible = true }

        for step in script.steps {
            // Targets that aren't on screen (e.g. a tab that doesn't exist) are skipped, never guessed.
            guard let center = targets[step.targetID] else { continue }
            // Slightly left/below centre so the arrow tip doesn't cover the label.
            let point = CGPoint(x: center.x + 2, y: center.y + 3)
            moving = true
            withAnimation(.spring(response: step.moveDuration, dampingFraction: 0.86)) { position = point }
            guard await pause(step.moveDuration) else { return }
            moving = false
            guard await pause(step.aimPause) else { return }

            withAnimation(.spring(response: 0.14, dampingFraction: 0.7)) {
                pressed = true
                pressedTargetID = step.targetID
            }
            guard await pause(step.pressDuration) else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                pressed = false
                pressedTargetID = nil
            }
            rippleTick += 1
            perform(step.targetID)
            guard await pause(step.dwellAfterClick) else { return }
        }
    }

    private func pause(_ seconds: Double) async -> Bool {
        if seconds > 0 { try? await Task.sleep(for: .seconds(seconds)) }
        return !Task.isCancelled
    }
}

// MARK: - Stage

/// Wraps a demo area: collects anchors, draws the cursor on top, plays the script once and yields to
/// the user on the first real mouse movement or click. Reduce Motion: no cursor at all.
struct OnboardingCursorStage<Content: View>: View {
    @ObservedObject var controller: OnboardingCursorController
    let script: OnboardingCursorScript
    let level: OnboardingMotionLevel
    let perform: @MainActor (String) -> Void
    @ViewBuilder let content: Content

    @State private var firstHover: CGPoint?

    var body: some View {
        content
            .overlayPreferenceValue(OnboardingCursorTargetKey.self) { anchors in
                GeometryReader { proxy in
                    let centers = anchors.mapValues { a -> CGPoint in
                        let r = proxy[a]
                        return CGPoint(x: r.midX, y: r.midY)
                    }
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .onAppear { sync(centers, proxy.size) }
                            .onChange(of: centers) { _, new in sync(new, proxy.size) }
                            .onChange(of: proxy.size) { _, new in sync(centers, new) }
                        if level != .minimal {
                            SimulatedCursorView(controller: controller, level: level)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .onContinuousHover { phase in
                // Ignore the hover event that fires when the page appears under a resting pointer;
                // only real movement counts as the user taking over.
                guard case .active(let p) = phase else { return }
                if let start = firstHover {
                    if hypot(p.x - start.x, p.y - start.y) > 3 { controller.cancelByUser() }
                } else {
                    firstHover = p
                }
            }
            .simultaneousGesture(TapGesture().onEnded { controller.cancelByUser() })
            .task {
                guard level != .minimal else { return }
                await controller.play(script, perform: perform)
            }
    }

    private func sync(_ centers: [String: CGPoint], _ size: CGSize) {
        controller.targets = centers
        controller.stageSize = size
    }
}

// MARK: - Cursor

private struct SimulatedCursorView: View {
    @ObservedObject var controller: OnboardingCursorController
    let level: OnboardingMotionLevel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ClickRipple(tick: controller.rippleTick)
            MacArrowShape()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.8, lineJoin: .round))
                .overlay(MacArrowShape().fill(Color(white: 0.08)))
                .frame(width: 20, height: 24, alignment: .topLeading)
                .shadow(color: .black.opacity(0.28), radius: 3.5, x: 0, y: 1.5)
                .scaleEffect(controller.pressed ? 0.86 : 1, anchor: .topLeading)
                .blur(radius: level.allowsBlur && controller.moving ? 1.2 : 0)
        }
        .offset(x: controller.position.x, y: controller.position.y)
        .opacity(controller.visible ? 1 : 0)
        .accessibilityHidden(true)
    }
}

/// Standard macOS arrow, tip at (0, 0), drawn in a 20×24 box.
private struct MacArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: 0, y: 17))
        p.addLine(to: CGPoint(x: 4.2, y: 13.2))
        p.addLine(to: CGPoint(x: 7, y: 19.6))
        p.addLine(to: CGPoint(x: 9.6, y: 18.5))
        p.addLine(to: CGPoint(x: 6.9, y: 12.2))
        p.addLine(to: CGPoint(x: 12.4, y: 12.2))
        p.closeSubpath()
        return p
    }
}

/// One-shot ring per click; a property animation, so nothing ticks once it has faded.
private struct ClickRipple: View {
    let tick: Int
    @State private var progress: Double = 1

    var body: some View {
        let d = 6 + 28 * progress
        Circle()
            .stroke(PharosColor.accentFill.opacity(1 - progress), lineWidth: 1.5)
            .frame(width: d, height: d)
            .offset(x: -d / 2, y: -d / 2)
            .onChange(of: tick) { _, _ in
                progress = 0
                withAnimation(.easeOut(duration: 0.45)) { progress = 1 }
            }
    }
}
