import SwiftUI
import PharosCore

public enum BatteryAndThermalTab: String, CaseIterable, Identifiable, Hashable {
    case battery
    case thermals

    public var id: String { rawValue }
}

/// Unified page bringing Battery Charging Management and Fans & Thermals together.
struct BatteryAndThermalView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var router = WindowRouter.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var selectedTab: BatteryAndThermalTab

    init() {
        _selectedTab = State(initialValue: BatteryStore.shared.reading.hasBattery ? .battery : .thermals)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Unified top toolbar with Segmented Picker
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                    Text(l10n.batteryAndThermalsTitle)
                        .font(PharosFont.pageTitle)
                    Text(l10n.batteryAndThermalsDesc)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                }
                Spacer()
                Picker("", selection: $selectedTab) {
                    Label(l10n.batteryTitle, systemImage: "battery.100.bolt")
                        .tag(BatteryAndThermalTab.battery)
                    Label(l10n.thermalTitle, systemImage: "fanblades")
                        .tag(BatteryAndThermalTab.thermals)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
            .padding(.horizontal, PharosSpacing.page)
            .padding(.top, PharosSpacing.l)
            .padding(.bottom, PharosSpacing.m)
            .background(Color.clear)

            PharosListDivider()

            // Selected Sub-View
            Group {
                switch selectedTab {
                case .battery:
                    BatteryControlView(showsTitle: false)
                case .thermals:
                    ThermalView(showsTitle: false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if let target = router.batteryThermalTab {
                selectedTab = target
                router.batteryThermalTab = nil
            }
        }
        .onChange(of: router.batteryThermalTab) { _, target in
            if let target {
                selectedTab = target
                router.batteryThermalTab = nil
            }
        }
    }
}
