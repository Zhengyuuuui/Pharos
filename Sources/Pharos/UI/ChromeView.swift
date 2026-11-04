import SwiftUI
import PharosCore

/// Main window page: Clash/Mihomo network control center, browser proxy isolation matrix,
/// and Chromium browser instances with live stats, start/quit and configuration.
struct BrowserNetworkView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = WindowRouter.shared
    @State private var editing: String?
    /// nil = all browsers.
    @State private var filter: ChromiumBrowser?

    private let metricColumns = [GridItem(.adaptive(minimum: 150), spacing: PharosSpacing.l, alignment: .top)]

    var body: some View {
        let browsers = chrome.browsersInUse(store.chrome)
        let active = filter.flatMap { browsers.contains($0) ? $0 : nil }
        let entries = chrome.entries(store.chrome, browser: active)
        let running = entries.compactMap(\.running)

        PharosPage {
            PharosPageHeader(title: l10n.browsersAndNetwork, subtitle: l10n.browsersAndNetworkSubtitle) {
                HStack(spacing: PharosSpacing.s) {
                    PharosActionButton(chrome.sizing ? l10n.measuring : l10n.measureFolders, systemImage: "internaldrive", role: .standard) {
                        chrome.measureSizes(Array(Set(entries.map(\.config.profileKey))))
                    }
                    .controlSize(.small)
                    .disabled(chrome.sizing)
                    newInstanceButton(active)
                }
            }
        } content: {
            BrowserProxyMatrixSection()

            ClashDashboardSection()

            if browsers.count > 1 {
                Picker("", selection: $filter) {
                    Text(l10n.allBrowsers).tag(ChromiumBrowser?.none)
                    ForEach(browsers, id: \.self) { b in
                        Text(b.appName).tag(ChromiumBrowser?.some(b))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            PharosSection(title: l10n.overview, systemImage: "globe") {
                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: PharosSpacing.l) {
                    PharosMetricValue(title: l10n.chromeRunning,
                                      value: "\(running.count)",
                                      systemImage: "globe")
                    PharosMetricValue(title: l10n.chromePresets,
                                      value: "\(entries.filter { $0.preset != nil }.count)",
                                      systemImage: "star")
                    PharosMetricValue(title: l10n.memory,
                                      value: ByteFormat.short(running.reduce(0) { $0 + $1.memoryBytes }),
                                      systemImage: "memorychip")
                }
            }

            if let message = chrome.errorMessage {
                PharosBanner(kind: .error, text: message) {
                    IconButton(systemImage: "xmark", help: l10n.dismiss) { chrome.errorMessage = nil }
                }
            }

            if !chrome.chromeInstalled {
                PharosBanner(kind: .warning, text: l10n.chromeNotInstalled)
            } else if entries.isEmpty {
                PharosCard {
                    PharosEmptyState(
                        title: l10n.chromeEmpty,
                        systemImage: "globe",
                        message: l10n.chromeEmptyDesc
                    )
                }
            }

            if active == nil && browsers.count > 1 {
                ForEach(browsers, id: \.self) { b in
                    let group = entries.filter { $0.config.browser == b }
                    if !group.isEmpty {
                        VStack(alignment: .leading, spacing: PharosSpacing.titleToCard) {
                            BrowserGroupHeader(browser: b, entries: group)
                            VStack(spacing: PharosSpacing.m) {
                                ForEach(group) { ChromeCard(entry: $0, editing: $editing) }
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: PharosSpacing.m) {
                    ForEach(entries) { entry in
                        ChromeCard(entry: entry, editing: $editing)
                    }
                }
            }

            PharosBanner(kind: .info, text: l10n.chromeNotice)
        }
        .onAppear {
            chrome.loadProfileNames(entries.map(\.config.profileKey))
            if let id = router.editingPresetId {
                editing = id
                router.editingPresetId = nil
            }
        }
        .onChange(of: router.editingPresetId) { _, id in
            if let id {
                editing = id
                router.editingPresetId = nil
            }
        }
        .onChange(of: store.lastScan) { _, _ in chrome.loadProfileNames(entries.map(\.config.profileKey)) }
    }

    /// With a browser filter selected, "New Instance" uses that browser;
    /// otherwise it's a menu defaulting to Settings → Browsers.
    @ViewBuilder
    private func newInstanceButton(_ active: ChromiumBrowser?) -> some View {
        if let active {
            Button { editing = chrome.addPreset(browser: active) } label: {
                Label(l10n.newChromePreset, systemImage: "plus")
            }
            .buttonStyle(.pharosPrimary)
            .controlSize(.small)
        } else if chrome.installedBrowsers.count > 1 {
            Menu {
                ForEach(chrome.installedBrowsers, id: \.self) { b in
                    Button(b.appName) { editing = chrome.addPreset(browser: b) }
                }
            } label: {
                Label(l10n.newChromePreset, systemImage: "plus")
            } primaryAction: {
                editing = chrome.addPreset()
            }
            .controlSize(.small)
            .fixedSize()
        } else {
            Button { editing = chrome.addPreset() } label: {
                Label(l10n.newChromePreset, systemImage: "plus")
            }
            .buttonStyle(.pharosPrimary)
            .controlSize(.small)
        }
    }
}

typealias ChromeView = BrowserNetworkView

private struct BrowserGroupHeader: View {
    @ObservedObject private var l10n = L10n.shared
    let browser: ChromiumBrowser
    let entries: [ChromeStore.Entry]

    var body: some View {
        let running = entries.compactMap(\.running)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(browser.appName).font(.system(size: 13, weight: .semibold))
            Text(l10n.runningCount(running.count)).font(.system(size: 10)).foregroundStyle(.secondary)
            if !running.isEmpty {
                Text("· " + ByteFormat.short(running.reduce(0) { $0 + $1.memoryBytes }))
                    .font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 4)
    }
}

private struct ChromeCard: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared
    let entry: ChromeStore.Entry
    @Binding var editing: String?
    @State private var armedRemove = false

    var body: some View {
        let c = entry.config
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack(alignment: .center, spacing: PharosSpacing.s) {
                    RunDot(running: entry.isRunning)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(entry.preset?.name ?? defaultName(c))
                                .font(PharosFont.rowLabel)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let port = c.debugPort {
                                PharosTag(":\(String(port))", tint: PharosColor.accent, monospaced: true)
                            }
                            proxyBadge(c.proxyStrategy)
                        }
                        Text(subtitle(c))
                            .font(PharosFont.captionDigits)
                            .foregroundStyle(PharosColor.textSecondary)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: PharosSpacing.s)
                    actions
                }

                Grid(alignment: .leading, horizontalSpacing: PharosSpacing.m, verticalSpacing: PharosSpacing.xs) {
                    if c.browser != .chrome { row(l10n.browserTitle, c.browser.appName, mono: false) }
                    row(l10n.profileFolder, c.isDefaultProfile ? l10n.defaultProfile : c.profileKey, mono: !c.isDefaultProfile)
                    if let proxy = c.proxyServer { row(l10n.proxy, proxy, mono: true) }
                    if let url = c.startURL { row(l10n.startURL, url, mono: true) }
                    let accounts = chrome.profileNames[c.profileKey] ?? []
                    if !accounts.isEmpty { row(l10n.chromeAccounts, accounts.joined(separator: ", "), mono: false) }
                    if let size = chrome.folderSizes[c.profileKey] {
                        row(l10n.folderSize, ByteFormat.short(size), mono: false)
                    }
                    if !c.extraFlags.isEmpty { row(l10n.extraFlags, c.extraFlags.joined(separator: " "), mono: true) }
                }

                // Quick Proxy Override Bar
                HStack(alignment: .center, spacing: 8) {
                    Text(l10n.proxyStrategyLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PharosColor.textSecondary)

                    HStack(spacing: 2) {
                        proxyPillButton(
                            title: l10n.proxyDirectPill,
                            isSelected: c.proxyStrategy == .direct,
                            color: PharosColor.success
                        ) {
                            applyProxyStrategy(.direct)
                        }

                        proxyPillButton(
                            title: l10n.proxyAPill,
                            isSelected: c.proxyStrategy == .clashMixedPort(7890),
                            color: PharosColor.accent
                        ) {
                            applyProxyStrategy(.clashMixedPort(7890))
                        }

                        proxyPillButton(
                            title: l10n.proxyBPill,
                            isSelected: c.proxyStrategy == .clashMixedPort(7897),
                            color: PharosColor.warning
                        ) {
                            applyProxyStrategy(.clashMixedPort(7897))
                        }

                        proxyPillButton(
                            title: l10n.proxySystemPill,
                            isSelected: c.proxyStrategy == .followSystem,
                            color: PharosColor.textSecondary
                        ) {
                            applyProxyStrategy(.followSystem)
                        }
                    }
                    .padding(2)
                    .background(Capsule(style: .continuous).fill(PharosColor.fill))

                    Spacer()

                    if let r = entry.running {
                        Button {
                            chrome.relaunch(r, with: entry.preset?.config ?? c) {
                                await store.refresh()
                            }
                        } label: {
                            Label(l10n.relaunchWithProxy, systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.pharos)
                        .controlSize(.small)
                    } else {
                        Button {
                            chrome.start(entry.preset?.config ?? c, running: store.chrome, listening: store.state.listeningPorts)
                        } label: {
                            Label(l10n.startWithProxy, systemImage: "play")
                        }
                        .buttonStyle(.pharos)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                        .fill(PharosColor.surfaceSecondary)
                )

                LaunchCommandRow(config: entry.preset?.config ?? c)

                if let preset = entry.preset, let r = entry.running, r.config != preset.config {
                    HStack(spacing: PharosSpacing.xs + 2) {
                        Label(l10n.presetDiffers, systemImage: "arrow.triangle.2.circlepath")
                            .font(PharosFont.caption).foregroundStyle(PharosColor.warning)
                        Button(l10n.updatePreset) { chrome.adopt(r, into: preset.id) }
                            .buttonStyle(.pharos)
                            .controlSize(.mini)
                    }
                }

                ForEach(warnings(c), id: \.self) { w in
                    Label(w, systemImage: "exclamationmark.triangle")
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.warning)
                }

                if let preset = entry.preset, editing == preset.id {
                    ChromePresetEditor(preset: preset) { editing = nil }
                }
            }
        }
    }

    @ViewBuilder
    private func proxyBadge(_ strategy: BrowserProxyStrategy) -> some View {
        switch strategy {
        case .direct:
            Text(l10n.clashModeDirect)
                .font(PharosFont.captionDigits)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(PharosColor.success.opacity(0.13)))
                .foregroundStyle(PharosColor.success)
        case .clashMixedPort(let port):
            Text("Clash :\(String(port))")
                .font(PharosFont.captionDigits)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(PharosColor.accent.opacity(0.13)))
                .foregroundStyle(PharosColor.accent)
        case .custom(let s):
            Text(s)
                .font(PharosFont.captionDigits)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(PharosColor.fill))
                .foregroundStyle(PharosColor.textSecondary)
        case .followSystem:
            EmptyView()
        }
    }

    private func proxyPillButton(title: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5).opacity(isSelected ? 1 : 0.5)
                Text(title)
            }
            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            .padding(.horizontal, 9)
            .frame(minHeight: 22)
            .background(Capsule(style: .continuous).fill(isSelected ? PharosColor.surface : Color.clear))
            .shadow(color: isSelected ? .black.opacity(0.08) : .clear, radius: 1.5, y: 0.5)
            .foregroundStyle(isSelected ? PharosColor.textPrimary : PharosColor.textSecondary)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func applyProxyStrategy(_ strategy: BrowserProxyStrategy) {
        chrome.updateProxyStrategy(strategy, for: entry)
        if let r = entry.running {
            var target = r.config
            target.proxyStrategy = strategy
            chrome.relaunch(r, with: target) {
                await store.refresh()
            }
        }
    }

    /// One visible primary action (Quit while running, Start when stopped); everything
    /// secondary lives in the overflow menu so the header never truncates.
    @ViewBuilder
    private var actions: some View {
        let c = entry.config
        HStack(spacing: PharosSpacing.xs) {
            PharosMoreMenu(help: l10n.moreActions) {
                if let port = c.debugPort, entry.isRunning {
                    Button { chrome.openDevToolsList(port: port) } label: { Label(l10n.openDevToolsList, systemImage: "ladybug") }
                }
                Button { chrome.reveal(c) } label: { Label(l10n.revealInFinder, systemImage: "folder") }
                Button { chrome.copyCommand(entry.preset?.config ?? c) } label: { Label(l10n.copyLaunchCommand, systemImage: "doc.on.doc") }
                if let r = entry.running, entry.preset == nil {
                    Button { chrome.save(r) } label: { Label(l10n.saveChromePreset, systemImage: "star") }
                }
                if let preset = entry.preset {
                    Button { editing = editing == preset.id ? nil : preset.id } label: { Label(l10n.editCommand, systemImage: "pencil") }
                    Divider()
                    Button(role: .destructive) { armedRemove = true } label: {
                        Label(entry.isRunning ? l10n.unsaveChromePreset : l10n.removeFavorite, systemImage: "trash")
                    }
                }
            }
            if armedRemove, let preset = entry.preset {
                PharosConfirmButton(
                    title: entry.isRunning ? l10n.unsaveChromePreset : l10n.removeFavorite,
                    systemImage: "trash",
                    confirmTitle: l10n.removeConfirm
                ) {
                    chrome.remove(id: preset.id)
                    armedRemove = false
                }
            } else if let r = entry.running {
                quitButton(r)
            } else if let preset = entry.preset {
                Button {
                    chrome.start(preset.config, running: store.chrome, listening: store.state.listeningPorts)
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        await store.refresh()
                    }
                } label: {
                    Label(l10n.startChrome, systemImage: "play.fill")
                }
                .buttonStyle(.pharosPrimary)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func quitButton(_ r: ChromeInstance) -> some View {
        if chrome.stubborn.contains(r.id) {
            Button {
                chrome.forceQuit(r, removed: store.removeChromeLocally) { await store.refresh() }
            } label: {
                Label(l10n.forceKill, systemImage: "bolt.fill")
            }
            .buttonStyle(.pharosDestructive)
            .controlSize(.small)
            .help(l10n.stillRunning)
        } else {
            PharosConfirmButton(
                title: l10n.quitChrome,
                systemImage: "power",
                confirmTitle: l10n.quitConfirm,
                workingTitle: l10n.quitting,
                isWorking: chrome.quitting.contains(r.id)
            ) {
                chrome.quit(r, removed: store.removeChromeLocally) { await store.refresh() }
            }
        }
    }

    private func subtitle(_ c: ChromeConfig) -> String {
        var parts: [String] = []
        if c.browser != .chrome { parts.append(c.browser.appName) }
        if let r = entry.running {
            parts.append(ByteFormat.short(r.memoryBytes))
            parts.append(l10n.processCount(r.processCount))
        } else if entry.preset == nil {
            parts.append(l10n.notSaved)
        } else {
            parts.append(l10n.savedStopped)
        }
        return parts.joined(separator: " · ")
    }

    private func row(_ title: String, _ value: String, mono: Bool) -> some View {
        GridRow {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value)
                .font(mono ? .system(size: 10.5, design: .monospaced) : .system(size: 11))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func warnings(_ c: ChromeConfig) -> [String] {
        guard !entry.isRunning else { return [] }
        return ChromeInstances.problems(for: c, running: store.chrome, listeningPorts: store.state.listeningPorts)
            .map { p in
                switch p {
                case .alreadyRunning: return l10n.chromeAlreadyRunning
                case .portInUse(let port): return l10n.portInUse(port)
                case .defaultProfileWithDebugPort: return l10n.defaultProfileDebugWarning
                }
            }
    }

    private func defaultName(_ c: ChromeConfig) -> String {
        if c.isDefaultProfile { return l10n.browserMain(c.browser.appName) }
        return (c.profileKey as NSString).lastPathComponent
    }
}

private struct ChromePresetEditor: View {
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared
    let preset: ChromePreset
    let onDone: () -> Void

    @State private var name = ""
    @State private var browser: ChromiumBrowser = .chrome
    @State private var dir = ""
    @State private var port = ""
    @State private var proxy = ""
    @State private var url = ""
    @State private var flags = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            field(l10n.presetName, $name, "grok 9223")
            HStack {
                Text(l10n.browserTitle).font(.system(size: 10)).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                Picker("", selection: $browser) {
                    // Keep the saved browser selectable even if it was uninstalled.
                    ForEach(ChromiumBrowser.allCases.filter { chrome.isInstalled($0) || $0 == preset.config.browser },
                            id: \.self) { Text($0.appName).tag($0) }
                }
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
                Spacer()
            }
            field(l10n.profileFolder, $dir, "~/chrome-dig")
            field(l10n.debugPort, $port, "9223")
            HStack {
                Text(l10n.proxyStrategyLabel).font(.system(size: 10)).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                Picker("", selection: Binding(
                    get: {
                        if proxy.isEmpty { return "system" }
                        if proxy == "direct://" { return "direct" }
                        if proxy.contains("127.0.0.1") || proxy.contains("localhost") { return "clash" }
                        return "custom"
                    },
                    set: { sel in
                        switch sel {
                        case "system":
                            proxy = ""
                        case "direct":
                            proxy = "direct://"
                            if !flags.contains("--no-proxy-server") {
                                flags = (flags + " --no-proxy-server").trimmingCharacters(in: .whitespaces)
                            }
                        case "clash":
                            proxy = "http://127.0.0.1:7890"
                            flags = flags.replacingOccurrences(of: "--no-proxy-server", with: "").trimmingCharacters(in: .whitespaces)
                        default:
                            break
                        }
                    }
                )) {
                    Text(l10n.proxyFollowSystem).tag("system")
                    Text(l10n.proxyDirect).tag("direct")
                    Text(l10n.proxyClash).tag("clash")
                    Text(l10n.proxyCustom).tag("custom")
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                Spacer()
            }
            field(l10n.proxy, $proxy, "http://127.0.0.1:7890")
            field(l10n.startURL, $url, "https://grok.com")
            field(l10n.extraFlags, $flags, "--no-first-run --no-default-browser-check")
            if let error = validation {
                Text(error).font(.system(size: 10)).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(l10n.cancel, action: onDone).buttonStyle(.pharos).controlSize(.small)
                Button(l10n.save) {
                    var p = preset
                    p.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? preset.name : name
                    let d = dir.trimmingCharacters(in: .whitespaces)
                    p.config = ChromeConfig(
                        browser: browser,
                        userDataDir: d.isEmpty ? nil : d,
                        debugPort: UInt16(port.trimmingCharacters(in: .whitespaces)),
                        proxyServer: proxy.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                        startURL: url.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                        extraFlags: flags.split(whereSeparator: \.isWhitespace).map(String.init))
                    chrome.update(p)
                    onDone()
                }
                .buttonStyle(.pharosPrimary)
                .controlSize(.small)
                .disabled(validation != nil)
            }
        }
        .onAppear {
            name = preset.name
            browser = preset.config.browser
            dir = preset.config.userDataDir ?? ""
            port = preset.config.debugPort.map(String.init) ?? ""
            proxy = preset.config.proxyServer ?? ""
            url = preset.config.startURL ?? ""
            flags = preset.config.extraFlags.joined(separator: " ")
        }
    }

    private var validation: String? {
        let p = port.trimmingCharacters(in: .whitespaces)
        if !p.isEmpty, UInt16(p).map({ $0 >= 1024 }) != true { return l10n.invalidPort }
        if flags.split(whereSeparator: \.isWhitespace).contains(where: { !$0.hasPrefix("-") }) { return l10n.flagsMustStartWithDash }
        return nil
    }

    private func field(_ title: String, _ text: Binding<String>, _ placeholder: String) -> some View {
        HStack {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// The exact launch, shown as a pasteable terminal command. Long commands wrap at argument
/// boundaries (one flag per line) instead of mid-word; copy stays pinned top-right.
private struct LaunchCommandRow: View {
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared
    let config: ChromeConfig
    @State private var copied = false

    var body: some View {
        let command = ChromeInstances.shellCommand(config)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(l10n.launchCommand)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                Spacer()
                Button {
                    chrome.copyCommand(config)
                    copied = true
                } label: {
                    Label(copied ? l10n.copied : l10n.copyLaunchCommand, systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.pharos)
                .controlSize(.mini)
                .task(id: copied) {
                    guard copied else { return }
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            }
            Text(Self.wrapped(command))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(PharosColor.textPrimary.opacity(0.85))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous).fill(PharosColor.surfaceSecondary))
    }

    /// Puts each ` --flag` on its own continuation line (shell-valid with `\`) and keeps
    /// paths unbreakable so lines never split inside a word.
    static func wrapped(_ command: String) -> String {
        // Keep `open -na 'App' --args` together; break before every real flag after it.
        let head: String, tail: String
        if let r = command.range(of: " --args ") {
            head = String(command[..<r.upperBound]).trimmingCharacters(in: .whitespaces)
            tail = String(command[r.upperBound...])
        } else {
            head = ""
            tail = command
        }
        let flags = tail.components(separatedBy: " --").enumerated().map { i, p in i == 0 ? p : "--" + p }
        guard !head.isEmpty else { return command }
        let lines = [head] + flags.map { "  " + $0 }
        return lines.joined(separator: " \\\n")
    }
}

/// Compact Chrome list for the menu-bar popover's Projects tab: running state,
/// port, memory, and start / quit. Editing lives in the main window.
struct PopoverChromeSection: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared
    let entries: [ChromeStore.Entry]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(l10n.chromeTitle).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    AppDelegate.shared?.showMainWindow(selecting: .chrome)
                } label: {
                    Text(l10n.manage).font(.system(size: 10))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            if let message = chrome.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(message).font(.system(size: 10)).lineLimit(2)
                    Spacer()
                    IconButton(systemImage: "xmark", help: l10n.dismiss) { chrome.errorMessage = nil }
                }
                .padding(.horizontal, 8)
            }
            ForEach(entries) { PopoverChromeRow(entry: $0) }
        }
    }
}

