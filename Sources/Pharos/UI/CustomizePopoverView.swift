import SwiftUI
import PharosCore

/// Main window → Customize: edit the popover like widgets. Blocks are dragged
/// between the two tab columns and the library; the left side is the real
/// popover content rendered at popover width, so it's an exact live snapshot.
struct CustomizePopoverView: View {
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var dragState = DragSessionState()
    @StateObject private var dragPosition = FloatingDragPosition()
    @State private var editorFrames = EditorFrames()
    @State private var previewTab: PopoverTab = .overview

    var body: some View {
        let layout = layoutStore.layout
        PharosPage {
            PharosPageHeader(title: l10n.customizeTitle, subtitle: l10n.customizeIntro) {
                PharosConfirmButton(
                    title: l10n.resetLayout,
                    confirmTitle: l10n.confirm
                ) {
                    layoutStore.reset()
                }
                .disabled(layout == .standard)
            }
        } content: {
            HStack(alignment: .top, spacing: PharosSpacing.l) {
                // Left: Live previews (1:1 Menu bar capsule + Popover snapshot, fixed 340 width)
                VStack(alignment: .leading, spacing: PharosSpacing.m) {
                    VStack(alignment: .leading, spacing: PharosSpacing.xs) {
                        Label(l10n.liveMenuBarPreview, systemImage: "menubar.dock.rectangle")
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                            .padding(.leading, 4)
                        LiveMenuBarPreviewCapsule()
                    }

                    VStack(alignment: .leading, spacing: PharosSpacing.xs) {
                        Label(l10n.livePreview, systemImage: "macwindow")
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                            .padding(.leading, 4)
                        PopoverSnapshot(layout: layout, tab: $previewTab)
                    }
                }
                .frame(width: 340)

                // Right: Menu Bar Composer on top, Tabs configuration below
                editorColumns(layout: layout)
            }
        }
    }

    private func editorColumns(layout: PopoverLayout) -> some View {
        VStack(alignment: .leading, spacing: PharosSpacing.m) {
            // Upper: Menu Bar Composer Section
            MenuBarComposerSection()

            PharosListDivider()
                .padding(.vertical, 2)

            // Popover widget columns header
            HStack {
                Label(l10n.customizePopover, systemImage: "square.grid.2x2")
                    .font(PharosFont.sectionTitle)
                    .foregroundStyle(PharosColor.textPrimary)
                Spacer()
            }

            // Upper right: Overview & Projects tabs side-by-side
            HStack(alignment: .top, spacing: PharosSpacing.m) {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    TabColumn(
                        tab: tab,
                        blocks: layout[tab],
                        selected: previewTab == tab,
                        dragState: dragState,
                        onSelect: { previewTab = tab },
                        onDragChanged: { block, value in
                            handleDragChanged(block: block, sourceTab: tab, value: value, layout: layout)
                        },
                        onDragEnded: { block, value in
                            handleDragEnded(block: block, sourceTab: tab, value: value, layout: layout)
                        }
                    )
                }
            }
            // Lower right: Component Library
            LibraryColumn(
                unused: layout.unused,
                dragState: dragState,
                onDragChanged: { block, value in
                    handleDragChanged(block: block, sourceTab: nil, value: value, layout: layout)
                },
                onDragEnded: { block, value in
                    handleDragEnded(block: block, sourceTab: nil, value: value, layout: layout)
                }
            )
            // Bottom: Running projects row limit
            ProjectRowsSettings(blockInUse: layout.tab(of: .projects) != nil)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .coordinateSpace(name: CustomizeEditorSpace.name)
        .onPreferenceChange(EditorFramesKey.self) { editorFrames = $0 }
        .overlay(alignment: .topLeading) {
            FloatingDragLayer(dragState: dragState, position: dragPosition)
        }
        .background(NonDraggableWindowRegion())
    }

