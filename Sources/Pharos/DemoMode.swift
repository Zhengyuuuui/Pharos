import Foundation
import AppKit

/// Global demo mode controller.
/// When running inside `Pharos Demo.app` or with `--demo` / `--capture-screenshots`,
/// all modules lock onto realistic developer mock data and cease scanning real disks or PIDs,
/// ensuring zero leaks of private unreleased projects while providing a complete interactive stage.
public enum DemoMode {
    public static var isEnabled: Bool {
        if CommandLine.arguments.contains("--demo") || CommandLine.arguments.contains("--capture-screenshots") {
            return true
        }
        let bundleName = Bundle.main.bundleURL.lastPathComponent
        return bundleName.localizedCaseInsensitiveContains("Demo")
    }
}
