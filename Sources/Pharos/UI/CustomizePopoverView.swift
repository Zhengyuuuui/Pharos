import SwiftUI
import UniformTypeIdentifiers
import PharosCore

/// Main window → Customize: edit the popover like widgets. Blocks are dragged
/// between the two tab columns and the library; the left side is the real
/// popover content rendered at popover width, so it's an exact live snapshot.
struct CustomizePopoverView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var previewTab: PopoverTab = .overview
    @State private var armedReset = false

    var body: some View {
        let layout = layoutStore.layout
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.customizeTitle).font(.system(size: 20, weight: .bold))
                    Spacer()
                    if armedReset {
                        Button(l10n.resetLayout) { armedReset = false; layoutStore.reset() }
                            .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
                        IconButton(systemImage: "xmark", help: l10n.cancel) { armedReset = false }
                    } else {
                        Button(l10n.resetLayout) { armedReset = true }
                            .controlSize(.small)
                            .disabled(layout == .standard)
                    }
                }
                Text(l10n.customizeIntro)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 20) {
                    PopoverSnapshot(layout: layout, tab: $previewTab)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(PopoverTab.allCases, id: \.self) { tab in
                                TabColumn(tab: tab, blocks: layout[tab], selected: previewTab == tab) {
                                    previewTab = tab
                                }
                            }
                        }
                        LibraryColumn(unused: layout.unused)
                        ProjectRowsSettings(blockInUse: layout.tab(of: .projects) != nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Live snapshot

private struct PopoverSnapshot: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let layout: PopoverLayout
    @Binding var tab: PopoverTab

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.appTitle).font(.system(size: 14, weight: .bold))
                Spacer()
                Text(l10n.summary(projects: store.projects.count, memory: ByteFormat.short(store.totalMemory)))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            // The picker stays clickable so both tabs can be previewed; the
            // blocks themselves are inert (no stopping projects from a preview).
            PopoverTabsContent(layout: layout, tab: $tab, interactive: false)
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.12)))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    /// Fixed footer rows, dimmed so the snapshot reads as the whole popover.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(l10n.refreshNow, systemImage: "arrow.clockwise")
            Label(l10n.diskCleanup, systemImage: "trash")
            Label(l10n.customizePopover, systemImage: "square.grid.2x2")
            Label(l10n.settingsEllipsis, systemImage: "gearshape")
        }
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 8)
    }
}

// MARK: - Editor columns

private struct TabColumn: View {
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @ObservedObject private var l10n = L10n.shared
    let tab: PopoverTab
    let blocks: [PopoverBlock]
    let selected: Bool
    let onSelect: () -> Void
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            ForEach(blocks, id: \.self) { block in
                tile(block)
            }
            dropTail
        }
        .padding(10)
        .frame(minWidth: 200, maxWidth: .infinity, alignment: .topLeading)
        .background(background)
        .overlay(border)
    }

    private var header: some View {
        Button(action: onSelect) {
            HStack {
                Text(l10n.popoverTabName(tab)).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(blocks.count)").font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tile(_ block: PopoverBlock) -> some View {
        BlockTile(block: block, inTab: tab, isFirst: block == blocks.first, isLast: block == blocks.last)
            .onDrop(of: [UTType.text], delegate: BlockDropDelegate(tab: tab, before: block))
    }

    /// Empty tail: drop here to append.
    private var dropTail: some View {
        let color: Color = targeted ? .accentColor : Color.secondary.opacity(0.4)
        return RoundedRectangle(cornerRadius: 8)
            .strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: [4]))
            .frame(height: blocks.isEmpty ? 70 : 34)
            .overlay(Text(l10n.dropHere).font(.system(size: 10)).foregroundStyle(.tertiary))
            .onDrop(of: [UTType.text], isTargeted: $targeted) { providers in
                append(providers)
            }
    }

    private func append(_ providers: [NSItemProvider]) -> Bool {
        let t = tab
        return BlockDrag.load(providers) { store, block in store.update { $0.insert(block, into: t) } }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(selected ? 0.06 : 0.03))
    }

    private var border: some View {
        let color: Color = selected ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.06)
        return RoundedRectangle(cornerRadius: 10).stroke(color)
    }
}

private struct LibraryColumn: View {
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @ObservedObject private var l10n = L10n.shared
    let unused: [PopoverBlock]
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            content
        }
        .padding(10)
        .background(background)
        .overlay(border)
        .onDrop(of: [UTType.text], isTargeted: $targeted) { providers in
            remove(providers)
        }
    }

    private var header: some View {
        HStack {
            Label(l10n.componentLibrary, systemImage: "square.grid.2x2").font(.system(size: 12, weight: .semibold))
            Spacer()
            Text(l10n.dropToRemove).font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if unused.isEmpty {
            Text(l10n.libraryEmpty).font(.system(size: 11)).foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, minHeight: 40)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], spacing: 8) {
                ForEach(unused, id: \.self) { block in
                    BlockTile(block: block, inTab: nil, isFirst: true, isLast: true)
                }
            }
        }
    }

    private func remove(_ providers: [NSItemProvider]) -> Bool {
        BlockDrag.load(providers) { store, block in store.update { $0.remove(block) } }
    }

    private var background: some View {
        let color: Color = targeted ? Color.red.opacity(0.08) : Color.primary.opacity(0.03)
        return RoundedRectangle(cornerRadius: 10).fill(color)
    }

    private var border: some View {
        let color: Color = targeted ? Color.red.opacity(0.6) : Color.secondary.opacity(0.3)
        let dash: [CGFloat] = targeted ? [] : [4]
        return RoundedRectangle(cornerRadius: 10).strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: dash))
    }
}

