import SwiftUI
import PharosCore

/// Interactive, Spotlight-style Popover panel for selecting and searching proxy nodes.
/// Solves the UX breakdown of 100+ nodes in classical cascading menus by providing
/// instant fuzzy search, country/region classification chips, and latency sorting.
struct NodePickerPopover: View {
    @ObservedObject private var clash = ClashStore.shared
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared

    let config: ChromeConfig
    let currentNode: String
    let onSelect: (String) -> Void

    @State private var searchText = ""
    @State private var selectedRegion: ProxyNodeRegion = .all
    @State private var sortByLatency = false
    @State private var hideOffline = false
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            regionFilterChips
            Divider()
            nodeList
            Divider()
            footerBar
        }
        .frame(width: 380, height: 430)
        .background(PharosColor.surfaceSecondary)
    }

    // MARK: - Header Bar (Search & Quick Actions)
    private var headerBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(PharosColor.textSecondary)

                TextField(l10n.searchNodePlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .onSubmit {
                        if let first = filteredNodes.first {
                            onSelect(first.name)
                        }
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(PharosColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(PharosColor.fill))

            // Refresh / Test Latency Button
            Button {
                guard !isRefreshing else { return }
                isRefreshing = true
                Task {
                    await clash.refresh()
                    await clash.refreshNodes(triggerSpeedTest: true)
                    await MainActor.run {
                        isRefreshing = false
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    .foregroundStyle(PharosColor.textSecondary)
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(PharosColor.fill))
            }
            .buttonStyle(.plain)
            .help(l10n.clashRefreshNodes)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Region Filter Chips
    private var regionFilterChips: some View {
        let counts = Dictionary(grouping: clash.nodes, by: \.region)
        let activeRegions: [ProxyNodeRegion] = [.all] + ProxyNodeRegion.allCases.filter {
            $0 != .all && (counts[$0]?.count ?? 0) > 0
        }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(activeRegions) { region in
                    let isSelected = selectedRegion == region
                    let count = region == .all ? clash.nodes.count : (counts[region]?.count ?? 0)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedRegion = region
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(region == .all ? l10n.allRegionsTitle : "\(region.code) \(l10n.regionShortName(region))")
                            Text("(\(count))")
                                .font(PharosFont.captionDigits)
                                .opacity(0.7)
                        }
                        .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isSelected ? PharosColor.accent.opacity(0.18) : PharosColor.fill)
                        )
                        .foregroundStyle(isSelected ? PharosColor.accent : PharosColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Node List
    private var nodeList: some View {
        VStack(spacing: 0) {
            // Sub-bar: Count & Sort Toggles
            HStack(spacing: 8) {
                Text("\(filteredNodes.count) \(filteredNodes.count == 1 ? "node" : "nodes")")
                    .font(PharosFont.captionDigits)
                    .foregroundStyle(PharosColor.textTertiary)

                Spacer()

                // Sort by latency toggle
                Button {
                    withAnimation { sortByLatency.toggle() }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.horizontal")
                            .font(.system(size: 9))
                        Text(l10n.sortByLatency)
                            .font(.system(size: 9.5))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(sortByLatency ? PharosColor.accent.opacity(0.15) : Color.clear))
                    .foregroundStyle(sortByLatency ? PharosColor.accent : PharosColor.textTertiary)
                }
                .buttonStyle(.plain)

                // Hide offline toggle
                Button {
                    withAnimation { hideOffline.toggle() }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: hideOffline ? "eye.slash" : "eye")
                            .font(.system(size: 9))
                        Text(l10n.hideOfflineNodes)
                            .font(.system(size: 9.5))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(hideOffline ? PharosColor.accent.opacity(0.15) : Color.clear))
                    .foregroundStyle(hideOffline ? PharosColor.accent : PharosColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(PharosColor.surface)

            Divider()

            if filteredNodes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(PharosColor.textTertiary)
                    Text(l10n.noMatchingNodes)
                        .font(.system(size: 11))
                        .foregroundStyle(PharosColor.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        // Recent nodes section when search is empty and region is all
                        if searchText.isEmpty && selectedRegion == .all && !recentNodes.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n.recentNodesTitle)
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(PharosColor.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.top, 4)

                                ForEach(recentNodes) { node in
                                    nodeRow(node)
                                }
                                Divider().padding(.vertical, 4)
                            }
                        }

                        ForEach(filteredNodes) { node in
                            nodeRow(node)
                        }
                    }
                    .padding(6)
                    .pharosSlimScroller()
                }
            }
        }
    }

    // MARK: - Node Row View
    private func nodeRow(_ node: MihomoProxyNode) -> some View {
        let isSelected = currentNode == node.name
        return Button {
            onSelect(node.name)
        } label: {
            HStack(spacing: 8) {
                // Region code tag
                Text(node.region.code)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(RoundedRectangle(cornerRadius: 3).fill(PharosColor.fill))
                    .foregroundStyle(PharosColor.textSecondary)

                // Node name & Type
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.name)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? PharosColor.textPrimary : PharosColor.textPrimary.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(node.type.uppercased())
                        .font(.system(size: 8.5))
                        .foregroundStyle(PharosColor.textTertiary)
                }

                Spacer(minLength: 4)

                // Latency Badge
                if let delay = node.validDelay {
                    Text("\(delay) ms")
                        .font(PharosFont.captionDigits)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(delayColor(delay).opacity(0.12)))
                        .foregroundStyle(delayColor(delay))
                } else if node.statusRank == 2 {
                    Text("Timeout")
                        .font(PharosFont.captionDigits)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(PharosColor.error.opacity(0.1)))
                        .foregroundStyle(PharosColor.error.opacity(0.8))
                }

                // Checkmark if selected
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PharosColor.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? PharosColor.accent.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 9))
                .foregroundStyle(PharosColor.textTertiary)

            Text("\(l10n.proxyExitNode):")
                .font(.system(size: 10))
                .foregroundStyle(PharosColor.textTertiary)

            Text(currentNode)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PharosColor.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(":\(config.dedicatedProxyPort)")
                .font(PharosFont.captionDigits)
                .foregroundStyle(PharosColor.textTertiary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(PharosColor.fill))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PharosColor.surface)
    }

    // MARK: - Computed Filtered Nodes
    private var filteredNodes: [MihomoProxyNode] {
        var result = clash.nodes

        // Filter by region
        if selectedRegion != .all {
            result = result.filter { $0.region == selectedRegion }
        }

        // Filter by search text
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let terms = trimmed.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            result = result.filter { node in
                let n = node.name.lowercased()
                let t = node.type.lowercased()
                let r = node.region.code.lowercased()
                return terms.allSatisfy { term in
                    n.contains(term) || t.contains(term) || r.contains(term)
                }
            }
        }

        // Hide offline
        if hideOffline {
            result = result.filter { $0.isHealthy }
        }

        // Sort: Healthy nodes ALWAYS come first! Timeout/dead nodes ALWAYS come last!
        result.sort { a, b in
            // Primary sort: status rank (0 = healthy, 1 = untested, 2 = timeout)
            if a.statusRank != b.statusRank {
                return a.statusRank < b.statusRank
            }

            // Secondary sort: if sortByLatency, healthy nodes sort by latency asc
            if sortByLatency, let d1 = a.validDelay, let d2 = b.validDelay, d1 != d2 {
                return d1 < d2
            }

            // Tertiary: natural alphanumeric name sorting
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        return result
    }

    private var recentNodes: [MihomoProxyNode] {
        let nodeMap = Dictionary(uniqueKeysWithValues: clash.nodes.map { ($0.name, $0) })
        return chrome.recentNodeNames.compactMap { nodeMap[$0] }
    }

    private func delayColor(_ delay: Int) -> Color {
        if delay < 100 {
            return PharosColor.success
        } else if delay < 250 {
            return PharosColor.amber
        } else {
            return PharosColor.error
        }
    }
}
