import SwiftUI
import PharosCore

/// Dedicated page for Battery & Charging Control, providing Tahoe-style charge limits (e.g. 80%)
/// and replicating the native macOS 15 "Plug" (Not Charging) state.
struct BatteryControlView: View {
    var showsTitle: Bool = true
    @ObservedObject private var battery = BatteryStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var armedUninstall = false

    var body: some View {
        PharosPage {
            headerView
        } content: {
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                managementBadge
                heroStatusCard
            }
            chargeLimitCard
            hardwareAndHealthGrid
            helperManagementCard
        }
        .onAppear {
            battery.refreshTelemetry()
            battery.refreshHelperState()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        PharosPageHeader(
            title: showsTitle ? l10n.batteryTitle : "",
            subtitle: showsTitle ? l10n.batteryChargeLimitDesc : nil
        ) {
            HStack(spacing: PharosSpacing.s) {
                if battery.busy {
                    ProgressView().controlSize(.small)
                }
                PharosActionButton(l10n.refreshNow, systemImage: "arrow.clockwise", role: .standard) {
                    battery.refreshTelemetry()
                    battery.refreshHelperState()
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - Takeover Badge

    /// Driven solely by the daemon's reply, so "active" means the helper confirmed it.
    private var managementBadge: some View {
        let managing = battery.isPharosManaging
        let color: Color = managing ? .green : .secondary
        let title: String
        if managing {
            title = l10n.batteryPharosActive
        } else if battery.helper == .ready {
            title = l10n.batteryMacOSManaged
        } else {
            title = "\(l10n.batteryMacOSManaged) · \(l10n.batteryHelperOffline)"
        }
        return HStack(spacing: 6) {
            Image(systemName: managing ? "circle.fill" : "circle")
                .font(.system(size: 8, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            if let limit = battery.activeLimit {
                Text(l10n.batteryActiveLimitBadge(limit))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(color.opacity(0.15)))
            } else if battery.helper == .ready, battery.mode == .full {
                Text(l10n.batteryFullOverrideBadge)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(color.opacity(0.15)))
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.10)))
        .overlay(Capsule().stroke(color.opacity(0.25)))
        .animation(.easeInOut(duration: 0.2), value: managing)
    }

    // MARK: - Hero Status Card (Native "小插头" State)

    private var heroStatusCard: some View {
        let r = battery.reading
        let isHolding = battery.isHolding || (!r.isCharging && r.powerSource == .acPower && r.currentPercent < 100)
        let isFull = r.isCharged || r.currentPercent >= 100
        let isPlugged = (r.powerSource == .acPower)
        let limit = battery.activeLimit ?? battery.targetLimit

        return PharosCard {
            HStack(spacing: PharosSpacing.xl) {
                // Visual Battery Indicator
                ZStack {
                    Circle()
                        .stroke(PharosColor.fill, lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(r.currentPercent) / 100.0)
                        .stroke(
                            isHolding ? Color.teal : (r.isCharging ? PharosColor.success : PharosColor.accent),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 80, height: 80)
                        .animation(.easeInOut(duration: 0.5), value: r.currentPercent)

                    VStack(spacing: PharosSpacing.xxs) {
                        Text("\(r.currentPercent)%")
                            .font(PharosFont.metricValue)
                        if isHolding {
                            Image(systemName: "powerplug.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.teal)
                        } else if r.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(PharosColor.success)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: PharosSpacing.s) {
                    HStack(spacing: PharosSpacing.s) {
                        if isHolding {
                            if r.currentPercent > limit {
                                Label(l10n.batteryHoldingAboveLimit(r.currentPercent, limit: limit), systemImage: "powerplug.fill")
                                    .font(PharosFont.sectionTitle)
                                    .foregroundStyle(Color.teal)
                            } else {
                                Label(l10n.batteryHoldingAtLimit(limit), systemImage: "powerplug.fill")
                                    .font(PharosFont.sectionTitle)
                                    .foregroundStyle(Color.teal)
                            }
                        } else if r.isCharging {
                            Label(l10n.batteryChargingTo(battery.activeLimit ?? 100), systemImage: "bolt.fill")
                                .font(PharosFont.sectionTitle)
                                .foregroundStyle(PharosColor.success)
                        } else if isFull && isPlugged {
                            Label(l10n.batteryFullyCharged, systemImage: "checkmark.circle.fill")
                                .font(PharosFont.sectionTitle)
                                .foregroundStyle(PharosColor.success)
                        } else {
                            Label(l10n.batteryDischarging, systemImage: "battery.75")
                                .font(PharosFont.sectionTitle)
                                .foregroundStyle(PharosColor.textPrimary)
                        }

                        Spacer()

                        // Quick status pill
                        if isHolding {
                            Text(l10n.batteryNotChargingPlug)
                                .font(PharosFont.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.teal.opacity(0.15)))
                                .foregroundStyle(Color.teal)
                        }
                    }

                    Text(isHolding
                         ? (r.currentPercent > limit ? l10n.batteryAboveLimitNote : l10n.batteryHoldingSubtitle)
                         : (r.adapterName ?? l10n.batteryAdapter))
                        .font(PharosFont.body)
                        .foregroundStyle(PharosColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    powerFlowEvidence(r)

                    HStack(spacing: PharosSpacing.l) {
                        if let watts = r.adapterWatts, watts > 0 {
                            Label("\(watts)W", systemImage: "bolt.badge.automatic")
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                        if r.watts > 0.05 {
                            Label(String(format: "%.1fW", r.watts), systemImage: "gauge.with.needle")
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                        Label(String(format: "%.1f°C", r.temperatureCelsius), systemImage: "thermometer.medium")
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                    }
                }
            }
        }
    }

    /// Measured AppleSmartBattery `Amperage` plus IOPS source — the proof that charging
    /// really stopped, rather than inferring it from the percentage.
    private func powerFlowEvidence(_ r: BatteryReading) -> some View {
        let flow = battery.powerFlow
        let (text, icon, color): (String, String, Color) = {
            switch flow {
            case .passthrough: return (l10n.batteryFlowPassthrough, "powerplug.fill", .teal)
            case .charging: return (l10n.batteryFlowCharging, "bolt.fill", .green)
            case .supplementing: return (l10n.batteryFlowSupplementing, "exclamationmark.triangle.fill", .orange)
            case .onBattery: return (l10n.batteryFlowOnBattery, "battery.75", .secondary)
            }
        }()
        return HStack(spacing: 6) {
            Image(systemName: "waveform.path.ecg")
            Text(l10n.batteryCellCurrent(r.amperage))
                .monospacedDigit()
            Text("·")
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.08)))
    }

    // MARK: - Charge Limit Control Card

    private var chargeLimitCard: some View {
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack {
                    Label(l10n.batteryChargeLimit, systemImage: "slider.horizontal.3")
                        .font(PharosFont.rowLabel)
                    Spacer()
                    Text("\(battery.targetLimit)%")
                        .font(PharosFont.metricValue)
                        .foregroundStyle(PharosColor.accent)
                }

                // Limit Slider
                VStack(spacing: PharosSpacing.xs) {
                    Slider(
                        value: Binding(
                            get: { Double(battery.targetLimit) },
                            set: { battery.targetLimit = Int($0) }
                        ),
                        in: 50...100,
                        step: 1
                    )
                    .disabled(battery.helper != .ready || battery.busy)

                    HStack {
                        Text("50%").font(PharosFont.caption).foregroundStyle(PharosColor.textTertiary)
                        Spacer()
                        Text("80% (Tahoe)").font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                        Spacer()
                        Text("100%").font(PharosFont.caption).foregroundStyle(PharosColor.textTertiary)
                    }
                }

                // Quick preset pills
                HStack(spacing: PharosSpacing.s) {
                    presetButton(80, label: l10n.batteryPresetRecommended)
                    presetButton(85, label: "85%")
                    presetButton(90, label: "90%")
                    presetButton(95, label: "95%")
                    presetButton(100, label: "100%")
                }

                PharosListDivider()

                // Action buttons
                HStack(spacing: PharosSpacing.m) {
                    Button {
                        battery.chargeToFullNow()
                    } label: {
                        Label(l10n.batteryChargeToFullNow, systemImage: "bolt.fill")
                    }
                    .buttonStyle(.pharos)
                    .controlSize(.small)
                    .disabled(battery.helper != .ready || battery.busy || battery.mode == .full)

                    Button {
                        battery.resumeLimit()
                    } label: {
                        Label(l10n.batteryResumeLimit, systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.pharos)
                    .controlSize(.small)
                    .disabled(battery.helper != .ready || battery.busy || battery.mode == .limit(maxPercent: battery.targetLimit))

                    Button {
                        battery.setSystemMode()
                    } label: {
                        Label(l10n.batterySystemManaged, systemImage: "apple.logo")
                    }
                    .buttonStyle(.pharos)
                    .controlSize(.small)
                    .disabled(battery.helper != .ready || battery.busy || battery.mode == .system)

                    Spacer()
                }

                // Safe design explanation
                PharosBanner(kind: .success, text: l10n.batterySafeLimitTip)

                // Persistent Guard toggle (Sleep & Lid-close protection)
                PharosListDivider()
                Toggle(isOn: $battery.persistentGuard) {
                    VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                        HStack(spacing: PharosSpacing.xs + 2) {
                            Text(l10n.batteryPersistentGuard).font(PharosFont.rowLabel)
                            PharosTag(text: l10n.recommendedTag, tint: PharosColor.accent)
                        }
                        Text(l10n.batteryPersistentGuardDesc).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(battery.helper != .ready)

                // MagSafe LED toggle
                if battery.capabilities.hasACLC {
                    PharosListDivider()
                    Toggle(isOn: $battery.syncMagSafe) {
                        VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                            Text(l10n.batterySyncMagSafe).font(PharosFont.rowLabel)
                            Text(l10n.batterySyncMagSafeDesc).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
        }
    }

    /// Highlight follows the limit the daemon is actually enforcing, not the slider value.
    @ViewBuilder
    private func presetButton(_ percent: Int, label: String) -> some View {
        let active = battery.activeLimit == percent
        Button {
            battery.selectLimit(percent)
        } label: {
            Text(label)
                .font(active ? PharosFont.rowLabel : PharosFont.body)
        }
        .buttonStyle(active ? .pharosPrimary : .pharos)
        .controlSize(.small)
        .disabled(battery.helper != .ready || battery.busy)
    }

    // MARK: - Hardware Telemetry & Health Grid

    private var hardwareAndHealthGrid: some View {
        let r = battery.reading
        return PharosSection(title: l10n.batteryHealth, systemImage: "heart.text.square") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: PharosSpacing.m) {
                metricCell(title: l10n.batteryHealth, value: "\(r.healthPercent)%", caption: r.health.rawValue.capitalized)
                metricCell(title: l10n.batteryCycleCount, value: "\(r.cycleCount)", caption: l10n.batteryDesignCapacityCaption(r.designCapacity))
                metricCell(title: l10n.batteryMaxCapacity, value: "\(r.maxCapacity) mAh", caption: l10n.batteryRemainingCaption(r.remainingCapacity))
                metricCell(title: l10n.batteryVoltage, value: String(format: "%.2f V", r.voltage), caption: l10n.batteryCurrentCaption(r.amperage))
                metricCell(title: l10n.batteryTemperature, value: String(format: "%.1f °C", r.temperatureCelsius), caption: l10n.batteryBMSSensor)
                metricCell(
                    title: l10n.batteryAdapter,
                    value: r.adapterWatts != nil ? "\(r.adapterWatts!)W" : (r.powerSource == .acPower ? "AC" : "DC"),
                    caption: r.adapterName ?? "Apple Charger"
                )
            }
        }
    }

    private func metricCell(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: PharosSpacing.xs) {
            Text(title).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
            Text(value).font(PharosFont.metricValue)
            Text(caption).font(PharosFont.captionDigits).foregroundStyle(PharosColor.textTertiary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PharosSpacing.s)
        .background(RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous).fill(PharosColor.fill))
    }

    // MARK: - Helper Management Card

    private var helperManagementCard: some View {
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack {
                    Label(l10n.batteryHelperInstalled, systemImage: "shield.lefthalf.filled")
                        .font(PharosFont.rowLabel)
                    Spacer()
                    statusBadge
                }

                if let message = battery.errorMessage {
                    PharosBanner(kind: .error, text: message) {
                        IconButton(systemImage: "xmark", help: l10n.dismiss) { battery.errorMessage = nil }
                    }
                }

                Text(l10n.batteryHelperDesc)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    switch battery.helper {
                    case .notInstalled:
                        Button(l10n.batteryInstallHelper) {
                            battery.install()
                        }
                        .buttonStyle(.pharosPrimary)
                        .controlSize(.small)
                        .disabled(battery.busy || battery.unsupported)

                    case .notResponding:
                        Button(l10n.refreshNow) {
                            battery.refreshHelperState()
                        }
                        .buttonStyle(.pharos)
                        .controlSize(.small)
                        .disabled(battery.busy)

                    case .ready:
                        if armedUninstall {
                            HStack(spacing: PharosSpacing.s) {
                                Button(l10n.confirm) {
                                    armedUninstall = false
                                    battery.uninstall()
                                }
                                .buttonStyle(.pharosDestructive)
                                .controlSize(.small)

                                Button(l10n.cancel) {
                                    armedUninstall = false
                                }
                                .buttonStyle(.pharos)
                                .controlSize(.small)
                            }
                        } else {
                            HStack(spacing: PharosSpacing.s) {
                                Button(l10n.batteryUninstallHelper) {
                                    armedUninstall = true
                                }
                                .buttonStyle(.pharos)
                                .controlSize(.small)
                                .disabled(battery.busy)

                                Button(l10n.reinstallHelper) {
                                    battery.install()
                                }
                                .buttonStyle(.pharos)
                                .controlSize(.small)
                                .disabled(battery.busy)
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch battery.helper {
        case .notInstalled:
            PharosTag(text: l10n.batteryStatusNotInstalled, tint: PharosColor.textSecondary)
        case .notResponding:
            PharosTag(text: l10n.batteryStatusNotResponding, systemImage: "exclamationmark.triangle.fill", tint: PharosColor.warning)
        case .ready:
            PharosTag(text: l10n.batteryStatusRunning, systemImage: "checkmark.circle.fill", tint: PharosColor.success)
        }
    }
}
