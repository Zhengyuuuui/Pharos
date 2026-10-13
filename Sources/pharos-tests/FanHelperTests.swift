import Foundation
import PharosCore

func testFanHelperInstall() {
    let plist = FanHelperInstall.plist(uid: 501)
    expect(plist.contains("<string>\(FanHelperInstall.binaryPath)</string>"), "plist runs the installed helper")
    expect(plist.contains("<string>501</string>"), "plist passes the owner uid")
    expect(plist.contains("<key>KeepAlive</key><true/>"), "launchd restarts the helper")
    let data = Data(plist.utf8)
    let parsed = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    expectEq(parsed?["Label"] as? String, FanHelperInstall.label, "plist is valid XML")

    let script = FanHelperInstall.installScript(helperSource: "/Applications/Pha ros.app/Contents/MacOS/pharos-fand",
                                                plistSource: "/tmp/x'y.plist")
    expect(script.contains("'/Applications/Pha ros.app/Contents/MacOS/pharos-fand'"), "source path with space quoted")
    expect(script.contains("'/tmp/x'\\''y.plist'"), "single quote escaped")
    expect(script.hasPrefix("set -e"), "install stops on first error")
    expect(FanHelperInstall.uninstallScript.contains("bootout system/\(FanHelperInstall.label)"),
           "uninstall stops the helper first (it hands fans back on SIGTERM)")
}
