import SwiftUI
import PharosCore

/// Real-time control center for Clash / Mihomo daemon.
/// Displays running client type, ports, traffic speeds, and provides hot mode switching.
struct ClashDashboardSection: View {
    @ObservedObject private var clash = ClashStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let snap = clash.snapshot

        PharosSection(title: l10n.clashControlHub, systemImage: "network") {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                // 1. Client Header & Metric Bar
                HStack(alignment: .center, spacing: PharosSpacing.m) {
                    // Client Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(snap.isRunning ? PharosColor.accent.opacity(0.12) : PharosColor.fill)
                            .frame(width: 44, height: 44)
                        Image(systemName: snap.clientKind?.iconName ?? "network")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(snap.isRunning ? PharosColor.accent : PharosColor.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(snap.clientKind?.rawValue ?? (snap.isRunning ? "Mihomo Core" : l10n.clashControlHub))
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
                        }

                        if snap.isRunning {
                            HStack(spacing: 12) {
                                Label("\(l10n.clashMixedPort): \(snap.mixedPort)", systemImage: "arrow.left.arrow.right")
                                    .font(PharosFont.captionDigits)
                                    .foregroundStyle(PharosColor.textSecondary)

                                if snap.socksPort > 0 {
                                    Label("\(l10n.clashSocksPort): \(snap.socksPort)", systemImage: "network")
                                        .font(PharosFont.captionDigits)
                                        .foregroundStyle(PharosColor.textSecondary)
                                }

                                Label(
                                    snap.isTunEnabled ? "\(l10n.clashTunMode): \(l10n.clashTunEnabled)" : "\(l10n.clashTunMode): \(l10n.clashTunDisabled)",
                                    systemImage: "shield.checkered"
                                )
                                .font(PharosFont.caption)
                                .foregroundStyle(snap.isTunEnabled ? PharosColor.accent : PharosColor.textTertiary)
                            }
                        } else {
                            Text(l10n.clashClientStoppedHint)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textTertiary)
                        }
                    }

                    Spacer()

                    // Real-time Traffic Speeds
                    if snap.isRunning {
                        VStack(alignment: .trailing, spacing: 3) {
                            HStack(spacing: 8) {
                                Label("↑ \(ByteFormat.short(snap.uploadBytesPerSec))/s", systemImage: "arrow.up")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(PharosColor.textSecondary)
                                Label("↓ \(ByteFormat.short(snap.downloadBytesPerSec))/s", systemImage: "arrow.down")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(PharosColor.accent)
                            }
                            if snap.activeConnectionCount > 0 {
                                Text("\(l10n.clashActiveConnections): \(snap.activeConnectionCount)")
                                    .font(PharosFont.captionDigits)
                                    .foregroundStyle(PharosColor.textTertiary)
                            }
                        }
                    }
                }

                Divider()

                // 2. Mode Selector Bento
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n.clashRoutingMode)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)

                    HStack(spacing: PharosSpacing.s) {
                        modeCard(
                            mode: .rule,
                            title: l10n.clashModeRule,
                            desc: l10n.clashModeRuleDesc,
                            icon: "arrow.triangle.branch",
                            isSelected: snap.mode == .rule,
                            disabled: !snap.isRunning
                        )
                        modeCard(
                            mode: .direct,
                            title: l10n.clashModeDirect,
                            desc: l10n.clashModeDirectDesc,
                            icon: "bolt.horizontal.fill",
                            isSelected: snap.mode == .direct,
                            disabled: !snap.isRunning
                        )
                        modeCard(
                            mode: .global,
                            title: l10n.clashModeGlobal,
                            desc: l10n.clashModeGlobalDesc,
                            icon: "globe",
                            isSelected: snap.mode == .global,
                            disabled: !snap.isRunning
                        )
                    }
                }

                // 3. Quick Action Buttons
                HStack(spacing: PharosSpacing.s) {
                    PharosActionButton(
                        l10n.clashResetConnections,
                        systemImage: "bolt.slash.fill",
                        role: .standard
                    ) {
                        Task { await clash.closeAllConnections() }
                    }
                    .controlSize(.small)
                    .disabled(!snap.isRunning || clash.isOperating)
                    .help(l10n.clashResetConnectionsHint)

                    PharosActionButton(
                        l10n.clashCopyTerminalProxy,
                        systemImage: "terminal.fill",
                        role: .standard
                    ) {
                        clash.copyTerminalProxySnippet()
                    }
                    .controlSize(.small)

                    PharosActionButton(
                        l10n.clashCopyTerminalUnset,
                        systemImage: "xmark.circle",
                        role: .standard
                    ) {
                        clash.copyTerminalUnsetSnippet()
                    }
                    .controlSize(.small)

                    Spacer()
                }

                // Banners
                if let note = clash.notificationBanner {
                    PharosBanner(kind: .info, text: note) {
                        IconButton(systemImage: "xmark", help: l10n.dismiss) { clash.notificationBanner = nil }
                    }
                    .task(id: note) {
                        try? await Task.sleep(for: .seconds(3))
                        clash.notificationBanner = nil
                    }
                }
                if let err = clash.errorMessage {
                    PharosBanner(kind: .error, text: err) {
                        IconButton(systemImage: "xmark", help: l10n.dismiss) { clash.errorMessage = nil }
                    }
                }
            }
        }
    }

    private func modeCard(
        mode: ClashRoutingMode,
        title: String,
        desc: String,
        icon: String,
        isSelected: Bool,
        disabled: Bool
    ) -> some View {
        Button {
            guard !disabled else { return }
            Task { await clash.switchMode(mode) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? PharosColor.accent : PharosColor.textSecondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? PharosColor.accent : PharosColor.textPrimary)
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundStyle(PharosColor.textTertiary)
                }
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PharosColor.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? PharosColor.accent.opacity(0.08) : PharosColor.fill.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? PharosColor.accent : PharosColor.separator.opacity(0.2), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1.0)
    }
}
