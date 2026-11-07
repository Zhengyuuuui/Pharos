import SwiftUI
import PharosCore

/// Real-time control center for Clash / Mihomo daemon.
/// Displays running client type, ports, traffic speeds, and available proxies.
struct ClashDashboardSection: View {
    @ObservedObject private var clash = ClashStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var showConfigSheet = false

    var body: some View {
        let snap = clash.snapshot

        PharosSection(title: l10n.clashControlHub, systemImage: "network") {
            HStack(spacing: 6) {
                Button {
                    Task { await clash.refreshNodes() }
                } label: {
                    Label(l10n.clashRefreshNodes, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.pharos)
                .controlSize(.small)
                .disabled(!snap.isRunning || clash.isOperating)

                Button {
                    showConfigSheet = true
                } label: {
                    Label(l10n.clashConfigCore, systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.pharos)
                .controlSize(.small)
            }
        } content: {
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                // 1. Compact Single-Line Status Bar
                HStack(alignment: .center, spacing: PharosSpacing.m) {
                    // Client Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(snap.isRunning ? PharosColor.accent.opacity(0.12) : PharosColor.fill)
                            .frame(width: 36, height: 36)
                        Image(systemName: snap.clientKind?.iconName ?? "network")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(snap.isRunning ? PharosColor.accent : PharosColor.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(clash.isManualMode ? clash.manualClientName : (snap.clientKind?.rawValue ?? (snap.isRunning ? "Mihomo Core" : l10n.clashControlHub)))
                                .font(PharosFont.rowLabel)
                                .fontWeight(.semibold)

                            // Status pill
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(snap.isRunning ? PharosColor.success : PharosColor.textTertiary)
                                    .frame(width: 6, height: 6)
                                Text(snap.isRunning ? l10n.clashClientRunning : l10n.clashClientStopped)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(snap.isRunning ? PharosColor.success : PharosColor.textSecondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(snap.isRunning ? PharosColor.success.opacity(0.12) : PharosColor.fill)
                            )

                            if clash.isManualMode {
                                Text(l10n.clashManualModeBadge)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(PharosColor.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(PharosColor.accent.opacity(0.12))
                                    )
                            }
                        }

                        if snap.isRunning {
                            HStack(spacing: 10) {
                                Label(l10n.clashNodesCount(clash.nodes.count), systemImage: "point.3.filled.connected.trianglepath.dotted")
                                    .font(PharosFont.caption)
                                    .foregroundStyle(PharosColor.textSecondary)

                                Text("•").foregroundStyle(PharosColor.textTertiary)

                                Label("\(l10n.clashMixedPort): \(snap.mixedPort)", systemImage: "arrow.left.arrow.right")
                                    .font(PharosFont.captionDigits)
                                    .foregroundStyle(PharosColor.textSecondary)

                                if snap.isTunEnabled {
                                    Text("•").foregroundStyle(PharosColor.textTertiary)
                                    Label(l10n.clashTunEnabled, systemImage: "shield.checkered")
                                        .font(PharosFont.caption)
                                        .foregroundStyle(PharosColor.accent)
                                }
                            }
                        } else {
                            Text(l10n.clashClientStoppedHint)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textTertiary)
                        }
                    }

                    Spacer()

                    // Real-time Traffic Speeds (clean single arrow)
                    if snap.isRunning {
                        HStack(spacing: 12) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(PharosColor.textSecondary)
                                Text("\(ByteFormat.short(snap.uploadBytesPerSec))/s")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(PharosColor.textSecondary)
                            }
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(PharosColor.accent)
                                Text("\(ByteFormat.short(snap.downloadBytesPerSec))/s")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(PharosColor.accent)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(PharosColor.fill)
                        )
                    }
                }
                .padding(.horizontal, PharosSpacing.m)
                .padding(.vertical, PharosSpacing.s)
                .background(
                    RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                        .fill(PharosColor.surfaceSecondary)
                )

                // Banners
                if let note = clash.notificationBanner {
                    PharosBanner(kind: .info, text: note) {
                        PharosCloseButton(help: l10n.dismiss) { clash.notificationBanner = nil }
                    }
                    .task(id: note) {
                        try? await Task.sleep(for: .seconds(3))
                        clash.notificationBanner = nil
                    }
                }
                if let err = clash.errorMessage {
                    PharosBanner(kind: .error, text: err) {
                        PharosCloseButton(help: l10n.dismiss) { clash.errorMessage = nil }
                    }
                }
            }
        }
        .sheet(isPresented: $showConfigSheet) {
            ClashConfigSheet(isPresented: $showConfigSheet)
        }
        .onAppear {
            clash.viewAppeared()
        }
        .onDisappear {
            clash.viewDisappeared()
        }
    }
}

// MARK: - Core Configuration Modal Sheet

