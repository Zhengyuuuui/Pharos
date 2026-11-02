import SwiftUI
import PharosCore

/// Lists only permissions Pharos really uses; none of them blocks Continue.
struct OnboardingPermissionsStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let level: OnboardingMotionLevel
    @ObservedObject private var battery = BatteryStore.shared
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var installing = false

    var body: some View {
        OnboardingStepScaffold(title: l10n.onboardingPermissionsTitle, subtitle: l10n.onboardingPermissionsSubtitle, level: level) {
            PharosCard(padding: 0) {
                VStack(spacing: 0) {
                    row(icon: "waveform.path.ecg", title: l10n.onboardingPermTelemetryTitle, desc: l10n.onboardingPermTelemetryDesc) {
                        OnboardingStatusTag(text: l10n.onboardingPermReady)
                    }
                    if battery.reading.hasBattery {
                        PharosListDivider().padding(.leading, 56)
                        row(icon: "bolt.shield", title: l10n.onboardingPermHelperTitle, desc: l10n.onboardingPermHelperDesc) {
                            helperControl
                        }
                    }
                    PharosListDivider().padding(.leading, 56)
                    row(icon: "externaldrive.badge.checkmark", title: l10n.onboardingPermFDATitle, desc: l10n.onboardingPermFDADesc) {
                        fdaControl
                    }
                }
            }
            .frame(maxWidth: 600)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            cleanup.refreshPermissionStatus()
            battery.refreshHelperState()
            coordinator.clearResumePoint()
        }
    }

    @ViewBuilder
    private var helperControl: some View {
        if !battery.capabilities.isSupported {
            PharosTag(l10n.onboardingPermHelperUnsupported)
        } else if battery.helper == .ready {
            OnboardingStatusTag(text: l10n.onboardingPermHelperInstalled)
        } else if installing || battery.busy {
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text(l10n.onboardingPermHelperInstalling)
            }
            .font(PharosFont.caption)
            .foregroundStyle(PharosColor.textSecondary)
        } else {
            Button(l10n.onboardingPermHelperInstall) {
                installing = true
                // Install only — charging stays with macOS. Cancel (-128) just restores the button.
                battery.install(activateLimitAfterInstall: false) { _ in installing = false }
            }
            .buttonStyle(.pharos)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var fdaControl: some View {
        if cleanup.hasFullDiskAccess {
            OnboardingStatusTag(text: l10n.onboardingPermFDAGranted)
        } else {
            Button(l10n.onboardingPermOpenSettings) {
                coordinator.rememberResumePoint()
                cleanup.openFullDiskAccessSettings()
            }
            .buttonStyle(.pharos)
            .controlSize(.small)
        }
    }

    private func row<Trailing: View>(icon: String, title: String, desc: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .top, spacing: PharosSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(PharosColor.textSecondary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(PharosFont.rowLabel).foregroundStyle(PharosColor.textPrimary)
                Text(desc)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: PharosSpacing.m)
            trailing()
                .fixedSize()
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
