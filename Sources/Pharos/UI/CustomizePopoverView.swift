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
        PharosPage(maxWidth: 1200) {
            PharosPageHeader(title: l10n.customizeTitle, subtitle: l10n.customizeIntro) {
                if armedReset {
                    HStack(spacing: PharosSpacing.xs) {
                        Button(l10n.resetLayout) { armedReset = false; layoutStore.reset() }
                            .buttonStyle(.pharosDestructive)
                            .controlSize(.small)
                        IconButton(systemImage: "xmark", help: l10n.cancel) { armedReset = false }
                    }
                } else {
                    Button(l10n.resetLayout) { armedReset = true }
                        .buttonStyle(.pharos)
                        .controlSize(.small)
                        .disabled(layout == .standard)
                }
            }
        } content: {
            HStack(alignment: .top, spacing: PharosSpacing.l) {
                // Left: Live popover snapshot preview (fixed 310 width)
                VStack(alignment: .leading, spacing: PharosSpacing.s) {
                    Label(l10n.livePreview, systemImage: "macwindow")
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                        .padding(.leading, 4)
                    PopoverSnapshot(layout: layout, tab: $previewTab)
                }
                .frame(width: 310)

                // Right: Tabs configuration on top, Library and Settings below
                editorColumns(layout: layout)
            }
        }
    }

    private func editorColumns(layout: PopoverLayout) -> some View {
        VStack(alignment: .leading, spacing: PharosSpacing.m) {
            // Upper right: Overview & Projects tabs side-by-side
            HStack(alignment: .top, spacing: PharosSpacing.m) {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    TabColumn(tab: tab, blocks: layout[tab], selected: previewTab == tab) {
                        previewTab = tab
                    }
                }
            }
            // Lower right: Component Library
            LibraryColumn(unused: layout.unused)
            // Bottom: Running projects row limit
            ProjectRowsSettings(blockInUse: layout.tab(of: .projects) != nil)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
        .frame(width: 310)
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
    @State private var tailTargeted = false
    @State private var columnTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            ForEach(blocks, id: \.self) { block in
                TileDropContainer(tab: tab, block: block, isFirst: block == blocks.first, isLast: block == blocks.last)
            }
            dropTail
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(minWidth: 125, maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(background)
        .overlay(border)
        .contentShape(Rectangle())
        .onDrop(of: [UTType.text], delegate: TabColumnDropDelegate(tab: tab, isTargeted: $columnTargeted))
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

    /// Empty tail: drop here to append.
    private var dropTail: some View {
        let isGlow = tailTargeted || columnTargeted
        let color: Color = isGlow ? PharosColor.accent : Color.secondary.opacity(0.35)
        return RoundedRectangle(cornerRadius: 8)
            .strokeBorder(color, style: StrokeStyle(lineWidth: isGlow ? 1.5 : 1, dash: [4]))
            .frame(height: blocks.isEmpty ? 80 : 38)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isGlow ? PharosColor.accent.opacity(0.08) : Color.clear)
            )
            .overlay(
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 11))
                    Text(l10n.dropHere)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isGlow ? PharosColor.accent : PharosColor.textTertiary)
            )
            .contentShape(Rectangle())
            .onDrop(of: [UTType.text], isTargeted: $tailTargeted) { providers in
                if let active = DragCoordinator.shared.endDrag() {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        layoutStore.update { $0.insert(active, into: tab) }
                    }
                    return true
                }
                return append(providers)
            }
    }

    private func append(_ providers: [NSItemProvider]) -> Bool {
        let t = tab
        return BlockDrag.load(providers) { store, block in store.update { $0.insert(block, into: t) } }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(columnTargeted ? PharosColor.accent.opacity(0.05) : (selected ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)))
    }

    private var border: some View {
        let color: Color = columnTargeted
            ? PharosColor.accent.opacity(0.8)
            : (selected ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.06))
        return RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: columnTargeted ? 1.5 : 1)
    }
}