    private func handleDragChanged(
        block: PopoverBlock,
        sourceTab: PopoverTab?,
        value: DragGesture.Value,
        layout: PopoverLayout
    ) {
        if dragState.activeBlock != block {
            let grabOffset: CGSize
            let width: CGFloat
            if let rect = editorFrames.tiles[block], rect.width > 10 {
                grabOffset = CGSize(
                    width: min(max(value.startLocation.x - rect.minX, 12), rect.width - 12),
                    height: min(max(value.startLocation.y - rect.minY, 8), rect.height - 8)
                )
                width = rect.width
            } else {
                grabOffset = CGSize(width: 80, height: 18)
                width = 180
            }
            dragPosition.grabOffset = grabOffset
            dragPosition.width = width
            dragPosition.origin = CGPoint(
                x: value.location.x - grabOffset.width,
                y: value.location.y - grabOffset.height
            )
            dragState.activeBlock = block
            dragState.sourceTab = sourceTab
        } else {
            dragPosition.origin = CGPoint(
                x: value.location.x - dragPosition.grabOffset.width,
                y: value.location.y - dragPosition.grabOffset.height
            )
        }

        let newTarget = resolveDropTarget(
            at: value.location,
            activeBlock: block,
            sourceTab: sourceTab,
            layout: layout
        )
        if dragState.dropTarget != newTarget {
            dragState.dropTarget = newTarget
        }
    }

    private func handleDragEnded(
        block: PopoverBlock,
        sourceTab: PopoverTab?,
        value: DragGesture.Value,
        layout: PopoverLayout
    ) {
        let finalTarget = resolveDropTarget(
            at: value.location,
            activeBlock: block,
            sourceTab: sourceTab,
            layout: layout
        ) ?? dragState.dropTarget

        dragState.reset()

        guard let target = finalTarget else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
            switch target {
            case .insertBefore(let tab, let before):
                if before != block {
                    layoutStore.update { $0.insert(block, into: tab, before: before) }
                }
            case .appendToTab(let tab):
                layoutStore.update { $0.insert(block, into: tab) }
            case .library:
                if sourceTab != nil {
                    layoutStore.update { $0.remove(block) }
                }
            }
        }
    }

    private func resolveDropTarget(
        at location: CGPoint,
        activeBlock: PopoverBlock,
        sourceTab: PopoverTab?,
        layout: PopoverLayout
    ) -> DropTarget? {
        for tab in PopoverTab.allCases {
            guard let tabRect = editorFrames.tabs[tab],
                  tabRect.insetBy(dx: -6, dy: -6).contains(location) else { continue }

            let blocks = layout[tab]
            for candidate in blocks {
                guard let tileRect = editorFrames.tiles[candidate] else { continue }
                if location.y < tileRect.midY {
                    return .insertBefore(tab: tab, before: candidate)
                }
            }
            return .appendToTab(tab)
        }

        if sourceTab != nil,
           let libRect = editorFrames.library,
           libRect.insetBy(dx: -6, dy: -6).contains(location) {
            return .library
        }

        return nil
    }
}

// MARK: - Direct 120Hz Drag State & Geometry

private enum CustomizeEditorSpace {
    static let name = "PharosCustomizeEditorSpace"
}

private enum DropTarget: Equatable {
    case insertBefore(tab: PopoverTab, before: PopoverBlock)
    case appendToTab(PopoverTab)
    case library
}

/// Low-frequency state: only publishes when a drag begins/ends or crosses into a new drop slot.
@MainActor
private final class DragSessionState: ObservableObject {
    @Published var activeBlock: PopoverBlock? = nil
    @Published var sourceTab: PopoverTab? = nil
    @Published var dropTarget: DropTarget? = nil

    func reset() {
        activeBlock = nil
        sourceTab = nil
        dropTarget = nil
    }
}

/// High-frequency 120Hz pointer state observed strictly by `FloatingDragLayer` so
/// moving the cursor never invalidates `TabColumn`, `LibraryColumn`, or `BlockTile`.
@MainActor
private final class FloatingDragPosition: ObservableObject {
    @Published var origin: CGPoint = .zero
    var grabOffset: CGSize = CGSize(width: 80, height: 18)
    var width: CGFloat = 180
}

private struct EditorFrames: Equatable {
    var tabs: [PopoverTab: CGRect] = [:]
    var tiles: [PopoverBlock: CGRect] = [:]
    var library: CGRect? = nil

