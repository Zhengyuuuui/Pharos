import AppKit
import Carbon.HIToolbox

/// What the menu bar shows next to the icon.
enum MenuBarText: String, CaseIterable, Identifiable {
    case none, projects, ports, memory, disk
    var id: String { rawValue }
}

/// Presets for the global "open popover" shortcut. A fixed list instead of a
/// key recorder keeps it simple and avoids clashing with common app shortcuts.
enum PopoverHotkey: String, CaseIterable, Identifiable {
    case none, optCmdP, ctrlOptP, optCmdSpace

    var id: String { rawValue }

    var label: String {
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

/// Menu-bar preferences: extra text next to the icon and the global shortcut.
/// The shortcut uses Carbon's RegisterEventHotKey (Apple SDK), which needs no
/// Accessibility permission and only fires for this exact key combo.
@MainActor
final class MenuBarSettings: ObservableObject {
    static let shared = MenuBarSettings()

    @Published var text: MenuBarText {
        didSet { UserDefaults.standard.set(text.rawValue, forKey: Keys.text) }
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
        static let hotkey = "popoverHotkey"
        static let maxProjects = "maxProjectsCapacity"
        static let maxPorts = "maxPortsCapacity"
    }

    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {
        text = UserDefaults.standard.string(forKey: Keys.text).flatMap(MenuBarText.init) ?? .none
        let savedProjects = UserDefaults.standard.integer(forKey: Keys.maxProjects)
        maxProjects = savedProjects > 0 ? savedProjects : 25
        let savedPorts = UserDefaults.standard.integer(forKey: Keys.maxPorts)
        maxPorts = savedPorts > 0 ? savedPorts : 30
        hotkey = UserDefaults.standard.string(forKey: Keys.hotkey).flatMap(PopoverHotkey.init) ?? .none
        installHandler()
        registerHotkey()
    }

    /// The menu bar label text for the current scan, or nil for icon only.
    func label(for store: ProjectStore) -> String? {
        switch text {
        case .none: return nil
        case .projects: return "\(store.projects.count)"
        case .ports: return "\(store.totalPorts)"
        case .memory: return store.system.map { "\(Int(($0.usedFraction * 100).rounded()))%" }
        case .disk: return store.volumes.first { $0.kind == .startup }.map { "\(Int(($0.usedFraction * 100).rounded()))%" }
        }
    }

    // MARK: - Hotkey

    private static let signature: OSType = 0x5048_5253 // "PHRS"

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // C callback: can't capture context, so it hops to the main actor and
        // reaches the popover through the status item (no stored self pointer).
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
