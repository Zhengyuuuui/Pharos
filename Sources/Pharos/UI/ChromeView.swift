import SwiftUI
import PharosCore

/// Main window page: Clash/Mihomo network control center, browser proxy isolation matrix,
/// and Chromium browser instances with live stats, start/quit and configuration.
struct BrowserNetworkView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared
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
        .onAppear { chrome.loadProfileNames(entries.map(\.config.profileKey)) }
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
    @State private var armedQuit = false
    @State private var armedRemove = false

    var body: some View {
        let c = entry.config
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack(alignment: .center, spacing: PharosSpacing.s) {
                    RunDot(running: entry.isRunning)
                    Text(entry.preset?.name ?? defaultName(c))
                        .font(PharosFont.rowLabel)
                        .lineLimit(1)
                    if let port = c.debugPort {
                        Text(":\(String(port))")
                            .font(PharosFont.captionDigits)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(PharosColor.accent.opacity(0.13)))
                            .foregroundStyle(PharosColor.accent)
                    }
                    proxyBadge(c.proxyStrategy)
                    if entry.preset == nil {
                        Text(l10n.notSaved).font(PharosFont.caption).foregroundStyle(PharosColor.textTertiary)
                    } else if !entry.isRunning {
                        Text(l10n.savedStopped).font(PharosFont.caption).foregroundStyle(PharosColor.textTertiary)
                    }
                    Spacer()
                    if let r = entry.running {
                        Text("\(ByteFormat.short(r.memoryBytes)) · \(l10n.processCount(r.processCount))")
                            .font(PharosFont.captionDigits)
                            .foregroundStyle(PharosColor.textSecondary)
                    }
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

                    HStack(spacing: 4) {
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

                    Spacer()

                    if let r = entry.running {
                        Button {
                            chrome.relaunch(r, with: entry.preset?.config ?? c) {
                                await store.refresh()
                            }
                        } label: {
                            Label(l10n.relaunchWithProxy, systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            chrome.start(entry.preset?.config ?? c, running: store.chrome, listening: store.state.listeningPorts)
                        } label: {
                            Label(l10n.startWithProxy, systemImage: "play.fill")
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PharosColor.surfaceSecondary.opacity(0.5))
                )

                LaunchCommandRow(config: entry.preset?.config ?? c)

                if let preset = entry.preset, let r = entry.running, r.config != preset.config {
                    HStack(spacing: PharosSpacing.xs + 2) {
                        Label(l10n.presetDiffers, systemImage: "arrow.triangle.2.circlepath")
                            .font(PharosFont.caption).foregroundStyle(PharosColor.warning)
                        Button(l10n.updatePreset) { chrome.adopt(r, into: preset.id) }
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
            Text("Clash :\(port)")
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
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(isSelected ? color.opacity(0.18) : PharosColor.fill.opacity(0.4))
                )
                .overlay(
                    Capsule().stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? color : PharosColor.textSecondary)
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

    @ViewBuilder
    private var actions: some View {
        let c = entry.config
        HStack(spacing: 4) {
            if let port = c.debugPort, entry.isRunning {
                IconButton(systemImage: "ladybug", help: l10n.openDevToolsList) { chrome.openDevToolsList(port: port) }
            }
            IconButton(systemImage: "folder", help: l10n.revealInFinder) { chrome.reveal(c) }
            if let r = entry.running {
                if let preset = entry.preset {
                    IconButton(systemImage: "star.fill", help: l10n.unsaveChromePreset, tint: .yellow) {
                        chrome.remove(id: preset.id)
                    }
                } else {
                    IconButton(systemImage: "star", help: l10n.saveChromePreset, tint: .secondary) { chrome.save(r) }
                }
                quitButton(r)
            } else if let preset = entry.preset {
                IconButton(systemImage: "pencil", help: l10n.editCommand) {
                    editing = editing == preset.id ? nil : preset.id
                }
                if armedRemove {
                    Button(l10n.removeFavorite) { chrome.remove(id: preset.id) }
                        .buttonStyle(.pharosDestructive).controlSize(.small)
                    IconButton(systemImage: "xmark", help: l10n.cancel) { armedRemove = false }
                } else {
                    IconButton(systemImage: "trash", help: l10n.removeFavorite) { armedRemove = true }
                }
                Button {
                    chrome.start(preset.config, running: store.chrome, listening: store.state.listeningPorts)
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        await store.refresh()
                    }
                } label: {
                    Label(l10n.startChrome, systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func quitButton(_ r: ChromeInstance) -> some View {
        if chrome.stubborn.contains(r.id) {
            Button(l10n.forceKill) { chrome.forceQuit(r) { await store.refresh() } }
                .buttonStyle(.pharosDestructive).controlSize(.small)
                .help(l10n.stillRunning)
        } else if armedQuit {
            Button(l10n.quitChrome) {
                armedQuit = false
                chrome.quit(r) { await store.refresh() }
            }
            .buttonStyle(.pharosDestructive).controlSize(.small)
            IconButton(systemImage: "xmark", help: l10n.cancel) { armedQuit = false }
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    armedQuit = false
                }
        } else {
            Button(role: .destructive) { armedQuit = true } label: {
                Label(l10n.quitChrome, systemImage: "power")
            }
            .buttonStyle(.pharosDestructive)
            .controlSize(.small)
        }
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
                Button(l10n.cancel, action: onDone).controlSize(.small)
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
                .buttonStyle(.borderedProminent)
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

/// The exact launch, shown as a pasteable terminal command.
private struct LaunchCommandRow: View {
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared
    let config: ChromeConfig
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(l10n.launchCommand).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(ChromeInstances.shellCommand(config))
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            IconButton(systemImage: copied ? "checkmark" : "doc.on.doc",
                       help: copied ? l10n.copied : l10n.copyLaunchCommand,
                       tint: copied ? .green : .secondary) {
                chrome.copyCommand(config)
                copied = true
            }
            .task(id: copied) {
                guard copied else { return }
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill((Color.primary as Color).opacity(0.04)))
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
    @State private var armed = false
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
                IconButton(systemImage: "play.fill", help: l10n.startChrome, tint: .green) {
                    chrome.start(preset.config, running: store.chrome, listening: store.state.listeningPorts)
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        await store.refresh()
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.05) : .clear))
        .onHover { hovering = $0 }
        .help(c.profileKey)
    }

    @ViewBuilder
    private func quit(_ r: ChromeInstance) -> some View {
        if chrome.stubborn.contains(r.id) {
            Button(l10n.forceKill) { chrome.forceQuit(r) { await store.refresh() } }
                .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
        } else if armed {
            HStack(spacing: 4) {
                Button(l10n.quitChrome) {
                    armed = false
                    chrome.quit(r) { await store.refresh() }
                }
                .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
                IconButton(systemImage: "xmark", help: l10n.cancel) { armed = false }
            }
            .task {
                try? await Task.sleep(for: .seconds(4))
                armed = false
            }
        } else {
            IconButton(systemImage: "power", help: l10n.quitChrome, tint: .red.opacity(0.8)) { armed = true }
        }
    }

    private func name(_ c: ChromeConfig) -> String {
        if let preset = entry.preset { return preset.name }
        if c.isDefaultProfile { return l10n.browserMain(c.browser.appName) }
        return (c.profileKey as NSString).lastPathComponent
    }
}