    mutating func merge(_ other: EditorFrames) {
        tabs.merge(other.tabs) { _, new in new }
        tiles.merge(other.tiles) { _, new in new }
        if let lib = other.library { library = lib }
    }
}

private struct EditorFramesKey: PreferenceKey {
    static let defaultValue = EditorFrames()
    static func reduce(value: inout EditorFrames, nextValue: () -> EditorFrames) {
        value.merge(nextValue())
    }
}

private struct FloatingDragLayer: View {
    @ObservedObject var dragState: DragSessionState
    @ObservedObject var position: FloatingDragPosition
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if let block = dragState.activeBlock {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PharosColor.textSecondary)
                    .frame(width: 12)
                Image(systemName: block.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(PharosColor.accent)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l10n.blockName(block))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PharosColor.textPrimary)
                        .lineLimit(1)
                    Text(l10n.blockDescription(block))
                        .font(.system(size: 9))
                        .foregroundStyle(PharosColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: max(140, position.width), alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PharosColor.accent.opacity(0.85), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
            .scaleEffect(1.02)
            .offset(x: position.origin.x, y: position.origin.y)
            .allowsHitTesting(false)
        }
    }
}

/// Marks a SwiftUI region as non-movable for `NSWindow` (`mouseDownCanMoveWindow = false`)
/// while passing all hit-testing through to SwiftUI gestures.
private struct NonDraggableWindowRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NonDraggableNSView {
        NonDraggableNSView()
    }
    func updateNSView(_ nsView: NonDraggableNSView, context: Context) {}
}

private final class NonDraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - Live Menu Bar Preview

