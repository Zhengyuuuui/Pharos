import Foundation
import PharosCore

func testBackup() {
    let fav = Favorite(name: "web", directory: "/Users/me/web", command: "pnpm run dev", commandSource: .detected,
                       lastPorts: [3000], addedAt: Date(timeIntervalSince1970: 1_700_000_000))
    let preset = ChromePreset(name: "edge", config: ChromeConfig(browser: .edge, userDataDir: "/Users/me/e", debugPort: 9500))
    let backup = Backup(favorites: [fav], browserPresets: [preset], exportedAt: Date(timeIntervalSince1970: 1_700_000_000))

    let data = try? backup.encoded()
    let back = data.flatMap { try? Backup.decode($0) }
    expectEq(back?.favorites, [fav], "favorites round-trip")
    expectEq(back?.browserPresets, [preset], "presets round-trip incl. browser")

    var threw: Backup.ReadError?
    do { _ = try Backup.decode(Data(#"{"hello":1}"#.utf8)) } catch { threw = error as? Backup.ReadError }
    expectEq(threw, .notABackup, "random JSON rejected")
    let future = String(decoding: data ?? Data(), as: UTF8.self).replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 9")
    do { _ = try Backup.decode(Data(future.utf8)) } catch { threw = error as? Backup.ReadError }
    expectEq(threw, .newerVersion(9), "newer backup version rejected")

    let other = Favorite(name: "api", directory: "/Users/me/api", command: "make run", commandSource: .custom)
    let incoming = Backup(favorites: [fav, other], browserPresets: [preset])
    let m = incoming.merge(into: [fav], presets: [preset])
    expectEq(m.favorites.map(\.directory), ["/Users/me/api"], "only new folders added")
    expectEq(m.presets.count, 0, "same browser + profile skipped")
    expectEq(m.skipped, 2, "skipped count")
    expect(m.favorites.first?.id != other.id, "imported entries get fresh ids")

    var custom = PopoverLayout.standard
    custom.insert(.favorites, into: .overview, before: .memory)
    let withLayout = try? Backup(favorites: [], browserPresets: [], popoverLayout: custom).encoded()
    expectEq(withLayout.flatMap { try? Backup.decode($0) }?.popoverLayout, custom, "popover layout round-trips")
    let old = String(decoding: data ?? Data(), as: UTF8.self)
    expectEq((try? Backup.decode(Data(old.utf8)))?.popoverLayout, nil, "backups without a layout still import")
}
