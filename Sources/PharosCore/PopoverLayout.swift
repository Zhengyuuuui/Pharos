import Foundation

/// A section that can be placed in the menu-bar popover.
public enum PopoverBlock: String, Codable, CaseIterable, Sendable {
    case memory, disk, thermals, devProjects, topApps, projects, browsers, favorites
}

public enum PopoverTab: String, Codable, CaseIterable, Sendable {
    case overview, projects
}

/// Which blocks each popover tab shows, in order. Like widgets: every block
/// appears at most once across both tabs; unused blocks wait in the library.
public struct PopoverLayout: Equatable, Sendable {
    public private(set) var overview: [PopoverBlock]
    public private(set) var projects: [PopoverBlock]
    /// How many running projects the "Running projects" block shows before it
    /// scrolls. 0 = all (the whole popover scrolls instead).
    public var visibleProjectRows: Int {
        didSet { visibleProjectRows = Self.clampRows(visibleProjectRows) }
    }

    public static let projectRowChoices = [3, 5, 8, 10, 15]
    public static let defaultProjectRows = 5
    public static let minProjectRows = 3

    /// 0 is kept for layouts saved as "show all"; anything else is 3…50.
    /// The UI further caps it at the number of projects running.
    static func clampRows(_ n: Int) -> Int { n <= 0 ? 0 : Swift.min(Swift.max(n, minProjectRows), 50) }

    /// Matches the popover before it was customizable.
    public static let standard = PopoverLayout(overview: [.memory, .disk, .thermals, .devProjects, .topApps],
                                               projects: [.projects, .browsers])

    public init(overview: [PopoverBlock], projects: [PopoverBlock], visibleProjectRows: Int = defaultProjectRows) {
        var seen = Set<PopoverBlock>()
        self.overview = overview.filter { seen.insert($0).inserted }
        self.projects = projects.filter { seen.insert($0).inserted }
        self.visibleProjectRows = Self.clampRows(visibleProjectRows)
    }

    public subscript(tab: PopoverTab) -> [PopoverBlock] {
        tab == .overview ? overview : projects
    }

    public var unused: [PopoverBlock] {
        PopoverBlock.allCases.filter { tab(of: $0) == nil }
    }

    /// Tabs that have something to show, in display order.
    public var visibleTabs: [PopoverTab] { PopoverTab.allCases.filter { !self[$0].isEmpty } }

    public func tab(of block: PopoverBlock) -> PopoverTab? {
        if overview.contains(block) { return .overview }
        if projects.contains(block) { return .projects }
        return nil
    }

    /// Puts `block` into `tab` before `target` (or at the end), taking it out of
    /// wherever it was. Dropping a block onto itself changes nothing.
    public mutating func insert(_ block: PopoverBlock, into tab: PopoverTab, before target: PopoverBlock? = nil) {
        guard block != target else { return }
        remove(block)
        var list = self[tab]
        let index = target.flatMap { list.firstIndex(of: $0) } ?? list.endIndex
        list.insert(block, at: index)
        set(list, for: tab)
    }

    public mutating func remove(_ block: PopoverBlock) {
        overview.removeAll { $0 == block }
        projects.removeAll { $0 == block }
    }

    /// Moves one step up (-1) or down (+1) within its tab.
    public mutating func move(_ block: PopoverBlock, by offset: Int) {
        guard let tab = tab(of: block), var list = Optional(self[tab]),
              let i = list.firstIndex(of: block) else { return }
        let j = i + offset
        guard list.indices.contains(j) else { return }
        list.swapAt(i, j)
        set(list, for: tab)
    }

    private mutating func set(_ list: [PopoverBlock], for tab: PopoverTab) {
        if tab == .overview { overview = list } else { projects = list }
    }
}

extension PopoverLayout: Codable {
    private enum CodingKeys: String, CodingKey { case overview, projects, visibleProjectRows }

    /// Unknown block names (from a newer version) are dropped instead of failing the whole layout.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func blocks(_ key: CodingKeys) throws -> [PopoverBlock] {
            try (c.decodeIfPresent([String].self, forKey: key) ?? []).compactMap(PopoverBlock.init)
        }
        self.init(overview: try blocks(.overview), projects: try blocks(.projects),
                  visibleProjectRows: try c.decodeIfPresent(Int.self, forKey: .visibleProjectRows) ?? Self.defaultProjectRows)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(overview.map(\.rawValue), forKey: .overview)
        try c.encode(projects.map(\.rawValue), forKey: .projects)
        try c.encode(visibleProjectRows, forKey: .visibleProjectRows)
    }
}