private struct LiveMenuBarPreviewCapsule: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var settings = MenuBarSettings.shared
    @ObservedObject private var battery = BatteryStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 11))
                    .foregroundStyle(PharosColor.textSecondary)
                Text("Pharos")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PharosColor.textPrimary)
            }
            .padding(.leading, 6)

            Spacer()

            HStack(spacing: 5) {
                Image(nsImage: MenuBarCompositeRenderer.currentImage(
                    store: store,
                    settings: settings,
                    battery: battery
                ))

                if settings.hotkey != .none {
                    Text(settings.hotkey.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PharosColor.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(RoundedRectangle(cornerRadius: 3).fill(PharosColor.fill))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(PharosColor.separator.opacity(0.3), lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(PharosColor.accent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(PharosColor.accent.opacity(0.35), lineWidth: 0.75)
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: 340, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
    }
}

// MARK: - Menu Bar Composer Section

private struct MenuBarComposerSection: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var settings = MenuBarSettings.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: PharosSpacing.s) {
            headerWithPresets
            if !settings.enabledMetrics.isEmpty {
                activeOrderStrip
            }
            metricsSelectionGrid
            detailsCard
        }
    }

    private var headerWithPresets: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Label(l10n.menuBarComposerTitle, systemImage: "menubar.rectangle")
                    .font(PharosFont.sectionTitle)
                    .foregroundStyle(PharosColor.textPrimary)

                Text(l10n.menuBarComposerDesc)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
            }

            HStack(spacing: 6) {
                presetButton(title: l10n.presetPortsTemp, metrics: [.ports, .temperature])
                presetButton(title: l10n.presetTempMem, metrics: [.temperature, .memory])
                presetButton(title: l10n.presetPortsTempMem, metrics: [.ports, .temperature, .memory])
                presetButton(title: l10n.presetIconOnly, metrics: [])
            }
        }
    }

    private func presetButton(title: String, metrics: [MenuBarMetric]) -> some View {
        let isSelected = settings.enabledMetrics == metrics
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                settings.enabledMetrics = metrics
            }
        } label: {
            Text(title)
                .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? PharosColor.accent : PharosColor.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? PharosColor.accent.opacity(0.14) : PharosColor.fill)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? PharosColor.accent.opacity(0.4) : PharosColor.separator.opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var activeOrderStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(l10n.activeOrderStripTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PharosColor.textSecondary)
                Text("•")
                    .font(.system(size: 8))
                    .foregroundStyle(PharosColor.textTertiary)
                Text(l10n.activeOrderStripHint)
                    .font(.system(size: 9.5))
                    .foregroundStyle(PharosColor.textTertiary)
                    .lineLimit(1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(settings.enabledMetrics.enumerated()), id: \.element) { idx, metric in
                        activeMetricPill(metric: metric, index: idx, count: settings.enabledMetrics.count)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PharosColor.fill.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(PharosColor.separator.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func activeMetricPill(metric: MenuBarMetric, index: Int, count: Int) -> some View {
        HStack(spacing: 4) {
            Text("\(index + 1)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 14, height: 14)
                .background(Circle().fill(PharosColor.accent))

            Image(systemName: metric.sfSymbol)
                .font(.system(size: 10))
                .foregroundStyle(PharosColor.accent)

            Text(l10n.menuBarMetricName(metric))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PharosColor.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: 1) {
                Button {
                    guard index > 0 else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                        settings.enabledMetrics.swapAt(index, index - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(index > 0 ? PharosColor.textSecondary : PharosColor.textTertiary.opacity(0.3))
                        .frame(width: 12, height: 16)
                }
                .buttonStyle(.plain)
                .disabled(index == 0)

                Button {
                    guard index < count - 1 else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                        settings.enabledMetrics.swapAt(index, index + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(index < count - 1 ? PharosColor.textSecondary : PharosColor.textTertiary.opacity(0.3))
                        .frame(width: 12, height: 16)
                }
                .buttonStyle(.plain)
                .disabled(index >= count - 1)

                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                        settings.enabledMetrics.removeAll { $0 == metric }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(PharosColor.textTertiary)
                        .frame(width: 12, height: 16)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(PharosColor.surface)
        )
        .overlay(
            Capsule()
                .strokeBorder(PharosColor.separator.opacity(0.4), lineWidth: 0.5)
        )
    }

    private var metricsSelectionGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(MenuBarMetric.allCases) { metric in
                metricChip(metric)
            }
        }
    }

    private func metricChip(_ metric: MenuBarMetric) -> some View {
        let isEnabled = settings.enabledMetrics.contains(metric)
        let orderIndex: Int? = settings.enabledMetrics.firstIndex(of: metric).map { $0 + 1 }
        let liveVal = metric.formattedValue(store: store, showLabel: false)

        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                if isEnabled {
                    settings.enabledMetrics.removeAll { $0 == metric }
                } else {
                    settings.enabledMetrics.append(metric)
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Left: 18x18 order indicator
                if let order = orderIndex {
                    Text("\(order)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(PharosColor.accent))
                } else {
                    Circle()
                        .strokeBorder(PharosColor.separator.opacity(0.6), lineWidth: 1)
                        .frame(width: 18, height: 18)
                }

                // SF Symbol
                Image(systemName: metric.sfSymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(isEnabled ? PharosColor.accent : PharosColor.textSecondary)
                    .frame(width: 14)

                // Metric Title
                Text(l10n.menuBarMetricName(metric))
                    .font(.system(size: 12, weight: isEnabled ? .semibold : .medium))
                    .foregroundStyle(isEnabled ? PharosColor.textPrimary : PharosColor.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 6)

                // Right: Live Value Capsule (Never line-wraps number & unit!)
                if let val = liveVal {
                    Text(val)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(isEnabled ? PharosColor.accent : PharosColor.textTertiary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isEnabled ? PharosColor.accent.opacity(0.12) : PharosColor.fill)
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isEnabled ? PharosColor.accent.opacity(0.08) : PharosColor.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isEnabled ? PharosColor.accent.opacity(0.4) : PharosColor.separator.opacity(0.3), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var detailsCard: some View {
        PharosCard(padding: 12) {
            VStack(spacing: 8) {
                PharosSettingRow(
                    title: l10n.ringMetricTitle,
                    systemImage: "circle.circle",
                    caption: l10n.ringMetricHint
                ) {
                    Picker("", selection: $settings.ringMetric) {
                        ForEach(MenuBarMetric.allCases) { m in
                            Label(l10n.menuBarMetricName(m), systemImage: m.sfSymbol).tag(m)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }

                PharosListDivider()

                PharosSettingRow(
                    title: l10n.displayStyleTitle,
                    systemImage: "character.textbox",
                    caption: l10n.displayStyleHint
                ) {
                    Picker("", selection: $settings.displayStyle) {
                        ForEach(MenuBarDisplayStyle.allCases) { style in
                            Text(l10n.displayStyleName(style)).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }

                PharosListDivider()

                PharosSettingRow(
                    title: l10n.separatorStyleTitle,
                    systemImage: "divide"
                ) {
                    Picker("", selection: $settings.separatorStyle) {
                        ForEach(MenuBarSeparator.allCases) { s in
                            Text(l10n.separatorStyleName(s)).tag(s)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                PharosListDivider()

                PharosSettingRow(
                    title: l10n.hotkeyTitle,
                    systemImage: "command",
                    caption: settings.hotkeyError
                ) {
                    Picker("", selection: $settings.hotkey) {
                        ForEach(PopoverHotkey.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                if settings.enabledMetrics.contains(.ports) || settings.ringMetric == .ports {
                    PharosListDivider()
                    HStack {
                        Label(l10n.maxPortsCapacity, systemImage: "network")
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                        Spacer()
                        TextField("", value: $settings.maxPorts, format: .number)
                            .frame(width: 44)
                            .multilineTextAlignment(.trailing)
                        Stepper("", value: $settings.maxPorts, in: 5...300, step: 5)
                            .labelsHidden()
                    }
                    .font(PharosFont.captionDigits)
                    .help(l10n.capacityRingHint)
                }

                if settings.enabledMetrics.contains(.projects) || settings.ringMetric == .projects {
                    PharosListDivider()
                    HStack {
                        Label(l10n.maxProjectsCapacity, systemImage: "folder")
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                        Spacer()
                        TextField("", value: $settings.maxProjects, format: .number)
                            .frame(width: 44)
                            .multilineTextAlignment(.trailing)
                        Stepper("", value: $settings.maxProjects, in: 5...200, step: 5)
                            .labelsHidden()
                    }
                    .font(PharosFont.captionDigits)
                    .help(l10n.capacityRingHint)
                }
            }
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
    @ObservedObject private var l10n = L10n.shared
    let tab: PopoverTab
    let blocks: [PopoverBlock]
    let selected: Bool
    @ObservedObject var dragState: DragSessionState
    let onSelect: () -> Void
    let onDragChanged: (PopoverBlock, DragGesture.Value) -> Void
    let onDragEnded: (PopoverBlock, DragGesture.Value) -> Void

    private var isColumnTargeted: Bool {
        switch dragState.dropTarget {
        case .appendToTab(let t), .insertBefore(let t, _):
            return t == tab
        default:
            return false
        }
    }

    private var isTailTargeted: Bool {
        dragState.dropTarget == .appendToTab(tab)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            ForEach(blocks, id: \.self) { block in
                let isInsertTarget = (dragState.dropTarget == .insertBefore(tab: tab, before: block))
                    && (dragState.activeBlock != block)
                BlockTile(
                    block: block,
                    inTab: tab,
                    isFirst: block == blocks.first,
                    isLast: block == blocks.last,
                    isBeingDragged: dragState.activeBlock == block,
                    showInsertAbove: isInsertTarget,
                    onDragChanged: { onDragChanged(block, $0) },
                    onDragEnded: { onDragEnded(block, $0) }
                )
            }
            dropTail
        }
        .padding(10)
        .frame(minWidth: 125, maxWidth: .infinity, minHeight: 160, maxHeight: .infinity, alignment: .topLeading)
        .background(
            GeometryReader { geo in
                background.preference(
                    key: EditorFramesKey.self,
                    value: EditorFrames(tabs: [tab: geo.frame(in: .named(CustomizeEditorSpace.name))])
                )
            }
        )
        .overlay(border)
        .contentShape(Rectangle())
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
        let isGlow = isTailTargeted
        let color: Color = isGlow ? PharosColor.accent : Color.secondary.opacity(0.35)
        return RoundedRectangle(cornerRadius: 8)
            .strokeBorder(color, style: StrokeStyle(lineWidth: isGlow ? 1.5 : 1, dash: [4]))
            .frame(maxWidth: .infinity, minHeight: blocks.isEmpty ? 80 : 38, maxHeight: .infinity)
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
    }

    private var background: some View {
        let isGlow = isColumnTargeted
        return RoundedRectangle(cornerRadius: 10)
            .fill(isGlow ? PharosColor.accent.opacity(0.05) : (selected ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)))
    }

    private var border: some View {
        let isGlow = isColumnTargeted
        let color: Color = isGlow
            ? PharosColor.accent.opacity(0.8)
            : (selected ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.06))
        return RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: isGlow ? 1.5 : 1)
    }
}

private struct LibraryColumn: View {
    @ObservedObject private var l10n = L10n.shared
    let unused: [PopoverBlock]
    @ObservedObject var dragState: DragSessionState
    let onDragChanged: (PopoverBlock, DragGesture.Value) -> Void
    let onDragEnded: (PopoverBlock, DragGesture.Value) -> Void

    private var isTargeted: Bool {
        dragState.dropTarget == .library && dragState.sourceTab != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            content
        }
        .padding(10)
        .background(
            GeometryReader { geo in
                background.preference(
                    key: EditorFramesKey.self,
                    value: EditorFrames(library: geo.frame(in: .named(CustomizeEditorSpace.name)))
                )
            }
        )
        .overlay(border)
        .contentShape(Rectangle())
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
                    BlockTile(
                        block: block,
                        inTab: nil,
                        isFirst: true,
                        isLast: true,
                        isBeingDragged: dragState.activeBlock == block,
                        showInsertAbove: false,
                        onDragChanged: { onDragChanged(block, $0) },
                        onDragEnded: { onDragEnded(block, $0) }
                    )
                }
            }
        }
    }

    private var background: some View {
        let color: Color = isTargeted ? Color.red.opacity(0.08) : Color.primary.opacity(0.03)
        return RoundedRectangle(cornerRadius: 10).fill(color)
    }

    private var border: some View {
        let color: Color = isTargeted ? Color.red.opacity(0.6) : Color.secondary.opacity(0.3)
        let dash: [CGFloat] = isTargeted ? [] : [4]
        return RoundedRectangle(cornerRadius: 10).strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: dash))
    }
}

/// A directly draggable block card (120Hz zero-latency gesture) plus quick-action buttons.
private struct BlockTile: View {
    @ObservedObject private var layoutStore = PopoverLayoutStore.shared
    @ObservedObject private var l10n = L10n.shared
    let block: PopoverBlock
    /// nil = in the library.
    let inTab: PopoverTab?
    let isFirst: Bool
    let isLast: Bool
    let isBeingDragged: Bool
    let showInsertAbove: Bool
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void
    @State private var hovering = false

    var body: some View {
        draggableBody
            .overlay(alignment: .trailing) {
                actions
                    .padding(.trailing, 6)
                    .opacity(hovering && !isBeingDragged ? 1 : 0)
                    .allowsHitTesting(hovering && !isBeingDragged)
            }
            .overlay(alignment: .top) {
                if showInsertAbove {
                    insertionBar
                        .offset(y: -4)
                        .allowsHitTesting(false)
                }
            }
            .opacity(isBeingDragged ? 0.3 : 1.0)
            .onHover { hovering = $0 }
    }

    private var draggableBody: some View {
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
        }
        .padding(.leading, 8)
        .padding(.trailing, hovering ? (inTab != nil ? 62 : 26) : 8)
        .padding(.vertical, 6)
        .background(
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .preference(
                        key: EditorFramesKey.self,
                        value: EditorFrames(tiles: [block: geo.frame(in: .named(CustomizeEditorSpace.name))])
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    showInsertAbove
                        ? PharosColor.accent.opacity(0.85)
                        : (hovering ? PharosColor.accent.opacity(0.35) : PharosColor.separator.opacity(0.3)),
                    lineWidth: showInsertAbove ? 1.2 : 0.5
                )
        )
        .shadow(color: Color.black.opacity(hovering ? 0.05 : 0.02), radius: 2, y: 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named(CustomizeEditorSpace.name))
                .onChanged { value in
                    onDragChanged(value)
                }
                .onEnded { value in
                    onDragEnded(value)
                }
        )
    }

    private var insertionBar: some View {
        HStack(spacing: 3) {
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
        .padding(.horizontal, 2)
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
