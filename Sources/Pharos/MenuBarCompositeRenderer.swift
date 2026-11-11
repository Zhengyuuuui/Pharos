import AppKit
import Foundation
import PharosCore

/// High-fidelity Retina status bar composite renderer.
/// Renders a unified single-image canvas (height 22pt) matching macOS status bar guidelines,
/// ensuring 100% pixel-perfect consistency between the actual menu bar and preview capsules.
@MainActor
public enum MenuBarCompositeRenderer {
    public struct MetricItem {
        public let metric: MenuBarMetric
        public let sfSymbol: String
        public let upperLabel: String
        public let value: String

        public init(metric: MenuBarMetric, sfSymbol: String, upperLabel: String, value: String) {
            self.metric = metric
            self.sfSymbol = sfSymbol
            self.upperLabel = upperLabel
            self.value = value
        }
    }

    private struct MeasuredColumn {
        let item: MetricItem
        let totalWidth: CGFloat
        let symWidth: CGFloat
        let valueWidth: CGFloat
        let upperWidth: CGFloat
    }

    /// Renders a unified Retina menu bar image (height 22pt).
    public static func render(
        ringFraction: Double,
        ringPressure: MemoryPressure,
        ringHighIsBad: Bool,
        metrics: [MetricItem],
        displayStyle: MenuBarDisplayStyle,
        separator: MenuBarSeparator
    ) -> NSImage {
        let ringSize: CGFloat = 18.0
        let barHeight: CGFloat = 22.0

        let ringImage = DynamicMenuBarIcon.image(fraction: ringFraction, pressure: ringPressure, highIsBad: ringHighIsBad)

        if metrics.isEmpty {
            let img = NSImage(size: NSSize(width: ringSize, height: barHeight), flipped: false) { rect in
                ringImage.draw(in: NSRect(x: 0, y: (barHeight - ringSize) / 2, width: ringSize, height: ringSize))
                return true
            }
            img.isTemplate = false
            return img
        }

        let ringToContentGap: CGFloat = 5.0
        var contentWidth: CGFloat = 0

        var columns: [MeasuredColumn] = []

        let symbolPointSize: CGFloat = 9.5
        let symbolWidth: CGFloat = 12.0
        let symbolGap: CGFloat = 3.5

        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: NSColor.labelColor
        ]

        let upperFont = NSFont.systemFont(ofSize: 6.5, weight: .bold)
        let upperAttrs: [NSAttributedString.Key: Any] = [
            .font: upperFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let stackedValueFont = NSFont.monospacedDigitSystemFont(ofSize: 10.0, weight: .medium)
        let stackedValueAttrs: [NSAttributedString.Key: Any] = [
            .font: stackedValueFont,
            .foregroundColor: NSColor.labelColor
        ]

        let sepFont = NSFont.systemFont(ofSize: 10.0, weight: .regular)
        let sepAttrs: [NSAttributedString.Key: Any] = [
            .font: sepFont,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let sepWidth: CGFloat = NSString(string: separator.symbol).size(withAttributes: sepAttrs).width

        for (idx, item) in metrics.enumerated() {
            if idx > 0 {
                switch displayStyle {
                case .iconAndValue:
                    contentWidth += 7.0
                case .stacked:
                    contentWidth += 6.5
                case .valueOnly:
                    contentWidth += sepWidth
                }
            }

            switch displayStyle {
            case .iconAndValue:
                let valW = ceil(NSString(string: item.value).size(withAttributes: valueAttrs).width)
                let colW = symbolWidth + symbolGap + valW
                columns.append(MeasuredColumn(item: item, totalWidth: colW, symWidth: symbolWidth, valueWidth: valW, upperWidth: 0))
                contentWidth += colW

            case .stacked:
                let upW = ceil(NSString(string: item.upperLabel).size(withAttributes: upperAttrs).width)
                let valW = ceil(NSString(string: item.value).size(withAttributes: stackedValueAttrs).width)
                let colW = max(upW, valW)
                columns.append(MeasuredColumn(item: item, totalWidth: colW, symWidth: 0, valueWidth: valW, upperWidth: upW))
                contentWidth += colW

            case .valueOnly:
                let valW = ceil(NSString(string: item.value).size(withAttributes: valueAttrs).width)
                columns.append(MeasuredColumn(item: item, totalWidth: valW, symWidth: 0, valueWidth: valW, upperWidth: 0))
                contentWidth += valW
            }
        }

        let totalWidth = ceil(ringSize + ringToContentGap + contentWidth + 1.0)

        let composite = NSImage(size: NSSize(width: totalWidth, height: barHeight), flipped: false) { rect in
            // 1. Draw Ring on left
            ringImage.draw(in: NSRect(x: 0, y: (barHeight - ringSize) / 2, width: ringSize, height: ringSize))

            // 2. Draw Metrics
            var curX: CGFloat = ringSize + ringToContentGap

            for (idx, col) in columns.enumerated() {
                if idx > 0 {
                    switch displayStyle {
                    case .iconAndValue:
                        curX += 7.0
                    case .stacked:
                        curX += 6.5
                    case .valueOnly:
                        let sepY = (barHeight - 12.0) / 2
                        NSString(string: separator.symbol).draw(
                            in: NSRect(x: curX, y: sepY, width: sepWidth, height: 12.0),
                            withAttributes: sepAttrs
                        )
                        curX += sepWidth
                    }
                }

                switch displayStyle {
                case .iconAndValue:
                    // SF Symbol
                    if let sym = NSImage(systemSymbolName: col.item.sfSymbol, accessibilityDescription: nil) {
                        let conf = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .medium)
                            .applying(NSImage.SymbolConfiguration(hierarchicalColor: NSColor.labelColor.withAlphaComponent(0.82)))
                        let configuredSym = sym.withSymbolConfiguration(conf) ?? sym
                        let symRect = NSRect(x: curX, y: (barHeight - 12.0) / 2, width: 12.0, height: 12.0)
                        configuredSym.draw(in: symRect)
                    }

                    // Value
                    let valX = curX + symbolWidth + symbolGap
                    let valY = (barHeight - 14.0) / 2
                    NSString(string: col.item.value).draw(
                        in: NSRect(x: valX, y: valY, width: col.valueWidth, height: 14.0),
                        withAttributes: valueAttrs
                    )
                    curX += col.totalWidth

                case .stacked:
                    let colX = curX
                    // Upper short label (e.g. PORT / TEMP / MEM)
                    let upX = colX + (col.totalWidth - col.upperWidth) / 2
                    NSString(string: col.item.upperLabel).draw(
                        in: NSRect(x: upX, y: 13.0, width: col.upperWidth, height: 8.5),
                        withAttributes: upperAttrs
                    )

                    // Lower compact value (e.g. 22 / 70°C / 60%)
                    let valX = colX + (col.totalWidth - col.valueWidth) / 2
                    NSString(string: col.item.value).draw(
                        in: NSRect(x: valX, y: 1.0, width: col.valueWidth, height: 12.5),
                        withAttributes: stackedValueAttrs
                    )
                    curX += col.totalWidth

                case .valueOnly:
                    let valY = (barHeight - 14.0) / 2
                    NSString(string: col.item.value).draw(
                        in: NSRect(x: curX, y: valY, width: col.valueWidth, height: 14.0),
                        withAttributes: valueAttrs
                    )
                    curX += col.totalWidth
                }
            }

            return true
        }

        composite.isTemplate = false
        return composite
    }

