import Foundation
import PharosCore

func testPopoverLayout() {
    var l = PopoverLayout.standard
    expectEq(l.unused, [.favorites], "standard layout leaves favorites in the library")
    expectEq(l.visibleTabs, [.overview, .projects], "both tabs visible")

    l.insert(.favorites, into: .projects, before: .browsers)
    expectEq(l.projects, [.projects, .favorites, .browsers], "dragged in before a block")
    expectEq(l.unused, [], "library empty")

    l.insert(.memory, into: .projects)
    expectEq(l.overview, [.disk, .thermals, .devProjects, .topApps], "moved out of overview")
    expectEq(l.projects.last, .memory, "appended to projects")

    l.insert(.disk, into: .overview, before: .topApps)
    expectEq(l.overview, [.thermals, .devProjects, .disk, .topApps], "reorder within a tab")
    l.insert(.disk, into: .overview, before: .disk)
    expectEq(l.overview, [.thermals, .devProjects, .disk, .topApps], "drop onto itself is a no-op")

    l.move(.disk, by: -1)
    expectEq(l.overview, [.thermals, .disk, .devProjects, .topApps], "move up")
    l.move(.thermals, by: -1)
    expectEq(l.overview.first, .thermals, "can't move past the top")

    l.remove(.topApps)
    expectEq(l.unused, [.topApps], "removed block returns to the library")

    for b in l.overview { l.remove(b) }
    expectEq(l.visibleTabs, [.projects], "empty tab is hidden")

    let dup = PopoverLayout(overview: [.memory, .memory, .disk], projects: [.disk, .projects])
    expectEq(dup.overview, [.memory, .disk], "duplicates dropped")
    expectEq(dup.projects, [.projects], "a block lives in one tab only")

    let json = Data(#"{"overview":["memory","futureWidget","disk"],"projects":["projects"]}"#.utf8)
    let decoded = try? JSONDecoder().decode(PopoverLayout.self, from: json)
    expectEq(decoded?.overview, [.memory, .disk], "unknown blocks from a newer version are skipped")
    let round = (try? JSONEncoder().encode(PopoverLayout.standard)).flatMap { try? JSONDecoder().decode(PopoverLayout.self, from: $0) }
    expectEq(round, .standard, "layout round-trips")

    expectEq(PopoverLayout.standard.visibleProjectRows, 5, "default: 5 project rows before scrolling")
    var rows = PopoverLayout.standard
    rows.visibleProjectRows = 8
    let back = (try? JSONEncoder().encode(rows)).flatMap { try? JSONDecoder().decode(PopoverLayout.self, from: $0) }
    expectEq(back?.visibleProjectRows, 8, "row limit round-trips")
    rows.visibleProjectRows = -3
    expectEq(rows.visibleProjectRows, 0, "negative → 0 (show all)")
    rows.visibleProjectRows = 1
    expectEq(rows.visibleProjectRows, 3, "minimum is 3 rows")
    rows.visibleProjectRows = 500
    expectEq(rows.visibleProjectRows, 50, "capped at 50")
    expectEq(decoded?.visibleProjectRows, 5, "layouts saved before the setting default to 5")
}