private struct TileDropContainer: View {
    let tab: PopoverTab
    let block: PopoverBlock
    let isFirst: Bool
    let isLast: Bool
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Drop insertion bar above tile with tactile amber guide
            if isTargeted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(PharosColor.accent)
                        .frame(width: 5, height: 5)
                    Rectangle()
                        .fill(PharosColor.accent)
                        .frame(height: 2)
                    Circle()
                        .fill(PharosColor.accent)
                        .frame(width: 5, height: 5)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .transition(.scale.combined(with: .opacity))
            }

            BlockTile(block: block, inTab: tab, isFirst: isFirst, isLast: isLast)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isTargeted ? PharosColor.accent.opacity(0.8) : Color.clear, lineWidth: isTargeted ? 1.5 : 0)
                )
        }
        .contentShape(Rectangle())
        .onDrop(of: [UTType.text], delegate: BlockDropDelegate(tab: tab, before: block, isTargeted: $isTargeted))
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
        .contentShape(Rectangle())
        .onDrop(of: [UTType.text], isTargeted: $targeted) { providers in
            if let active = DragCoordinator.shared.endDrag() {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                    layoutStore.update { $0.remove(active) }
                }
                return true
            }
            return remove(providers)
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 8)], spacing: 8) {
                ForEach(unused, id: \.self) { block in
                    BlockTile(block: block, inTab: nil, isFirst: true, isLast: true)
                        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                            if let active = DragCoordinator.shared.endDrag() {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                    layoutStore.update { $0.remove(active) }
                                }
                                return true
                            }
                            return remove(providers)
                        }
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
    @ObservedObject private var dragCoord = DragCoordinator.shared
    let block: PopoverBlock
    /// nil = in the library.
    let inTab: PopoverTab?
    let isFirst: Bool
    let isLast: Bool
    @State private var hovering = false

    var isBeingDragged: Bool {
        dragCoord.activeBlock == block
    }

    var body: some View {
        tileContent
            .opacity(isBeingDragged ? 0.35 : 1.0)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onDrag {
                dragCoord.beginDrag(block)
                return NSItemProvider(object: block.rawValue as NSString)
            } preview: {
                dragPreview
            }
    }

    private var tileContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(hovering ? PharosColor.textSecondary : PharosColor.textTertiary)
                .frame(width: 12)
            Image(systemName: block.icon)
                .font(.system(size: 12))
                .foregroundStyle(PharosColor.accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(l10n.blockName(block))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PharosColor.textPrimary)
                    .lineLimit(1)
                Text(l10n.blockDescription(block))
                    .font(.system(size: 9))
                    .foregroundStyle(PharosColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            if hovering {
                actions
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(hovering ? PharosColor.accent.opacity(0.35) : PharosColor.separator.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(hovering ? 0.05 : 0.02), radius: 2, y: 1)
    }

    private var dragPreview: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PharosColor.textSecondary)
            Image(systemName: block.icon)
                .font(.system(size: 12))
                .foregroundStyle(PharosColor.accent)
            Text(l10n.blockName(block))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PharosColor.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PharosColor.accent.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
        )
    }

    @ViewBuilder
    private var actions: some View {
        if inTab != nil {
            HStack(spacing: 2) {
                IconButton(systemImage: "chevron.up", help: l10n.moveUp, size: 18) {
                    layoutStore.update { $0.move(block, by: -1) }
                }
                .disabled(isFirst)
                IconButton(systemImage: "chevron.down", help: l10n.moveDown, size: 18) {
                    layoutStore.update { $0.move(block, by: 1) }
                }
                .disabled(isLast)
                IconButton(systemImage: "minus.circle", help: l10n.removeBlock, tint: .red.opacity(0.8), size: 18) {
                    layoutStore.update { $0.remove(block) }
                }
            }
        } else {
            Menu {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    Button(l10n.addTo(l10n.popoverTabName(tab))) {
                        layoutStore.update { $0.insert(block, into: tab) }
                    }
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
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
            // Header: title on left, range on right
            HStack(alignment: .firstTextBaseline) {
                Label(l10n.projectRowsTitle, systemImage: "arrow.up.and.down.text.horizontal")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(l10n.projectRowsRange(PopoverLayout.minProjectRows, upper, running: store.projects.count))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Controls: Presets capsules on left, Stepper on right
            HStack(spacing: 6) {
                // Preset capsules
                HStack(spacing: 4) {
                    ForEach(presets, id: \.self) { n in
                        Button { set(n) } label: {
                            Text(n == upper && !PopoverLayout.projectRowChoices.contains(n) ? l10n.rowsAll(n) : "\(n)")
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(n == current ? Color.accentColor : Color.primary.opacity(0.07)))
                                .foregroundStyle(n == current ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 4)

                // Compact custom number input with Stepper
                HStack(spacing: 3) {
                    TextField("", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(width: 38)
                        .focused($focused)
                        .onSubmit { commit() }
                        .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
                    Stepper("", value: Binding(get: { current }, set: { set($0) }),
                            in: PopoverLayout.minProjectRows...upper)
                        .labelsHidden()
                    Text(l10n.projectsUnit)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
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

// MARK: - Drag & drop coordinator

@MainActor
final class DragCoordinator: ObservableObject {
    static let shared = DragCoordinator()
    @Published var activeBlock: PopoverBlock? = nil
    private var clearTask: Task<Void, Never>? = nil

    func beginDrag(_ block: PopoverBlock) {
        clearTask?.cancel()
        activeBlock = block
        clearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if !Task.isCancelled {
                self?.activeBlock = nil
            }
        }
    }

    func endDrag() -> PopoverBlock? {
        clearTask?.cancel()
        clearTask = nil
        let b = activeBlock
        activeBlock = nil
        return b
    }
}

private enum BlockDrag {
    /// Drag payload fallback using NSItemProvider.
    @MainActor
    static func load(_ providers: [NSItemProvider], perform: @escaping @MainActor (PopoverLayoutStore, PopoverBlock) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let raw = item as? String, let block = PopoverBlock(rawValue: raw) else { return }
            Task { @MainActor in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) { perform(PopoverLayoutStore.shared, block) }
            }
        }
        return true
    }
}

/// Dropping onto a tile inserts before it.
private struct BlockDropDelegate: DropDelegate {
    let tab: PopoverTab
    let before: PopoverBlock
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.12)) { isTargeted = true }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.12)) { isTargeted = false }
    }

    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.easeOut(duration: 0.12)) { isTargeted = false }
        if let active = DragCoordinator.shared.endDrag() {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                PopoverLayoutStore.shared.update { $0.insert(active, into: tab, before: before) }
            }
            return true
        }
        let providers = info.itemProviders(for: [UTType.text])
        return MainActor.assumeIsolated {
            BlockDrag.load(providers) { store, block in
                store.update { $0.insert(block, into: tab, before: before) }
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

/// Dropping anywhere on a tab column appends to the tab.
private struct TabColumnDropDelegate: DropDelegate {
    let tab: PopoverTab
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.12)) { isTargeted = true }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.12)) { isTargeted = false }
    }

    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.easeOut(duration: 0.12)) { isTargeted = false }
        if let active = DragCoordinator.shared.endDrag() {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                PopoverLayoutStore.shared.update { $0.insert(active, into: tab) }
            }
            return true
        }
        let providers = info.itemProviders(for: [UTType.text])
        return MainActor.assumeIsolated {
            BlockDrag.load(providers) { store, block in
                store.update { $0.insert(block, into: tab) }
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
