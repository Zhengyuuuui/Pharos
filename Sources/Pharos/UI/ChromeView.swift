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
    @ObservedObject private var clash = ClashStore.shared
    @ObservedObject private var l10n = L10n.shared
    let entry: ChromeStore.Entry
    @Binding var editing: String?
    @State private var armedRemove = false
    @State private var showCustomProxyPrompt = false
    @State private var customProxyInput = ""
    @State private var hotSwitchToast: String? = nil
    @State private var showRelaunchAlert = false
    @State private var pendingRelaunchTarget: ChromeConfig? = nil
    @State private var pendingRelaunchModeName: String = ""
    @State private var showNodePopover = false

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
                    row(l10n.proxy, c.proxyServer ?? l10n.proxyFollowSystemDesc, mono: c.proxyServer != nil)
                    if let url = c.startURL { row(l10n.startURL, url, mono: true) }
                    let accounts = chrome.profileNames[c.profileKey] ?? []
                    if !accounts.isEmpty { row(l10n.chromeAccounts, accounts.joined(separator: ", "), mono: false) }
                    if let size = chrome.folderSizes[c.profileKey] {
                        row(l10n.folderSize, ByteFormat.short(size), mono: false)
                    }
                    if !c.extraFlags.isEmpty { row(l10n.extraFlags, c.extraFlags.joined(separator: " "), mono: true) }
                }

                // Startup & Proxy Mode Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(l10n.proxyModeBarTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PharosColor.textSecondary)

                        if isNodeSelected(c) {
                            Text(":\(c.dedicatedProxyPort)")
                                .font(PharosFont.captionDigits)
                                .foregroundStyle(PharosColor.textTertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(PharosColor.fill))
                                .help("Dedicated Proxy Port: \(c.dedicatedProxyPort)")
                        }

                        Spacer()

                        if let toast = hotSwitchToast {
                            Text(toast)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PharosColor.success)
                                .transition(.opacity)
                        }

                        if entry.isRunning {
                            Button {
                                requestRelaunch(target: entry.config, modeName: modeDisplayName(entry.config))
                            } label: {
                                Label(l10n.relaunchWithProxy, systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.pharos)
                            .controlSize(.small)
                        } else {
                            Button {
                                chrome.startWithNodeCheck(entry.config, running: store.chrome, listening: store.state.listeningPorts)
                            } label: {
                                Label(l10n.startWithProxy, systemImage: "play.fill")
                            }
                            .buttonStyle(.pharosPrimary)
                            .controlSize(.small)
                        }
                    }

                    // 5 Mode Pills Bar
                    HStack(spacing: 6) {
                        // 1. 跟随系统 (Follow System)
                        modePill(
                            title: l10n.proxySystemPill,
                            icon: "arrow.triangle.2.circlepath",
                            isSelected: isFollowSystem(c),
                            activeColor: Color.blue
                        ) {
                            applyProxyFollowSystem(c)
                        }

                        // 2. 纯净直连 (Pure Direct)
                        modePill(
                            title: l10n.proxyDirectPill,
                            icon: "bolt.fill",
                            isSelected: isPureDirect(c),
                            activeColor: PharosColor.success
                        ) {
                            applyProxyDirect(c)
                        }

                        // 3. Clash 规则代理 (Clash Mixed Port)
                        let clashPort = clash.snapshot.mixedPort > 0 ? clash.snapshot.mixedPort : 7890
                        modePill(
                            title: "\(l10n.proxyClashPill) (:\(clashPort))",
                            icon: "shield.checkerboard",
                            isSelected: isClashMixed(c),
                            activeColor: PharosColor.accent
                        ) {
                            applyProxyClashMixed(c)
                        }

                        // 4. 出口节点 (Node Selection Menu)
                        nodeMenuPill(c)

                        // 5. 自定义代理 (Custom Proxy)
                        customProxyPill(c)

                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                        .fill(PharosColor.surfaceSecondary)
                )

                LaunchCommandRow(config: entry.config)

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
        .alert(l10n.customProxyPrompt, isPresented: $showCustomProxyPrompt) {
            TextField(l10n.customProxyHint, text: $customProxyInput)
            Button(l10n.save) {
                let trimmed = customProxyInput.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    applyCustomProxy(trimmed)
                }
            }
            Button(l10n.cancel, role: .cancel) {}
        }
        .alert(l10n.relaunchBrowserTitle, isPresented: $showRelaunchAlert) {
            Button(l10n.cancel, role: .cancel) {
                pendingRelaunchTarget = nil
                pendingRelaunchModeName = ""
            }
            Button(l10n.relaunchNow, role: .destructive) {
                if let target = pendingRelaunchTarget {
                    confirmAndExecuteRelaunch(target: target)
                }
            }
        } message: {
            Text(l10n.relaunchBrowserMessage(pendingRelaunchModeName))
        }
    }

    private func isFollowSystem(_ c: ChromeConfig) -> Bool {
        if case .followSystem = c.proxyStrategy { return true }
        return false
    }

    private func isPureDirect(_ c: ChromeConfig) -> Bool {
        return c.proxyStrategy.isDirect
    }

    private func isClashMixed(_ c: ChromeConfig) -> Bool {
        if case .clashMixedPort = c.proxyStrategy { return true }
        return false
    }

    private func isNodeSelected(_ c: ChromeConfig) -> Bool {
        if case .node(let name, _) = c.proxyStrategy {
            return name != "DIRECT"
        }
        return false
    }

    private func isCustomSelected(_ c: ChromeConfig) -> Bool {
        if case .custom = c.proxyStrategy { return true }
        return false
    }

    private func currentNodeTitle(_ c: ChromeConfig) -> String {
        if case .node(let name, _) = c.proxyStrategy {
            if name != "DIRECT" {
                return name
            }
        }
        if let name = c.proxyNodeName, !name.isEmpty, name != "DIRECT" {
            return name
        }
        return l10n.proxyExitNode
    }

    private func modePill(
        title: String,
        icon: String,
        isSelected: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? activeColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? activeColor : PharosColor.textSecondary)
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? PharosColor.textPrimary : PharosColor.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? activeColor.opacity(0.12) : PharosColor.fill)
            )
        }
        .buttonStyle(.plain)
    }

    private func nodeMenuPill(_ c: ChromeConfig) -> some View {
        let isSelected = isNodeSelected(c)
        return Button {
            showNodePopover = true
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? PharosColor.accent : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? PharosColor.accent : PharosColor.textSecondary)
                Text(currentNodeTitle(c))
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? PharosColor.textPrimary : PharosColor.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7))
                    .foregroundStyle(PharosColor.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? PharosColor.accent.opacity(0.12) : PharosColor.fill)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .popover(isPresented: $showNodePopover, arrowEdge: .bottom) {
            NodePickerPopover(
                config: c,
                currentNode: currentNodeTitle(c),
                onSelect: { nodeName in
                    showNodePopover = false
                    applyProxyNode(nodeName, config: c)
                }
            )
        }
    }

    private func customProxyPill(_ c: ChromeConfig) -> some View {
        let isSelected = isCustomSelected(c)
        return Button {
            customProxyInput = c.proxyServer ?? ""
            showCustomProxyPrompt = true
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? PharosColor.accent : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? PharosColor.accent : PharosColor.textSecondary)
                Text(isSelected ? (c.proxyServer ?? l10n.proxyCustomPill) : l10n.proxyCustomPill)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? PharosColor.textPrimary : PharosColor.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? PharosColor.accent.opacity(0.12) : PharosColor.fill)
            )
        }
        .buttonStyle(.plain)
    }

    private func modeDisplayName(_ c: ChromeConfig) -> String {
        switch c.proxyStrategy {
        case .followSystem:
            return l10n.proxySystemPill
        case .direct:
            return l10n.proxyDirectPill
        case .clashMixedPort(let port):
            return "\(l10n.proxyClashPill) (:\(port))"
        case .node(let name, _):
            return name
        case .custom(let s):
            return s
        }
    }

    private func requestRelaunch(target: ChromeConfig, modeName: String) {
        pendingRelaunchTarget = target
        pendingRelaunchModeName = modeName
        showRelaunchAlert = true
    }

    private func confirmAndExecuteRelaunch(target: ChromeConfig) {
        guard let r = entry.running else { return }
        chrome.updateProxyStrategy(target.proxyStrategy, for: entry)
        Task {
            if case .node(let name, _) = target.proxyStrategy, clash.snapshot.isRunning {
                try? await clash.ensureInstanceListener(config: target)
                _ = await clash.switchProxy(groupName: target.dedicatedGroupName, nodeName: name)
            }
            chrome.relaunch(r, with: target) {
                await store.refresh()
            }
            let modeName = modeDisplayName(target)
            withAnimation { hotSwitchToast = l10n.relaunchSuccessToast(modeName) }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { hotSwitchToast = nil }
        }
    }

    private func applyProxyFollowSystem(_ c: ChromeConfig) {
        let strategy = BrowserProxyStrategy.followSystem
        if let r = entry.running {
            if case .followSystem = r.config.proxyStrategy { return }
            var target = r.config
            target.proxyStrategy = strategy
            requestRelaunch(target: target, modeName: l10n.proxySystemPill)
        } else {
            chrome.updateProxyStrategy(strategy, for: entry)
        }
    }

    private func applyProxyDirect(_ c: ChromeConfig) {
        let strategy = BrowserProxyStrategy.direct
        if let r = entry.running {
            if r.config.proxyStrategy.isDirect { return }
            var target = r.config
            target.proxyStrategy = strategy
            requestRelaunch(target: target, modeName: l10n.proxyDirectPill)
        } else {
            chrome.updateProxyStrategy(strategy, for: entry)
        }
    }

    private func applyProxyClashMixed(_ c: ChromeConfig) {
        let port = clash.snapshot.mixedPort > 0 ? clash.snapshot.mixedPort : 7890
        let strategy = BrowserProxyStrategy.clashMixedPort(port)
        if let r = entry.running {
            if case .clashMixedPort(let p) = r.config.proxyStrategy, p == port { return }
            var target = r.config
            target.proxyStrategy = strategy
            requestRelaunch(target: target, modeName: "\(l10n.proxyClashPill) (:\(port))")
        } else {
            chrome.updateProxyStrategy(strategy, for: entry)
        }
    }

    private func applyProxyNode(_ name: String, config: ChromeConfig) {
        let port = config.dedicatedProxyPort
        let strategy = BrowserProxyStrategy.node(name: name, port: port)
        if let r = entry.running {
            let isAlreadyOnDedicatedPort = r.config.proxyServer == "http://127.0.0.1:\(port)"
            if isAlreadyOnDedicatedPort && clash.snapshot.isRunning {
                // Hot-switch in Mihomo without browser restart!
                chrome.updateProxyStrategy(strategy, for: entry)
                Task {
                    let ok = await clash.switchProxy(groupName: config.dedicatedGroupName, nodeName: name)
                    if ok {
                        withAnimation { hotSwitchToast = l10n.proxyNodeSwitchedToast(name, port) }
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { hotSwitchToast = nil }
                    }
                }
            } else {
                // Switching from another mode requires restarting Chrome with proxy flags
                var target = r.config
                target.proxyStrategy = strategy
                target.proxyNodeName = name
                requestRelaunch(target: target, modeName: name)
            }
        } else {
            chrome.updateProxyStrategy(strategy, for: entry)
        }
    }

    private func applyCustomProxy(_ proxyUrl: String) {
        let strategy = BrowserProxyStrategy.custom(proxyUrl)
        if let r = entry.running {
            if case .custom(let cur) = r.config.proxyStrategy, cur == proxyUrl { return }
            var target = r.config
            target.proxyStrategy = strategy
            requestRelaunch(target: target, modeName: proxyUrl)
        } else {
            chrome.updateProxyStrategy(strategy, for: entry)
        }
    }

    @ViewBuilder
    private func proxyBadge(_ strategy: BrowserProxyStrategy) -> some View {
        switch strategy {
        case .direct:
            Text(l10n.proxyDirectPill)
                .font(PharosFont.captionDigits)
                .padding(.horizontal, 6).padding(.vertical, 1.5)
                .background(Capsule().fill(PharosColor.success.opacity(0.13)))
                .foregroundStyle(PharosColor.success)
        case .node(let name, let port):
            if name == "DIRECT" {
                Text(l10n.proxyDirectPill)
                    .font(PharosFont.captionDigits)
                    .padding(.horizontal, 6).padding(.vertical, 1.5)
                    .background(Capsule().fill(PharosColor.success.opacity(0.13)))
                    .foregroundStyle(PharosColor.success)
            } else {
                Text("\(name) :\(port)")
                    .font(PharosFont.captionDigits)
                    .padding(.horizontal, 6).padding(.vertical, 1.5)
                    .background(Capsule().fill(PharosColor.accent.opacity(0.13)))
                    .foregroundStyle(PharosColor.accent)
            }
        case .clashMixedPort(let port):
            Text("Clash :\(String(port))")
                .font(PharosFont.captionDigits)
                .padding(.horizontal, 6).padding(.vertical, 1.5)
                .background(Capsule().fill(PharosColor.accent.opacity(0.13)))
                .foregroundStyle(PharosColor.accent)
        case .custom(let s):
            Text(s)
                .font(PharosFont.captionDigits)
                .padding(.horizontal, 6).padding(.vertical, 1.5)
                .background(Capsule().fill(PharosColor.fill))
                .foregroundStyle(PharosColor.textSecondary)
        case .followSystem:
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 8, weight: .semibold))
                Text(l10n.proxySystemPill)
            }
            .font(PharosFont.captionDigits)
            .padding(.horizontal, 6).padding(.vertical, 1.5)
            .background(Capsule().fill(Color.blue.opacity(0.14)))
            .foregroundStyle(Color.blue)
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
                Button { chrome.copyCommand(entry.config) } label: { Label(l10n.copyLaunchCommand, systemImage: "doc.on.doc") }
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
            } else if entry.preset != nil {
                Button {
                    chrome.startWithNodeCheck(entry.config, running: store.chrome, listening: store.state.listeningPorts)
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
    @State private var nodeName = ""
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
                        if !nodeName.isEmpty { return "node" }
                        if proxy.contains("127.0.0.1") || proxy.contains("localhost") { return "clash" }
                        return "custom"
                    },
                    set: { sel in
                        switch sel {
                        case "system":
                            proxy = ""
                            nodeName = ""
                        case "direct":
                            proxy = "direct://"
                            nodeName = ""
                            if !flags.contains("--no-proxy-server") {
                                flags = (flags + " --no-proxy-server").trimmingCharacters(in: .whitespaces)
                            }
                        case "clash":
                            let clashPort = ClashStore.shared.snapshot.mixedPort > 0 ? ClashStore.shared.snapshot.mixedPort : 7890
                            proxy = "http://127.0.0.1:\(clashPort)"
                            nodeName = ""
                            flags = flags.replacingOccurrences(of: "--no-proxy-server", with: "").trimmingCharacters(in: .whitespaces)
                        case "node":
                            let dp = preset.config.dedicatedProxyPort
                            proxy = "http://127.0.0.1:\(dp)"
                            if nodeName.isEmpty {
                                nodeName = ClashStore.shared.nodes.first?.name ?? "DIRECT"
                            }
                            flags = flags.replacingOccurrences(of: "--no-proxy-server", with: "").trimmingCharacters(in: .whitespaces)
                        default:
                            break
                        }
                    }
                )) {
                    Text(l10n.proxyFollowSystem).tag("system")
                    Text(l10n.proxyDirect).tag("direct")
                    Text(l10n.proxyClash).tag("clash")
                    Text(l10n.proxyNodeOption).tag("node")
                    Text(l10n.proxyCustom).tag("custom")
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                Spacer()
            }
            if !nodeName.isEmpty {
                HStack {
                    Text(l10n.proxyExitNode).font(.system(size: 10)).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                    Picker("", selection: $nodeName) {
                        if ClashStore.shared.nodes.isEmpty {
                            Text(nodeName.isEmpty ? "DIRECT" : nodeName).tag(nodeName.isEmpty ? "DIRECT" : nodeName)
                        } else {
                            ForEach(ClashStore.shared.nodes) { n in
                                Text(n.name).tag(n.name)
                            }
                        }
                    }
                    .controlSize(.small)
                    Spacer()
                }
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
                        proxyNodeName: nodeName.trimmingCharacters(in: .whitespaces).nilIfEmpty,
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
            nodeName = preset.config.proxyNodeName ?? ""
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
            } else if entry.preset != nil {
                IconButton(systemImage: "doc.on.doc", help: l10n.copyLaunchCommand) { chrome.copyCommand(entry.config) }
                IconButton(systemImage: "play.fill", help: l10n.startChrome, tint: PharosColor.textPrimary) {
                    chrome.startWithNodeCheck(entry.config, running: store.chrome, listening: store.state.listeningPorts)
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
