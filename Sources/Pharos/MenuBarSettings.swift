import AppKit
import Carbon.HIToolbox
import PharosCore

/// Available metrics that can be enabled, combined, and ordered on the menu bar.
public enum MenuBarMetric: String, CaseIterable, Identifiable, Codable, Sendable {
    case ports
    case temperature
    case memory
    case projects
    case disk
    case battery

    public var id: String { rawValue }

    public var sfSymbol: String {
        switch self {
        case .ports: return "network"
        case .temperature: return "thermometer.medium"
        case .memory: return "memorychip"
        case .projects: return "folder"
        case .disk: return "internaldrive"
        case .battery: return "battery.100percent"
        }
    }

    public var shortPrefix: String {
        switch self {
        case .ports: return "P"
        case .temperature: return "°C"
        case .memory: return "MEM"
        case .projects: return "PRJ"
        case .disk: return "DISK"
        case .battery: return "BAT"
        }
    }

    public var upperLabel: String {
        switch self {
        case .ports: return "PORT"
        case .temperature: return "TEMP"
        case .memory: return "MEM"
        case .projects: return "PROJ"
        case .disk: return "DISK"
        case .battery: return "BATT"
        }
    }

    @MainActor
    func value(store: ProjectStore, style: MenuBarDisplayStyle) -> String? {
        switch self {
        case .ports:
            let count = store.totalPorts
            return "\(count)"
        case .temperature:
            guard let temp = store.thermals?.peakChipTemperature else { return nil }
            return "\(Int(temp.rounded()))°C"
        case .memory:
            guard let m = store.system else { return nil }
            let pct = Int((m.usedFraction * 100).rounded())
            return "\(pct)%"
        case .projects:
            let count = store.projects.count
            return "\(count)"
        case .disk:
            guard let disk = store.volumes.first(where: { $0.kind == .startup }) else { return nil }
            let pct = Int((disk.usedFraction * 100).rounded())
            return "\(pct)%"
        case .battery:
            let r = BatteryStore.shared.reading
            guard r.hasBattery else { return nil }
            return "\(r.currentPercent)%"
        }
    }

    @MainActor
    func formattedValue(store: ProjectStore, showLabel: Bool) -> String? {
        switch self {
        case .ports:
            let count = store.totalPorts
            return showLabel ? "\(count)P" : "\(count)"
        case .temperature:
            guard let temp = store.thermals?.peakChipTemperature else { return nil }
            return "\(Int(temp.rounded()))°C"
        case .memory:
            guard let m = store.system else { return nil }
            let pct = Int((m.usedFraction * 100).rounded())
            return showLabel ? "MEM \(pct)%" : "\(pct)%"
        case .projects:
            let count = store.projects.count
            return showLabel ? "\(count)PRJ" : "\(count)"
        case .disk:
            guard let disk = store.volumes.first(where: { $0.kind == .startup }) else { return nil }
            let pct = Int((disk.usedFraction * 100).rounded())
            return showLabel ? "DISK \(pct)%" : "\(pct)%"
        case .battery:
            let r = BatteryStore.shared.reading
            guard r.hasBattery else { return nil }
            return showLabel ? "BAT \(r.currentPercent)%" : "\(r.currentPercent)%"
        }
    }
}

/// Visual display style for metrics in the menu bar.
public enum MenuBarDisplayStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case iconAndValue // 微缩图标 + 数值 (默认推荐)
    case stacked      // 上下双行微缩仪表 (专业硬件仪表)
    case valueOnly    // 极简纯数值

    public var id: String { rawValue }
}

/// Separator style between metrics in the menu bar.
public enum MenuBarSeparator: String, CaseIterable, Identifiable, Codable, Sendable {
    case dot
    case pipe
    case space

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .dot: return " · "
        case .pipe: return " | "
        case .space: return "  "
        }
    }
}

/// Legacy single-choice option kept for backward compatibility and serialization.
public enum MenuBarText: String, CaseIterable, Identifiable {
    case none, projects, ports, memory, disk, battery
    public var id: String { rawValue }
}

/// Presets for the global "open popover" shortcut.
public enum PopoverHotkey: String, CaseIterable, Identifiable {
    case none, optCmdP, ctrlOptP, optCmdSpace

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: return L10n.shared.hotkeyNone
        case .optCmdP: return "⌥⌘P"
        case .ctrlOptP: return "⌃⌥P"
        case .optCmdSpace: return "⌥⌘Space"
        }
    }

    fileprivate var keyAndModifiers: (UInt32, UInt32)? {
        switch self {
        case .none: return nil
        case .optCmdP: return (UInt32(kVK_ANSI_P), UInt32(optionKey | cmdKey))
        case .ctrlOptP: return (UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey))
        case .optCmdSpace: return (UInt32(kVK_Space), UInt32(optionKey | cmdKey))
        }
    }
}

