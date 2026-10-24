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
                    if index > 0 {
                        PharosListDivider()
                    }
                    row(b)
                }
            }

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
    @AppStorage("pharos.popoverGaussianBlur") private var popoverGaussianBlur: Bool = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(l10n.motionPerformanceMode)
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $gauge3DAcceleration) {
                        Text(l10n.motionModeSmooth).tag(true)
                        Text(l10n.motionModeBalanced).tag(false)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 175)
                    .disabled(systemReduceMotion)
                }

                if systemReduceMotion {
                    Text(l10n.systemReduceMotionNotice)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if gauge3DAcceleration {
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

            VStack(alignment: .leading, spacing: 3) {
                Toggle(l10n.popoverGaussianBlur, isOn: $popoverGaussianBlur)
                    .font(.system(size: 12))
                    .disabled(systemReduceMotion)
                Text(l10n.popoverGaussianBlurHint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Modern Main Settings View (Target App Inspired)

struct MainSettingsView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var workspaces = WorkspaceStore.shared
    @ObservedObject private var menuBar = MenuBarSettings.shared
    @ObservedObject private var notifier = Notifier.shared
    @ObservedObject private var packageStore = PackageStore.shared
    @ObservedObject private var agentStore = AgentChatStore.shared
    @ObservedObject private var chrome = ChromeStore.shared

    @AppStorage("pharos.gauge3DAcceleration") private var gauge3DAcceleration: Bool = true
    @AppStorage("pharos.popoverGaussianBlur") private var popoverGaussianBlur: Bool = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String? = nil
    @State private var backupMessage: String? = nil
    @State private var showResetAlert = false

    var body: some View {
        PharosPage(maxWidth: 680) {
            PharosPageHeader(title: l10n.settings)
        } content: {
            // 1. Quick Actions (Rabbit / Hare icon)
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                SettingsSectionHeader(title: l10n.quickActions, systemImage: "hare.fill")
                PharosCard(padding: 14) {
                    VStack(spacing: 12) {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 10) {
                            CapsuleActionButton(title: l10n.refreshNow, systemImage: "arrow.clockwise") {
                                Task { await store.refresh() }
                            }
                            CapsuleActionButton(title: l10n.exportSettings, systemImage: "square.and.arrow.up") {
                                backupMessage = BackupActions.export() ?? backupMessage
                            }
                            CapsuleActionButton(title: l10n.importSettings, systemImage: "square.and.arrow.down") {
                                backupMessage = BackupActions.importFile() ?? backupMessage
                            }
                            CapsuleActionButton(title: l10n.resetAllSettings, systemImage: "arrow.counterclockwise", isDestructive: true) {
                                showResetAlert = true
                            }
                        }

                        if let backupMessage {
                            PharosBanner(kind: .info, text: backupMessage)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }

            // 2. License & About (Shield checkmark icon)
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                SettingsSectionHeader(title: l10n.aboutPharos, systemImage: "checkmark.shield.fill")
                PharosCard(padding: 16) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Pharos v3.0")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(PharosColor.textPrimary)
                            Text(l10n.openSourceSubtitle)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://github.com/Zhengyuuuui/Pharos")!)
                        } label: {
                            HStack(spacing: 5) {
                                Text(l10n.viewOnGitHub)
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 10.5))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PharosColor.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(Capsule().fill(PharosColor.fill))
                            .overlay(Capsule().stroke(PharosColor.separator.opacity(0.3), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 3. General & System (Gearshape icon)
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                SettingsSectionHeader(title: l10n.generalSettings, systemImage: "gearshape.fill")
                PharosCard(padding: 14) {
                    VStack(spacing: 10) {
                        // Launch at Login
                        PharosSettingRow(
                            title: l10n.launchAtLogin,
                            systemImage: "play.circle",
                            help: l10n.launchAtLoginHelp
                        ) {
                            Toggle("", isOn: $launchAtLogin)
                                .labelsHidden()
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
                        }

                        if let loginError {
                            PharosBanner(kind: .warning, text: loginError)
                        }

                        PharosListDivider()

                        // Language
                        PharosSettingRow(title: l10n.languageTitle, systemImage: "globe") {
                            Picker("", selection: $l10n.language) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }

                        PharosListDivider()

                        // Refresh Interval
                        PharosSettingRow(title: l10n.refreshEvery, systemImage: "arrow.clockwise") {
                            Picker("", selection: $store.refreshSeconds) {
                                ForEach([2, 5, 10, 30], id: \.self) { s in
                                    Text(l10n.seconds(s)).tag(s)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }

                        PharosListDivider()

                        // Show system processes
                        PharosSettingRow(
                            title: l10n.showSystem,
                            systemImage: "cpu",
                            caption: l10n.showSystemHint
                        ) {
                            Toggle("", isOn: $store.showSystem)
                                .labelsHidden()
                        }
                    }
                }
            }

            // 4. Menu Bar & Visuals (Sparkles icon)
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                SettingsSectionHeader(title: l10n.appearanceSettings, systemImage: "sparkles")
                PharosCard(padding: 14) {
                    VStack(spacing: 10) {
                        // Menu bar text
                        PharosSettingRow(title: l10n.menuBarText, systemImage: "menubar.rectangle") {
                            Picker("", selection: $menuBar.text) {
                                ForEach(MenuBarText.allCases) { Text(l10n.menuBarTextOption($0)).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }

                        if menuBar.text == .projects {
                            HStack {
                                Text(l10n.maxProjectsCapacity)
                                    .font(PharosFont.caption)
                                    .foregroundStyle(PharosColor.textSecondary)
                                    .padding(.leading, 26)
                                Spacer()
                                TextField("", value: $menuBar.maxProjects, format: .number)
                                    .frame(width: 44)
                                    .multilineTextAlignment(.trailing)
                                Stepper("", value: $menuBar.maxProjects, in: 5...200, step: 5)
                                    .labelsHidden()
                            }
                            .font(PharosFont.captionDigits)
                            .help(l10n.capacityRingHint)
                        } else if menuBar.text == .ports {
                            HStack {
                                Text(l10n.maxPortsCapacity)
                                    .font(PharosFont.caption)
                                    .foregroundStyle(PharosColor.textSecondary)
                                    .padding(.leading, 26)
                                Spacer()
                                TextField("", value: $menuBar.maxPorts, format: .number)
                                    .frame(width: 44)
                                    .multilineTextAlignment(.trailing)
                                Stepper("", value: $menuBar.maxPorts, in: 5...300, step: 5)
                                    .labelsHidden()
                            }
                            .font(PharosFont.captionDigits)
                            .help(l10n.capacityRingHint)
                        }

                        PharosListDivider()

                        // Global hotkey
                        PharosSettingRow(
                            title: l10n.hotkeyTitle,
                            systemImage: "command",
                            caption: menuBar.hotkeyError
                        ) {
                            Picker("", selection: $menuBar.hotkey) {
                                ForEach(PopoverHotkey.allCases) { Text($0.label).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }

                        PharosListDivider()

                        // Gauge 3D Acceleration / Motion Mode
                        PharosSettingRow(
                            title: l10n.motionPerformanceMode,
                            systemImage: "gauge.with.needle",
                            caption: systemReduceMotion ? l10n.systemReduceMotionNotice : (gauge3DAcceleration ? l10n.gauge3DAccelerationNotice : l10n.gaugeReducedMotionNotice)
                        ) {
                            Picker("", selection: $gauge3DAcceleration) {
                                Text(l10n.motionModeSmooth).tag(true)
                                Text(l10n.motionModeBalanced).tag(false)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                            .disabled(systemReduceMotion)
                        }

                        PharosListDivider()

                        // Popover glass blur
                        PharosSettingRow(
                            title: l10n.popoverGaussianBlur,
                            systemImage: "drop.fill",
                            caption: l10n.popoverGaussianBlurHint
                        ) {
                            Toggle("", isOn: $popoverGaussianBlur)
                                .labelsHidden()
                                .disabled(systemReduceMotion)
                        }
                    }
                }
            }

            // 5. Developer & Workspaces (Terminal icon)
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                SettingsSectionHeader(title: l10n.devToolsSettings, systemImage: "terminal.fill")
                PharosCard(padding: 14) {
                    VStack(spacing: 10) {
                        // Terminal
                        PharosSettingRow(title: l10n.terminalTitle, systemImage: "terminal") {
                            Picker("", selection: $workspaces.terminal) {
                                ForEach(TerminalApp.allCases, id: \.self) { t in
                                    Text(workspaces.isInstalled(t) ? t.displayName : "\(t.displayName) (\(l10n.notInstalled))")
                                        .tag(t)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }

                        PharosListDivider()

                        // AI Chat layout
                        PharosSettingRow(
                            title: l10n.agentEditorLayoutTitle,
                            systemImage: "bubble.left.and.text.bubble.right",
                            caption: l10n.agentEditorLayoutHint
                        ) {
                            Picker("", selection: $agentStore.editorLayout) {
                                ForEach(AgentEditorLayout.allCases) { Text(l10n.agentEditorLayoutOption($0)).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }

                        PharosListDivider()

                        // Package deps display mode
                        PharosSettingRow(
                            title: l10n.projectDepsDisplayMode,
                            systemImage: "shippingbox",
                            caption: l10n.projectDepsDisplayModeHint
                        ) {
                            Picker("", selection: $packageStore.projectDepsDisplayMode) {
                                ForEach(PackageDepsDisplayMode.allCases) { mode in
                                    Text(l10n.projectDepsDisplayModeOption(mode)).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                    }
                }
            }

            // 6. Notifications (Bell icon)
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                SettingsSectionHeader(title: l10n.notificationsTitle, systemImage: "bell.fill")
                PharosCard(padding: 14) {
                    VStack(spacing: 10) {
                        PharosSettingRow(title: l10n.notifyMemory, systemImage: "memorychip") {
                            Toggle("", isOn: $notifier.memory).labelsHidden()
                        }
                        PharosListDivider()
                        PharosSettingRow(title: l10n.notifyDisk, systemImage: "internaldrive") {
                            Toggle("", isOn: $notifier.disk).labelsHidden()
                        }
                        PharosListDivider()
                        PharosSettingRow(title: l10n.notifyFavoriteExit, systemImage: "star") {
                            Toggle("", isOn: $notifier.favoriteExit).labelsHidden()
                        }

                        if notifier.denied && notifier.anyEnabled {
                            PharosBanner(kind: .warning, text: l10n.notificationsDenied)
                        }
                    }
                    .onAppear { notifier.refreshAuthorization() }
                }
            }

            // 7. Chromium Browsers (Globe Americas icon)
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                SettingsSectionHeader(title: l10n.browsersSettings, systemImage: "globe.americas.fill")
                PharosCard(padding: 14) {
                    BrowserSettingsForm()
                }
            }

            // 8. Privacy & Data Notice Banner
            PharosBanner(kind: .info, text: l10n.dataNotice)

            // 9. Footer (Matching reference app footer)
            HStack {
                Text("Pharos v3.0 · macOS 14+")
                    .font(PharosFont.captionDigits)
                    .foregroundStyle(PharosColor.textTertiary)
                Spacer()
                Link("github.com/Zhengyuuuui/Pharos", destination: URL(string: "https://github.com/Zhengyuuuui/Pharos")!)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.accent)
                Spacer()
                Text(l10n.footerCrafted)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textTertiary)
            }
            .padding(.top, PharosSpacing.s)
            .padding(.bottom, PharosSpacing.l)
        }
        .alert(l10n.resetAllSettings, isPresented: $showResetAlert) {
            Button(l10n.cancel, role: .cancel) {}
            Button(l10n.resetAllSettings, role: .destructive) {
                PopoverLayoutStore.shared.reset()
                MenuBarSettings.shared.reset()
                backupMessage = l10n.resetSettingsDone
            }
        } message: {
            Text(l10n.resetAllSettingsConfirm)
        }
    }
}

// MARK: - Reusable Setting UI Helpers

private struct SettingsSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: PharosSpacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(PharosColor.textPrimary)
            Text(title)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(PharosColor.textPrimary)
        }
        .padding(.horizontal, PharosSpacing.xs)
    }
}

private struct CapsuleActionButton: View {
    let title: String
    var systemImage: String? = nil
    var isDestructive: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isDestructive ? PharosColor.error : PharosColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                Capsule(style: .continuous)
                    .fill(isHovered ? PharosColor.fillPressed : PharosColor.fill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isDestructive ? PharosColor.error.opacity(0.3) : PharosColor.separator.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
