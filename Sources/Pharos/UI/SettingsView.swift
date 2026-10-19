import PharosCore
import SwiftUI
import ServiceManagement

/// Settings → Browsers: which Chromium browsers are installed, which appear on
/// the instances page, and which one "New Instance" uses.
struct BrowserSettingsForm: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var chrome = ChromeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.browsersSettings).font(.system(size: 12, weight: .semibold))

            VStack(spacing: 0) {
                ForEach(Array(ChromiumBrowser.allCases.enumerated()), id: \.element) { index, b in
                    row(b).background(index.isMultiple(of: 2) ? Color.primary.opacity(0.03) : .clear)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.08)))

            if chrome.installedBrowsers.count > 1 {
                Picker(l10n.defaultBrowserForNew, selection: $chrome.defaultBrowser) {
                    ForEach(chrome.installedBrowsers, id: \.self) { Text($0.appName).tag($0) }
                }
                .font(.system(size: 12))
                .fixedSize()
            }

            Text(l10n.browsersSettingsHint)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ b: ChromiumBrowser) -> some View {
        let installed = chrome.isInstalled(b)
        let running = store.chrome.filter { $0.config.browser == b }.count
        let saved = chrome.presets.filter { $0.config.browser == b }.count
        return HStack(spacing: 8) {
            Toggle(isOn: Binding(get: { chrome.isVisible(b) }, set: { chrome.setVisible(b, $0) })) { EmptyView() }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .help(l10n.showInList)
            VStack(alignment: .leading, spacing: 1) {
                Text(b.appName).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(installed ? .primary : .secondary)
                Text(b.defaultUserDataDir.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if installed {
                if running > 0 {
                    Text(l10n.runningCount(running)).font(.system(size: 10)).foregroundStyle(.green)
                }
                if saved > 0 {
                    Text(l10n.presetCount(saved)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                IconButton(systemImage: "folder", help: l10n.revealProfiles) { chrome.revealDefaultProfile(b) }
            } else {
                Text(l10n.notInstalled).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

/// Main-window-only settings: terminal, menu bar text, shortcut, notifications, backup.
struct ExtraSettingsForm: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var workspaces = WorkspaceStore.shared
    @ObservedObject private var menuBar = MenuBarSettings.shared
    @ObservedObject private var notifier = Notifier.shared
    @ObservedObject private var packageStore = PackageStore.shared
    @ObservedObject private var agentStore = AgentChatStore.shared
    @State private var backupMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(l10n.terminalTitle, selection: $workspaces.terminal) {
                ForEach(TerminalApp.allCases, id: \.self) { t in
                    Text(workspaces.isInstalled(t) ? t.displayName : "\(t.displayName) (\(l10n.notInstalled))")
                        .tag(t)
                }
            }
            .font(.system(size: 12))

            Picker(l10n.menuBarText, selection: $menuBar.text) {
                ForEach(MenuBarText.allCases) { Text(l10n.menuBarTextOption($0)).tag($0) }
            }
            .font(.system(size: 12))

            if menuBar.text == .projects {
                HStack {
                    Text(l10n.maxProjectsCapacity)
                    Spacer()
                    TextField("", value: $menuBar.maxProjects, format: .number)
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $menuBar.maxProjects, in: 5...200, step: 5)
                        .labelsHidden()
                }
                .font(.system(size: 12))
                .help(l10n.capacityRingHint)
            } else if menuBar.text == .ports {
                HStack {
                    Text(l10n.maxPortsCapacity)
                    Spacer()
                    TextField("", value: $menuBar.maxPorts, format: .number)
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $menuBar.maxPorts, in: 5...300, step: 5)
                        .labelsHidden()
                }
                .font(.system(size: 12))
                .help(l10n.capacityRingHint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Picker(l10n.hotkeyTitle, selection: $menuBar.hotkey) {
                    ForEach(PopoverHotkey.allCases) { Text($0.label).tag($0) }
                }
                .font(.system(size: 12))
                if let error = menuBar.hotkeyError {
                    Text(error).font(.system(size: 10)).foregroundStyle(.orange)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Picker(l10n.agentEditorLayoutTitle, selection: $agentStore.editorLayout) {
                    ForEach(AgentEditorLayout.allCases) { Text(l10n.agentEditorLayoutOption($0)).tag($0) }
                }
                .font(.system(size: 12))
                Text(l10n.agentEditorLayoutHint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(l10n.packageSettingsTitle).font(.system(size: 12, weight: .semibold))
                Picker(l10n.projectDepsDisplayMode, selection: $packageStore.projectDepsDisplayMode) {
                    ForEach(PackageDepsDisplayMode.allCases) { mode in
                        Text(l10n.projectDepsDisplayModeOption(mode)).tag(mode)
                    }
                }
                .font(.system(size: 12))
                Text(l10n.projectDepsDisplayModeHint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.notificationsTitle).font(.system(size: 12, weight: .semibold))
                Toggle(l10n.notifyMemory, isOn: $notifier.memory).font(.system(size: 12))
                Toggle(l10n.notifyDisk, isOn: $notifier.disk).font(.system(size: 12))
                Toggle(l10n.notifyFavoriteExit, isOn: $notifier.favoriteExit).font(.system(size: 12))
                if notifier.denied && notifier.anyEnabled {
                    Text(l10n.notificationsDenied).font(.system(size: 10)).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .onAppear { notifier.refreshAuthorization() }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(l10n.backupTitle).font(.system(size: 12, weight: .semibold))
                HStack {
                    Button(l10n.exportSettings) { backupMessage = BackupActions.export() ?? backupMessage }
                    Button(l10n.importSettings) { backupMessage = BackupActions.importFile() ?? backupMessage }
                }
                .controlSize(.small)
                Text(l10n.backupHint).font(.system(size: 10)).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if let backupMessage {
                    Text(backupMessage).font(.system(size: 10)).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
    }
}


/// Shared settings controls, used by both the popover and the main window.
struct SettingsForm: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("pharos.gauge3DAcceleration") private var gauge3DAcceleration: Bool = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(l10n.languageTitle, selection: $l10n.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .font(.system(size: 12))

            Picker(l10n.refreshEvery, selection: $store.refreshSeconds) {
                ForEach([2, 5, 10, 30], id: \.self) { s in
                    Text(l10n.seconds(s)).tag(s)
                }
            }
            .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 3) {
                Toggle(l10n.showSystem, isOn: $store.showSystem)
                    .font(.system(size: 12))
                Text(l10n.showSystemHint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle(l10n.gauge3DAcceleration, isOn: $gauge3DAcceleration)
                    .font(.system(size: 12))
                if gauge3DAcceleration {
                    Text(l10n.gauge3DAccelerationNotice)
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(l10n.gaugeReducedMotionNotice)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(l10n.launchAtLogin, isOn: $launchAtLogin)
                .font(.system(size: 12))
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        loginError = nil
                    } catch {
                        loginError = l10n.loginError
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            if let loginError {
                Text(loginError)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { isPresented = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                        Text(l10n.back)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowButtonStyle())
                Spacer()
                Text(l10n.settings)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Color.clear.frame(width: 50, height: 1)
            }

            SettingsForm()
                .padding(.horizontal, 4)

            Text(l10n.dataNotice)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