/// Menu-bar preferences: multi-metric composition, dynamic ring binding, and global shortcut.
@MainActor
final class MenuBarSettings: ObservableObject {
    static let shared = MenuBarSettings()

    @Published var enabledMetrics: [MenuBarMetric] {
        didSet {
            UserDefaults.standard.set(enabledMetrics.map(\.rawValue), forKey: Keys.metrics)
            syncLegacyText()
            if let first = enabledMetrics.first, ringMetric != first {
                ringMetric = first
            }
        }
    }

    @Published var ringMetric: MenuBarMetric {
        didSet {
            UserDefaults.standard.set(ringMetric.rawValue, forKey: Keys.ringMetric)
            ensureRingMetricFirst()
        }
    }

    /// Ensures the metric driving the dynamic ring is placed at index 0 of enabledMetrics.
    func ensureRingMetricFirst() {
        guard !enabledMetrics.isEmpty else { return }
        if let idx = enabledMetrics.firstIndex(of: ringMetric) {
            if idx != 0 {
                let m = enabledMetrics.remove(at: idx)
                enabledMetrics.insert(m, at: 0)
            }
        } else {
            enabledMetrics.insert(ringMetric, at: 0)
        }
    }

    func applyPreset(_ metrics: [MenuBarMetric]) {
        enabledMetrics = metrics
        if let first = metrics.first {
            ringMetric = first
        }
    }

    @Published var displayStyle: MenuBarDisplayStyle {
        didSet {
            UserDefaults.standard.set(displayStyle.rawValue, forKey: Keys.displayStyle)
            showMetricLabels = (displayStyle != .valueOnly)
        }
    }

    @Published var showMetricLabels: Bool {
        didSet {
            UserDefaults.standard.set(showMetricLabels, forKey: Keys.showLabels)
        }
    }

    @Published var separatorStyle: MenuBarSeparator {
        didSet {
            UserDefaults.standard.set(separatorStyle.rawValue, forKey: Keys.separator)
        }
    }

    @Published var text: MenuBarText {
        didSet {
            UserDefaults.standard.set(text.rawValue, forKey: Keys.text)
        }
    }

    @Published var maxProjects: Int {
        didSet { UserDefaults.standard.set(maxProjects, forKey: Keys.maxProjects) }
    }

    @Published var maxPorts: Int {
        didSet { UserDefaults.standard.set(maxPorts, forKey: Keys.maxPorts) }
    }

    @Published var hotkey: PopoverHotkey {
        didSet {
            UserDefaults.standard.set(hotkey.rawValue, forKey: Keys.hotkey)
            registerHotkey()
        }
    }

    /// Shown under the picker when registration fails (combo taken by another app).
    @Published private(set) var hotkeyError: String?

    private enum Keys {
        static let text = "menuBarText"
        static let metrics = "pharos.menuBarMetrics"
        static let ringMetric = "pharos.menuBarRingMetric"
        static let showLabels = "pharos.menuBarShowLabels"
        static let displayStyle = "pharos.menuBarDisplayStyle"
        static let separator = "pharos.menuBarSeparator"
        static let hotkey = "popoverHotkey"
        static let maxProjects = "maxProjectsCapacity"
        static let maxPorts = "maxPortsCapacity"
    }

    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    public static let defaultMaxProjects = 25
    public static let defaultMaxPorts = 30