private struct ClashConfigSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var clash = ClashStore.shared
    @ObservedObject private var l10n = L10n.shared

    @State private var isManual: Bool = false
    @State private var endpoint: String = ""
    @State private var secret: String = ""
    @State private var isSecretVisible: Bool = false
    @State private var mixedPortStr: String = ""
    @State private var clientName: String = ""
    @State private var configPath: String = ""

    @State private var isTesting = false
    @State private var testResult: (success: Bool, message: String)? = nil

    var body: some View {
        VStack(spacing: PharosSpacing.m) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PharosColor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.clashConfigTitle)
                        .font(PharosFont.sectionTitle)
                    Text(l10n.clashConfigSubtitle)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(PharosColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            // Segmented Picker
            Picker("", selection: $isManual) {
                Text(l10n.clashModeAuto).tag(false)
                Text(l10n.clashModeManual).tag(true)
            }
            .pickerStyle(.segmented)

            if !isManual {
                // Auto Detect View
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundStyle(PharosColor.accent)
                            .padding(.top, 2)
                        Text(l10n.clashAutoDetectHint)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                            .lineSpacing(3)
                    }
                    .padding(PharosSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(PharosColor.fill)
                    )

                    if let ep = clash.endpoint {
                        HStack(spacing: 6) {
                            Text(l10n.clashEndpointLabel + ":")
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textTertiary)
                            Text(ep.displayString)
                                .font(PharosFont.captionDigits)
                                .foregroundStyle(PharosColor.textPrimary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.vertical, 8)
            } else {
                // Manual Config Form
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.clashEndpointLabel)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                        TextField(l10n.clashEndpointPlaceholder, text: $endpoint)
                            .textFieldStyle(.roundedBorder)
                            .font(PharosFont.rowLabel)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.clashSecretLabel)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                        HStack(spacing: 6) {
                            if isSecretVisible {
                                TextField(l10n.clashSecretPlaceholder, text: $secret)
                                    .textFieldStyle(.roundedBorder)
                                    .font(PharosFont.rowLabel)
                            } else {
                                SecureField(l10n.clashSecretPlaceholder, text: $secret)
                                    .textFieldStyle(.roundedBorder)
                                    .font(PharosFont.rowLabel)
                            }
                            Button {
                                isSecretVisible.toggle()
                            } label: {
                                Image(systemName: isSecretVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 13))
                                    .foregroundStyle(PharosColor.textSecondary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .help(isSecretVisible ? "Hide" : "Show")
                        }
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(l10n.clashMixedPortLabel)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                            TextField("7890", text: $mixedPortStr)
                                .textFieldStyle(.roundedBorder)
                                .font(PharosFont.rowLabel)
                                .frame(width: 100)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(l10n.clashClientNameLabel)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                            TextField("Clash Verge Rev / Sing-Box", text: $clientName)
                                .textFieldStyle(.roundedBorder)
                                .font(PharosFont.rowLabel)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.clashConfigPathLabel)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                        TextField(l10n.clashConfigPathPlaceholder, text: $configPath)
                            .textFieldStyle(.roundedBorder)
                            .font(PharosFont.rowLabel)
                    }

                    // Test Connection Section
                    HStack(spacing: 10) {
                        Button {
                            testCurrentConnection()
                        } label: {
                            HStack(spacing: 5) {
                                if isTesting {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text(isTesting ? l10n.clashTesting : l10n.clashTestConnection)
                            }
                        }
                        .buttonStyle(.pharos)
                        .controlSize(.small)
                        .disabled(isTesting || endpoint.trimmingCharacters(in: .whitespaces).isEmpty)

                        if let res = testResult {
                            HStack(spacing: 5) {
                                Image(systemName: res.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(res.success ? PharosColor.success : PharosColor.error)
                                    .font(.system(size: 12))
                                Text(res.success ? l10n.clashTestSuccess : "\(l10n.clashTestFailed): \(res.message)")
                                    .font(PharosFont.caption)
                                    .foregroundStyle(res.success ? PharosColor.success : PharosColor.error)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            // Bottom action buttons
            HStack(spacing: PharosSpacing.s) {
                Spacer()

                Button(l10n.cancel) {
                    isPresented = false
                }
                .buttonStyle(.pharos)
                .controlSize(.regular)

                Button(l10n.clashSaveAndApply) {
                    saveAndApply()
                }
                .buttonStyle(.pharosPrimary)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(PharosSpacing.l)
        .frame(width: 480)
        .onAppear {
            isManual = clash.isManualMode
            endpoint = clash.manualEndpoint
            secret = clash.manualSecret
            mixedPortStr = String(clash.manualMixedPort)
            clientName = clash.manualClientName
            configPath = clash.manualConfigPath
        }
    }

    private func testCurrentConnection() {
        guard !isTesting else { return }
        isTesting = true
        testResult = nil
        let targetEndpoint = endpoint
        let targetSecret = secret
        Task {
            let res = await clash.testConnection(endpoint: targetEndpoint, secret: targetSecret)
            await MainActor.run {
                testResult = res
                isTesting = false
            }
        }
    }

    private func saveAndApply() {
        clash.isManualMode = isManual
        if isManual {
            clash.manualEndpoint = endpoint.trimmingCharacters(in: .whitespaces)
            clash.manualSecret = secret.trimmingCharacters(in: .whitespaces)
            clash.manualConfigPath = configPath.trimmingCharacters(in: .whitespaces)
            if let p = Int(mixedPortStr.trimmingCharacters(in: .whitespaces)), p > 0 {
                clash.manualMixedPort = p
            }
            let trimmedName = clientName.trimmingCharacters(in: .whitespaces)
            if !trimmedName.isEmpty {
                clash.manualClientName = trimmedName
            }
        }
        Task {
            await clash.refresh()
        }
        isPresented = false
    }
}
