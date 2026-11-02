import SwiftUI
import PharosCore

enum OnboardingMotion {
    static func level(reduceMotion: Bool) -> OnboardingMotionLevel {
        .resolve(reduceMotion: reduceMotion, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }

    static func stepAnimation(_ level: OnboardingMotionLevel) -> Animation {
        level == .minimal ? .easeInOut(duration: 0.16) : .spring(response: 0.38, dampingFraction: 0.86)
    }
}

/// Camera dolly + transient Gaussian blur. At rest (`.identity`) blur is exactly 0 and scale exactly 1,
/// so Metal skips the offscreen pass once settled. Attach only to the step container, never the window.
struct OnboardingZoomBlurTransition: Transition {
    let direction: OnboardingNavigationDirection
    let level: OnboardingMotionLevel

    func body(content: Content, phase: TransitionPhase) -> some View {
        let geometryPhase: OnboardingTransitionGeometry.Phase = switch phase {
        case .willAppear: .willAppear
        case .identity: .identity
        case .didDisappear: .didDisappear
        }
        let v = OnboardingTransitionGeometry.values(phase: geometryPhase, direction: direction, level: level)
        content
            .scaleEffect(v.scale)
            .offset(x: v.offsetX)
            .blur(radius: v.blur)
            .opacity(v.opacity)
    }
}

/// Staggered rise-in for titles / rows inside a step (70 ms per index, 8 pt).
struct OnboardingStaggeredEntrance: ViewModifier {
    let index: Int
    let level: OnboardingMotionLevel
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || !level.allowsScale ? 0 : 8)
            .onAppear {
                let anim = level == .minimal
                    ? Animation.easeOut(duration: 0.16)
                    : .spring(response: 0.42, dampingFraction: 0.85).delay(0.07 * Double(index))
                withAnimation(anim) { shown = true }
            }
    }
}

extension View {
    func onboardingEntrance(_ index: Int, level: OnboardingMotionLevel) -> some View {
        modifier(OnboardingStaggeredEntrance(index: index, level: level))
    }
}
