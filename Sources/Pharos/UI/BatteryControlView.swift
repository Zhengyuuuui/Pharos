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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerView
                VStack(alignment: .leading, spacing: 8) {
                    managementBadge
                    heroStatusCard
                }
                chargeLimitCard
                hardwareAndHealthGrid
                helperManagementCard
            }
            .padding(20)
        }
        .onAppear {
            battery.refreshTelemetry()
            battery.refreshHelperState()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            if showsTitle {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.batteryTitle)
                        .font(.system(size: 20, weight: .bold))
                    Text(l10n.batteryChargeLimitDesc)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(l10n.batteryChargeLimitDesc)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if battery.busy {
                ProgressView().controlSize(.small)
            }
            Button {
                battery.refreshTelemetry()
                battery.refreshHelperState()
            } label: {
                Label(l10n.refreshNow, systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
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

        return HStack(spacing: 20) {
            // Visual Battery Indicator
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(r.currentPercent) / 100.0)
                    .stroke(
                        isHolding ? Color.teal : (r.isCharging ? Color.green : Color.accentColor),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                    .animation(.easeInOut(duration: 0.5), value: r.currentPercent)

                VStack(spacing: 2) {
                    Text("\(r.currentPercent)%")
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                    if isHolding {
                        Image(systemName: "powerplug.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.teal)
                    } else if r.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if isHolding {
                        if r.currentPercent > limit {
                            Label(l10n.batteryHoldingAboveLimit(r.currentPercent, limit: limit), systemImage: "powerplug.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.teal)
                        } else {
                            Label(l10n.batteryHoldingAtLimit(limit), systemImage: "powerplug.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.teal)
                        }
                    } else if r.isCharging {
                        Label(l10n.batteryChargingTo(battery.activeLimit ?? 100), systemImage: "bolt.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.green)
                    } else if isFull && isPlugged {
                        Label(l10n.batteryFullyCharged, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Label(l10n.batteryDischarging, systemImage: "battery.75")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    // Quick status pill
                    if isHolding {
                        Text(l10n.batteryNotChargingPlug)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.teal.opacity(0.15)))
                            .foregroundStyle(.teal)
                    }
                }

                Text(isHolding
                     ? (r.currentPercent > limit ? l10n.batteryAboveLimitNote : l10n.batteryHoldingSubtitle)
                     : (r.adapterName ?? l10n.batteryAdapter))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                powerFlowEvidence(r)

                HStack(spacing: 16) {
                    if let watts = r.adapterWatts, watts > 0 {
                        Label("\(watts)W", systemImage: "bolt.badge.automatic")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if r.watts > 0.05 {
                        Label(String(format: "%.1fW", r.watts), systemImage: "gauge.with.needle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Label(String(format: "%.1f°C", r.temperatureCelsius), systemImage: "thermometer.medium")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(l10n.batteryChargeLimit, systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(battery.targetLimit)%")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.accentColor)
            }

            // Limit Slider
            VStack(spacing: 6) {
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
                    Text("50%").font(.system(size: 10)).foregroundStyle(.tertiary)
                    Spacer()
                    Text("80% (Tahoe)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text("100%").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }

            // Quick preset pills
            HStack(spacing: 8) {
                presetButton(80, label: l10n.batteryPresetRecommended)
                presetButton(85, label: "85%")
                presetButton(90, label: "90%")
                presetButton(95, label: "95%")
                presetButton(100, label: "100%")
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    battery.chargeToFullNow()
                } label: {
                    Label(l10n.batteryChargeToFullNow, systemImage: "bolt.fill")
                }
                .controlSize(.small)
                .disabled(battery.helper != .ready || battery.busy || battery.mode == .full)

                Button {
                    battery.resumeLimit()
                } label: {
                    Label(l10n.batteryResumeLimit, systemImage: "arrow.counterclockwise")
                }
                .controlSize(.small)
                .disabled(battery.helper != .ready || battery.busy || battery.mode == .limit(maxPercent: battery.targetLimit))

                Button {
                    battery.setSystemMode()
                } label: {
                    Label(l10n.batterySystemManaged, systemImage: "apple.logo")
                }
                .controlSize(.small)
                .disabled(battery.helper != .ready || battery.busy || battery.mode == .system)

                Spacer()
            }

            // Safe design explanation
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                    .padding(.top, 1)
                Text(l10n.batterySafeLimitTip)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.12)))

            // Persistent Guard toggle (Sleep & Lid-close protection)
            Divider()
            Toggle(isOn: $battery.persistentGuard) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(l10n.batteryPersistentGuard).font(.system(size: 12, weight: .medium))
                        Text(l10n.recommendedTag)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            .foregroundStyle(Color.accentColor)
                    }
                    Text(l10n.batteryPersistentGuardDesc).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(battery.helper != .ready)

            // MagSafe LED toggle
            if battery.capabilities.hasACLC {
                Divider()
                Toggle(isOn: $battery.syncMagSafe) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.batterySyncMagSafe).font(.system(size: 12, weight: .medium))
                        Text(l10n.batterySyncMagSafeDesc).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
    }

    /// Highlight follows the limit the daemon is actually enforcing, not the slider value.
    @ViewBuilder
    private func presetButton(_ percent: Int, label: String) -> some View {
        let active = battery.activeLimit == percent
        let button = Button {
            battery.selectLimit(percent)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: active ? .bold : .regular))
        }
        .controlSize(.small)
        .disabled(battery.helper != .ready || battery.busy)
        if active {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    // MARK: - Hardware Telemetry & Health Grid

    private var hardwareAndHealthGrid: some View {
        let r = battery.reading
        return VStack(alignment: .leading, spacing: 12) {
            Label(l10n.batteryHealth, systemImage: "heart.text.square")
                .font(.system(size: 14, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
    }

    private func metricCell(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .bold).monospacedDigit())
            Text(caption).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
    }

    // MARK: - Helper Management Card

    private var helperManagementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(l10n.batteryHelperInstalled, systemImage: "shield.lefthalf.filled")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                statusBadge
            }

            if let message = battery.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(message).font(.system(size: 11)).textSelection(.enabled)
                    Spacer()
                    IconButton(systemImage: "xmark", help: l10n.dismiss) { battery.errorMessage = nil }
                }
            }

            Text(l10n.batteryHelperDesc)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                switch battery.helper {
                case .notInstalled:
                    Button(l10n.batteryInstallHelper) {
                        battery.install()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(battery.busy || battery.unsupported)

                case .notResponding:
                    Button(l10n.refreshNow) {
                        battery.refreshHelperState()
                    }
                    .controlSize(.small)
                    .disabled(battery.busy)

                case .ready:
                    if armedUninstall {
                        HStack(spacing: 8) {
                            Button(l10n.confirm) {
                                armedUninstall = false
                                battery.uninstall()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)

                            Button(l10n.cancel) {
                                armedUninstall = false
                            }
                            .controlSize(.small)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Button(l10n.batteryUninstallHelper) {
                                armedUninstall = true
                            }
                            .controlSize(.small)
                            .disabled(battery.busy)

                            Button(l10n.reinstallHelper) {
                                battery.install()
                            }
                            .controlSize(.small)
                            .disabled(battery.busy)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06)))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch battery.helper {
        case .notInstalled:
            Text(l10n.batteryStatusNotInstalled)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
                .foregroundStyle(.secondary)
        case .notResponding:
            Text(l10n.batteryStatusNotResponding)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
                .foregroundStyle(.orange)
        case .ready:
            Text(l10n.batteryStatusRunning)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green.opacity(0.15)))
                .foregroundStyle(.green)
        }
    }
}
