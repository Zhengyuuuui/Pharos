import Foundation

public enum OnboardingPolicy {
    public static let currentVersion = 1
    public static let stepCount = 6

    public static let completedVersionKey = "pharos.onboardingCompletedVersion"
    public static let resumeStepKey = "pharos.onboardingResumeStep"

    /// Keys written by Pharos versions that predate onboarding; any of them means an upgrade.
    public static let existingUserTraceKeys: [String] = [
        "popoverLayout.v1",
        "batteryTargetLimit",
        "batteryLimitEnabled",
        "favoriteWorkspaces.v1",
        "chromePresets.v1",
        "refreshSeconds",
        "menuBarText",
    ]

    public enum LaunchDecision: Equatable, Sendable {
        /// Brand-new user, or resuming after a Full Disk Access restart.
        case showOnboarding(startStep: Int)
        /// Upgrading user: mark as completed silently and open the main window.
        case skipForExistingUpgrader
        case openMainWindow
    }

    public static func evaluateLaunch(
        completedVersion: Int?,
        resumeStep: Int?,
        presentKeys: Set<String>
    ) -> LaunchDecision {
        if let completedVersion, completedVersion >= currentVersion {
            return .openMainWindow
        }
        if let resumeStep, (0..<stepCount).contains(resumeStep) {
            return .showOnboarding(startStep: resumeStep)
        }
        if !presentKeys.isDisjoint(with: existingUserTraceKeys) {
            return .skipForExistingUpgrader
        }
        return .showOnboarding(startStep: 0)
    }
}

/// Step 04 edits this value copy; nothing touches hardware until the user confirms.
public struct OnboardingDraft: Equatable, Sendable {
    public enum ChargingChoice: Equatable, Sendable {
        case systemManaged
        case pharosLimit
    }

    public var chargingChoice: ChargingChoice
    public private(set) var targetLimit: Int
    public var persistentGuard: Bool
    public var pinBatteryInPopover: Bool
    public var menuBarTextRaw: String
    public var launchAtLogin: Bool

    public init(
        chargingChoice: ChargingChoice = .systemManaged,
        targetLimit: Int = 80,
        persistentGuard: Bool = true,
        pinBatteryInPopover: Bool = true,
        menuBarTextRaw: String = "none",
        launchAtLogin: Bool = false
    ) {
        self.chargingChoice = chargingChoice
        self.targetLimit = BatteryPolicy.clampLimit(targetLimit)
        self.persistentGuard = persistentGuard
        self.pinBatteryInPopover = pinBatteryInPopover
        self.menuBarTextRaw = menuBarTextRaw
        self.launchAtLogin = launchAtLogin
    }

    /// First run never opts into a charge limit; the battery card is pinned only if there is a battery.
    public static func firstLaunch(hasBattery: Bool) -> OnboardingDraft {
        OnboardingDraft(chargingChoice: .systemManaged, pinBatteryInPopover: hasBattery, launchAtLogin: false)
    }

    public mutating func setTargetLimit(_ percent: Int) {
        targetLimit = BatteryPolicy.clampLimit(percent)
    }
}

/// What `BatteryStore.install` should send to a freshly (re)started daemon, which always boots in `.system`.
public enum BatteryInstallPlan {
    /// - Returns: the mode to apply, or `nil` to stay in `.system`.
    ///   With `activateLimit == false` an install never *adds* a limit; it only puts back one the
    ///   user already had (helper update while limiting, or a persisted limit preference).
    public static func modeAfterInstall(
        activateLimit: Bool,
        helperWasReady: Bool,
        currentMode: BatteryMode,
        limitEnabled: Bool,
        targetLimit: Int
    ) -> BatteryMode? {
        let limit = BatteryMode.limit(maxPercent: BatteryPolicy.clampLimit(targetLimit))
        if helperWasReady, currentMode != .system { return currentMode }
        if limitEnabled { return limit }
        // An update of a helper the user left in system mode must not start limiting.
        if helperWasReady { return nil }
        return activateLimit ? limit : nil
    }
}

public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome, powerIntro, permissions, preferences, menuBar, completion

    public var isFirst: Bool { self == .welcome }
    public var isLast: Bool { self == .completion }
    public var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    public var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    /// Unknown indices (stale resume step) start from the beginning.
    public static func at(_ index: Int) -> OnboardingStep { OnboardingStep(rawValue: index) ?? .welcome }
}

public enum OnboardingNavigationDirection: Sendable, Equatable {
    case forward, backward
}

/// How much motion the onboarding may use. Ordered from least to most.
public enum OnboardingMotionLevel: Int, Comparable, Sendable {
    /// Reduce Motion: opacity crossfade only.
    case minimal
    /// Low Power Mode or 3D acceleration off: spring scale/offset, no blur, no continuous frames.
    case reduced
    case rich

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    public static func resolve(reduceMotion: Bool, lowPower: Bool, gauge3DEnabled: Bool) -> Self {
        if reduceMotion { return .minimal }
        if lowPower || !gauge3DEnabled { return .reduced }
        return .rich
    }

    public var allowsScale: Bool { self >= .reduced }
    public var allowsBlur: Bool { self == .rich }
    public var allowsContinuousFrames: Bool { self == .rich }
}

/// Zoom-blur transition geometry, kept here so rest-state invariants are unit-tested.
public enum OnboardingTransitionGeometry {
    public static let maxBlurRadius: Double = 6.0
    public static let blurRadius: Double = 5.5
    public static let offset: Double = 28

    public enum Phase: Sendable { case willAppear, identity, didDisappear }

    public struct Values: Equatable, Sendable {
        public var scale: Double
        public var offsetX: Double
        public var blur: Double
        public var opacity: Double

        public init(scale: Double, offsetX: Double, blur: Double, opacity: Double) {
            self.scale = scale
            self.offsetX = offsetX
            self.blur = blur
            self.opacity = opacity
        }
    }

    public static func values(phase: Phase, direction: OnboardingNavigationDirection, level: OnboardingMotionLevel) -> Values {
        guard phase != .identity else { return Values(scale: 1, offsetX: 0, blur: 0, opacity: 1) }
        // Forward: incoming page comes from close (1.06) and the right; outgoing recedes (0.93) to the left.
        let incoming = phase == .willAppear
        let towardViewer = (direction == .forward) == incoming
        let scale = level.allowsScale ? (towardViewer ? 1.06 : 0.93) : 1
        let sign: Double = (direction == .forward) == incoming ? 1 : -1
        return Values(
            scale: scale,
            offsetX: level.allowsScale ? sign * offset : 0,
            blur: level.allowsBlur ? Swift.min(blurRadius, maxBlurRadius) : 0,
            opacity: 0
        )
    }
}
