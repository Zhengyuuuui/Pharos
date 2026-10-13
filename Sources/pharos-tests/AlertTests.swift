import Foundation
import PharosCore

func testAlerts() {
    let normal = SystemMemoryStats(total: 100, appMemory: 40, wired: 10, compressed: 0, cachedFiles: 0, pressure: .normal)
    let high = SystemMemoryStats(total: 100, appMemory: 80, wired: 15, compressed: 0, cachedFiles: 0, pressure: .warning)
    let disk = { (avail: UInt64) in DiskVolume(path: "/", name: "Macintosh HD", kind: .startup, total: 100, available: avail) }
    let dmg = DiskVolume(path: "/Volumes/X", name: "X", kind: .diskImage, total: 100, available: 1, isReadOnly: true)
    let fav = [(id: "a", name: "web", ports: [UInt16(3000)])]

    var s = AlertState()
    expectEq(s.update(memory: normal, volumes: [disk(50), dmg], favorites: fav, runningFavoriteIDs: [],
                      stoppedByUser: []), [], "first scan: baseline only; full disk image ignored")
    expectEq(s.update(memory: high, volumes: [disk(50)], favorites: fav, runningFavoriteIDs: ["a"], stoppedByUser: []),
             [.memoryPressure(used: 95, total: 100)], "pressure rises → one alert")
    expectEq(s.update(memory: high, volumes: [disk(50)], favorites: fav, runningFavoriteIDs: ["a"], stoppedByUser: []),
             [], "still high → no repeat")
    expectEq(s.update(memory: normal, volumes: [disk(4)], favorites: fav, runningFavoriteIDs: [], stoppedByUser: []),
             [.diskAlmostFull(name: "Macintosh HD", path: "/", available: 4),
              .favoriteStopped(id: "a", name: "web", ports: [3000])],
             "disk crosses 95 % and a running favorite disappears")
    expectEq(s.update(memory: normal, volumes: [disk(6)], favorites: fav, runningFavoriteIDs: [], stoppedByUser: []),
             [], "94 % is inside the hysteresis band → no re-alert")
    _ = s.update(memory: normal, volumes: [disk(10)], favorites: fav, runningFavoriteIDs: ["a"], stoppedByUser: [])
    expectEq(s.update(memory: normal, volumes: [disk(3)], favorites: fav, runningFavoriteIDs: [], stoppedByUser: ["a"]),
             [.diskAlmostFull(name: "Macintosh HD", path: "/", available: 3)],
             "re-armed after clearing; favorite stopped from Pharos isn't 'unexpected'")
}