    private init() {
        // 1. Determine enabled metrics
        let initialMetrics: [MenuBarMetric]
        if let savedMetrics = UserDefaults.standard.stringArray(forKey: Keys.metrics) {
            initialMetrics = savedMetrics.compactMap(MenuBarMetric.init)
        } else if let legacy = UserDefaults.standard.string(forKey: Keys.text).flatMap(MenuBarText.init) {
            switch legacy {
            case .none: initialMetrics = []
            case .ports: initialMetrics = [.ports]
            case .memory: initialMetrics = [.memory]
            case .projects: initialMetrics = [.projects]
            case .disk: initialMetrics = [.disk]
            case .battery: initialMetrics = [.battery]
            }
            UserDefaults.standard.set(initialMetrics.map(\.rawValue), forKey: Keys.metrics)
        } else {
            // Default on fresh start: Listening ports + Memory percentage
            initialMetrics = [.ports, .memory]
            UserDefaults.standard.set(initialMetrics.map(\.rawValue), forKey: Keys.metrics)
        }
        enabledMetrics = initialMetrics

        // 2. Load ringMetric (default matches first enabled metric, or .projects)
        let savedRing = UserDefaults.standard.string(forKey: Keys.ringMetric).flatMap(MenuBarMetric.init)
        ringMetric = savedRing ?? initialMetrics.first ?? .projects

        // 3. Load displayStyle (default .valueOnly for clean typography)
        let resolvedStyle: MenuBarDisplayStyle
        if let savedStyle = UserDefaults.standard.string(forKey: Keys.displayStyle).flatMap(MenuBarDisplayStyle.init) {
            resolvedStyle = savedStyle
        } else {
            resolvedStyle = .valueOnly
        }
        displayStyle = resolvedStyle
        showMetricLabels = (resolvedStyle != .valueOnly)

        // 4. Load separatorStyle (default .dot)
        separatorStyle = UserDefaults.standard.string(forKey: Keys.separator).flatMap(MenuBarSeparator.init) ?? .dot

        // 5. Capacities & hotkey
        let savedProjects = UserDefaults.standard.integer(forKey: Keys.maxProjects)
        maxProjects = savedProjects > 0 ? savedProjects : Self.defaultMaxProjects
        let savedPorts = UserDefaults.standard.integer(forKey: Keys.maxPorts)
        maxPorts = savedPorts > 0 ? savedPorts : Self.defaultMaxPorts
        hotkey = UserDefaults.standard.string(forKey: Keys.hotkey).flatMap(PopoverHotkey.init) ?? .none

        // 6. Legacy text property
        text = initialMetrics.first.flatMap { m -> MenuBarText? in
            switch m {
            case .ports: return .ports
            case .memory: return .memory
            case .projects: return .projects
            case .disk: return .disk
            case .battery: return .battery
            case .temperature: return .memory
            }
        } ?? .none

        installHandler()
        registerHotkey()
        ensureRingMetricFirst()
    }

    private func syncLegacyText() {
        if enabledMetrics.isEmpty {
            text = .none
        } else if let first = enabledMetrics.first {
            switch first {
            case .ports: text = .ports
            case .memory: text = .memory
            case .projects: text = .projects
            case .disk: text = .disk
            case .battery: text = .battery
            case .temperature: text = .memory
            }
        }
    }

    /// Combined text for the enabled metrics, or nil for icon-only.
    func combinedLabel(for store: ProjectStore) -> String? {
        guard !enabledMetrics.isEmpty else { return nil }
        let values = enabledMetrics.compactMap { $0.formattedValue(store: store, showLabel: showMetricLabels) }
        guard !values.isEmpty else { return nil }
        return values.joined(separator: separatorStyle.symbol)
    }

    /// Backward compatibility for existing callers.
    func label(for store: ProjectStore) -> String? {
        combinedLabel(for: store)
    }

    // MARK: - Hotkey

    private static let signature: OSType = 0x5048_5253 // "PHRS"

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MenuBarSettings.togglePopover() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }

    private func registerHotkey() {
        if let hotkeyRef { UnregisterEventHotKey(hotkeyRef) }
        hotkeyRef = nil
        hotkeyError = nil
        guard let (key, mods) = hotkey.keyAndModifiers else { return }
        let status = RegisterEventHotKey(key, mods, EventHotKeyID(signature: Self.signature, id: 1),
                                         GetApplicationEventTarget(), 0, &hotkeyRef)
        if status != noErr { hotkeyError = L10n.shared.hotkeyFailed }
    }

    func reset() {
        enabledMetrics = [.projects, .temperature, .memory]
        ringMetric = .projects
        displayStyle = .valueOnly
        showMetricLabels = false
        separatorStyle = .dot
        text = .projects
        maxProjects = Self.defaultMaxProjects
        maxPorts = Self.defaultMaxPorts
        hotkey = .none
    }

    /// MenuBarExtra has no API to open its popover, so click its status item button.
    static func togglePopover() {
        func find(_ view: NSView?) -> NSStatusBarButton? {
            guard let view else { return nil }
            if let button = view as? NSStatusBarButton { return button }
            for sub in view.subviews { if let b = find(sub) { return b } }
            return nil
        }
        let button = NSApp.windows.lazy.compactMap { find($0.contentView) }.first
        NSApp.activate(ignoringOtherApps: true)
        button?.performClick(nil)
    }
}