    /// Convenience helper that queries live store and settings to produce the composite NSImage.
    @MainActor
    static func currentImage(store: ProjectStore, settings: MenuBarSettings, battery: BatteryStore) -> NSImage {
        let ring = ringStatus(store: store, settings: settings, battery: battery)
        let metrics: [MetricItem] = settings.enabledMetrics.compactMap { m in
            guard let val = m.value(store: store, style: settings.displayStyle) else { return nil }
            return MetricItem(metric: m, sfSymbol: m.sfSymbol, upperLabel: m.upperLabel, value: val)
        }
        return render(
            ringFraction: ring.fraction,
            ringPressure: ring.pressure,
            ringHighIsBad: ring.highIsBad,
            metrics: metrics,
            displayStyle: settings.displayStyle,
            separator: settings.separatorStyle
        )
    }

    /// Calculates the ring fraction and memory pressure status for the currently selected ring metric.
    @MainActor
    static func ringStatus(
        store: ProjectStore,
        settings: MenuBarSettings,
        battery: BatteryStore
    ) -> (fraction: Double, pressure: MemoryPressure, highIsBad: Bool) {
        switch settings.ringMetric {
        case .temperature:
            let t = store.thermals?.peakChipTemperature ?? 40.0
            let clamped = max(35.0, min(100.0, t))
            let frac = (clamped - 35.0) / (100.0 - 35.0)
            let press: MemoryPressure = (t >= 95.0) ? .critical : ((t >= 85.0) ? .warning : .normal)
            return (frac, press, true)
        case .disk:
            let disk = store.volumes.first { $0.kind == .startup }
            let frac = disk?.usedFraction ?? 0
            let press: MemoryPressure = frac >= 0.95 ? .critical : (frac >= 0.85 ? .warning : .normal)
            return (frac, press, true)
        case .memory:
            return (store.system?.usedFraction ?? 0, store.system?.pressure ?? .normal, true)
        case .projects:
            let cap = max(1, settings.maxProjects)
            let frac = Double(store.projects.count) / Double(cap)
            let press: MemoryPressure = frac >= 1.0 ? .critical : (frac >= 0.85 ? .warning : .normal)
            return (min(1.0, frac), press, true)
        case .ports:
            let cap = max(1, settings.maxPorts)
            let frac = Double(store.totalPorts) / Double(cap)
            let press: MemoryPressure = frac >= 1.0 ? .critical : (frac >= 0.85 ? .warning : .normal)
            return (min(1.0, frac), press, true)
        case .battery:
            let r = battery.reading
            guard r.hasBattery else {
                return (store.system?.usedFraction ?? 0, store.system?.pressure ?? .normal, true)
            }
            let press: MemoryPressure = switch BatteryMenuBarMetric.level(percent: r.currentPercent, onAC: r.powerSource == .acPower) {
            case .critical: .critical
            case .warning: .warning
            case .normal: .normal
            }
            return (BatteryMenuBarMetric.fraction(percent: r.currentPercent), press, false)
        }
    }
}
