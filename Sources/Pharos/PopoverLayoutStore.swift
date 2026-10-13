import Foundation
import PharosCore

/// The saved popover layout (Main window → Customize).
@MainActor
final class PopoverLayoutStore: ObservableObject {
    static let shared = PopoverLayoutStore()

    @Published private(set) var layout: PopoverLayout

    private static let key = "popoverLayout.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(PopoverLayout.self, from: data) {
            layout = saved
        } else {
            layout = .standard
        }
    }

    func update(_ change: (inout PopoverLayout) -> Void) {
        var next = layout
        change(&next)
        guard next != layout else { return }
        layout = next
        if let data = try? JSONEncoder().encode(next) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    func reset() { update { $0 = .standard } }
}