private struct PopoverChromeRow: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared
    let entry: ChromeStore.Entry
    @State private var hovering = false

    var body: some View {
        let c = entry.config
        HStack(spacing: 6) {
            RunDot(running: entry.isRunning)
            Text(name(c))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            if c.browser != .chrome, entry.preset != nil || !c.isDefaultProfile {
                Text(c.browser.appName)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            if let port = c.debugPort {
                Text(":\(String(port))")
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.accentColor)
            }
            Spacer(minLength: 4)
            if let r = entry.running {
                Text(ByteFormat.short(r.memoryBytes))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                if let port = c.debugPort {
                    IconButton(systemImage: "ladybug", help: l10n.openDevToolsList) { chrome.openDevToolsList(port: port) }
                }
                if entry.preset == nil {
                    IconButton(systemImage: "star", help: l10n.saveChromePreset) { chrome.save(r) }
                }
                quit(r)
            } else if let preset = entry.preset {
                IconButton(systemImage: "doc.on.doc", help: l10n.copyLaunchCommand) { chrome.copyCommand(preset.config) }
                IconButton(systemImage: "play.fill", help: l10n.startChrome, tint: PharosColor.textPrimary) {
                    chrome.start(preset.config, running: store.chrome, listening: store.state.listeningPorts)
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        await store.refresh()
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: PharosRadius.small + 2, style: .continuous).fill(hovering ? PharosColor.fill.opacity(0.6) : .clear))
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onHover { hovering = $0 }
        .help(c.profileKey)
    }

    @ViewBuilder
    private func quit(_ r: ChromeInstance) -> some View {
        if chrome.stubborn.contains(r.id) {
            Button { chrome.forceQuit(r, removed: store.removeChromeLocally) { await store.refresh() } } label: {
                Label(l10n.forceKill, systemImage: "bolt.fill")
            }
            .buttonStyle(.pharosDestructive)
            .controlSize(.small)
            .help(l10n.stillRunning)
        } else {
            PharosConfirmButton(
                title: l10n.quitChrome,
                systemImage: "power",
                confirmTitle: l10n.quitConfirm,
                workingTitle: l10n.quitting,
                isWorking: chrome.quitting.contains(r.id),
                iconOnly: true
            ) {
                chrome.quit(r, removed: store.removeChromeLocally) { await store.refresh() }
            }
        }
    }

    private func name(_ c: ChromeConfig) -> String {
        if let preset = entry.preset { return preset.name }
        if c.isDefaultProfile { return l10n.browserMain(c.browser.appName) }
        return (c.profileKey as NSString).lastPathComponent
    }
}