/// A draggable block card. Buttons give the same edits without dragging.
private struct BlockTile: View {
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @ObservedObject private var l10n = L10n.shared
    let block: PopoverBlock
    /// nil = in the library.
    let inTab: PopoverTab?
    let isFirst: Bool
    let isLast: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal").font(.system(size: 10)).foregroundStyle(.tertiary)
                Image(systemName: block.icon).font(.system(size: 13)).foregroundStyle(Color.accentColor).frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l10n.blockName(block)).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(l10n.blockDescription(block)).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                if hovering { actions }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(hovering ? 0.15 : 0.08)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(object: block.rawValue as NSString) } preview: {
            Label(l10n.blockName(block), systemImage: block.icon)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))
        }
    }

    @ViewBuilder
    private var actions: some View {
        if inTab != nil {
            IconButton(systemImage: "chevron.up", help: l10n.moveUp) { layoutStore.update { $0.move(block, by: -1) } }
                .disabled(isFirst)
            IconButton(systemImage: "chevron.down", help: l10n.moveDown) { layoutStore.update { $0.move(block, by: 1) } }
                .disabled(isLast)
            IconButton(systemImage: "minus.circle", help: l10n.removeBlock, tint: .red.opacity(0.8)) {
                layoutStore.update { $0.remove(block) }
            }
        } else {
            Menu {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    Button(l10n.addTo(l10n.popoverTabName(tab))) { layoutStore.update { $0.insert(block, into: tab) } }
                }
            } label: {
                Image(systemName: "plus.circle.fill").foregroundStyle(.green)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

// MARK: - Running-projects row limit

/// Below the library: how many running projects the popover shows before the
/// list scrolls. Range 3 … number of projects running right now.
private struct ProjectRowsSettings: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @ObservedObject private var l10n = L10n.shared
    let blockInUse: Bool
    @State private var text = ""
    @FocusState private var focused: Bool

    private var upper: Int { max(PopoverLayout.minProjectRows, store.projects.count) }
    /// Saved value; 0 (older "show all") is shown as the current maximum.
    private var current: Int {
        let v = layoutStore.layout.visibleProjectRows
        return v == 0 ? upper : v
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(l10n.projectRowsTitle, systemImage: "arrow.up.and.down.text.horizontal")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(l10n.projectRowsRange(PopoverLayout.minProjectRows, upper, running: store.projects.count))
                    .font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { n in
                    Button { set(n) } label: {
                        Text(n == upper && !PopoverLayout.projectRowChoices.contains(n) ? l10n.rowsAll(n) : "\(n)")
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Capsule().fill(n == current ? Color.accentColor : Color.primary.opacity(0.07)))
                            .foregroundStyle(n == current ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 8)
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                    .focused($focused)
                    .onSubmit { commit() }
                    .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
                Stepper("", value: Binding(get: { current }, set: { set($0) }),
                        in: PopoverLayout.minProjectRows...upper)
                    .labelsHidden()
                Text(l10n.projectsUnit).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06)))
        .opacity(blockInUse ? 1 : 0.6)
        .onAppear { text = "\(current)" }
        .onChange(of: current) { _, v in if !focused { text = "\(v)" } }
    }

    /// Fixed presets that fit, plus the current maximum ("all running").
    private var presets: [Int] {
        var list = PopoverLayout.projectRowChoices.filter { $0 <= upper }
        if !list.contains(upper) { list.append(upper) }
        return list
    }

    private func set(_ n: Int) {
        let v = min(max(n, PopoverLayout.minProjectRows), upper)
        layoutStore.update { $0.visibleProjectRows = v }
        text = "\(v)"
    }

    /// Invalid input snaps back to the saved value; out-of-range is clamped.
    private func commit() {
        if let n = Int(text.trimmingCharacters(in: .whitespaces)) { set(n) } else { text = "\(current)" }
    }
}

// MARK: - Drag & drop

private enum BlockDrag {
    /// Drag payload is the block's raw name as plain text.
    @MainActor
    static func load(_ providers: [NSItemProvider], perform: @escaping @MainActor (PopoverLayoutStore, PopoverBlock) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let raw = item as? String, let block = PopoverBlock(rawValue: raw) else { return }
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.18)) { perform(PopoverLayoutStore.shared, block) }
            }
        }
        return true
    }
}

/// Dropping onto a tile inserts before it.
private struct BlockDropDelegate: DropDelegate {
    let tab: PopoverTab
    let before: PopoverBlock

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [UTType.text])
        return MainActor.assumeIsolated {
            BlockDrag.load(providers) { store, block in store.update { $0.insert(block, into: tab, before: before) } }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}
