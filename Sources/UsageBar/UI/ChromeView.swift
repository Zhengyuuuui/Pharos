import SwiftUI
import UsageBarCore

/// Main window page: every Chrome instance (running or saved preset) with
/// port, profile folder, proxy, memory, folder size, start/quit and editing.
struct ChromeView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var editing: String?

    var body: some View {
        let entries = chrome.entries(store.chrome)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.chromeTitle).font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button {
                        chrome.measureSizes(Array(Set(entries.map(\.config.profileKey))))
                    } label: {
                        Label(chrome.sizing ? l10n.measuring : l10n.measureFolders, systemImage: "internaldrive")
                    }
                    .controlSize(.small)
                    .disabled(chrome.sizing)
                    Button { editing = chrome.addPreset() } label: {
                        Label(l10n.newChromePreset, systemImage: "plus")
                    }
                    .controlSize(.small)
                }

                HStack(spacing: 12) {
                    StatCard(title: l10n.chromeRunning, value: "\(store.chrome.count)", icon: "globe")
                    StatCard(title: l10n.chromePresets, value: "\(chrome.presets.count)", icon: "star")
                    StatCard(title: l10n.memory,
                             value: ByteFormat.short(store.chrome.reduce(0) { $0 + $1.memoryBytes }),
                             icon: "memorychip")
                }

                if let message = chrome.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(message).font(.system(size: 11)).textSelection(.enabled)
                        Spacer()
                        IconButton(systemImage: "xmark", help: l10n.dismiss) { chrome.errorMessage = nil }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.1)))
                }

                if !chrome.chromeInstalled {
                    Label(l10n.chromeNotInstalled, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else if entries.isEmpty {
                    ContentUnavailableView(l10n.chromeEmpty, systemImage: "globe",
                                           description: Text(l10n.chromeEmptyDesc))
                        .frame(height: 180)
                }

                ForEach(entries) { entry in
                    ChromeCard(entry: entry, editing: $editing)
                }

                Text(l10n.chromeNotice)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                RunDot(running: entry.isRunning)
                Text(entry.preset?.name ?? defaultName(c))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                if let port = c.debugPort {
                    Text(":\(String(port))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor.opacity(0.13)))
                        .foregroundStyle(Color.accentColor)
                }
                if entry.preset == nil {
                    Text(l10n.notSaved).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                Spacer()
                if let r = entry.running {
                    Text("\(ByteFormat.short(r.memoryBytes)) · \(l10n.processCount(r.processCount))")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                actions
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                row(l10n.profileFolder, c.isDefaultProfile ? l10n.defaultProfile : c.profileKey, mono: !c.isDefaultProfile)
                if let proxy = c.proxyServer { row(l10n.proxy, proxy, mono: true) }
                if let url = c.startURL { row(l10n.startURL, url, mono: true) }
                let accounts = ChromeInstances.profileNames(in: c.profileKey)
                if !accounts.isEmpty { row(l10n.chromeAccounts, accounts.joined(separator: ", "), mono: false) }
                if let size = chrome.folderSizes[c.profileKey] {
                    row(l10n.folderSize, ByteFormat.short(size), mono: false)
                }
                if !c.extraFlags.isEmpty { row(l10n.extraFlags, c.extraFlags.joined(separator: " "), mono: true) }
            }

            ForEach(warnings(c), id: \.self) { w in
                Label(w, systemImage: "exclamationmark.triangle").font(.system(size: 10)).foregroundStyle(.orange)
            }

            if let preset = entry.preset, editing == preset.id {
                ChromePresetEditor(preset: preset) { editing = nil }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(entry.isRunning ? 0.05 : 0.025)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.06)))
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
                if entry.preset == nil {
                    IconButton(systemImage: "star", help: l10n.saveChromePreset, tint: .secondary) { chrome.save(r) }
                }
                quitButton(r)
            } else if let preset = entry.preset {
                IconButton(systemImage: "pencil", help: l10n.editCommand) {
                    editing = editing == preset.id ? nil : preset.id
                }
                if armedRemove {
                    Button(l10n.removeFavorite) { chrome.remove(id: preset.id) }
                        .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
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
                .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
                .help(l10n.stillRunning)
        } else if armedQuit {
            Button(l10n.quitChrome) {
                armedQuit = false
                chrome.quit(r) { await store.refresh() }
            }
            .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
            IconButton(systemImage: "xmark", help: l10n.cancel) { armedQuit = false }
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    armedQuit = false
                }
        } else {
            Button(role: .destructive) { armedQuit = true } label: {
                Label(l10n.quitChrome, systemImage: "power")
            }
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
        if c.isDefaultProfile { return l10n.chromeMain }
        return (c.profileKey as NSString).lastPathComponent
    }
}

private struct ChromePresetEditor: View {
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared
    let preset: ChromePreset
    let onDone: () -> Void

    @State private var name = ""
    @State private var dir = ""
    @State private var port = ""
    @State private var proxy = ""
    @State private var url = ""
    @State private var flags = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            field(l10n.presetName, $name, "grok 9223")
            field(l10n.profileFolder, $dir, "~/chrome-dig")
            field(l10n.debugPort, $port, "9223")
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
                quit(r)
            } else if let preset = entry.preset {
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
        if c.isDefaultProfile { return l10n.chromeMain }
        return (c.profileKey as NSString).lastPathComponent
    }
}
