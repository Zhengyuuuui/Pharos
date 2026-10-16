import AppKit
import SwiftUI
import PharosCore

public enum PackageTab: String, CaseIterable, Identifiable, Sendable {
    case globalCli
    case projectDeps
    case cacheRepos

    public var id: String { rawValue }
}

struct PackageView: View {
    @ObservedObject private var store = PackageStore.shared
    @ObservedObject private var l10n = L10n.shared

    @State private var selectedTab: PackageTab = .globalCli
    @State private var displayLimit = 60
    @State private var copiedFeedbackId: String? = nil
    @State private var isFeaturedShelfExpanded = true
    @State private var itemToUninstall: LocalPackageItem? = nil
    @State private var showUninstallAlert = false
    @State private var bundleToDelete: ProjectDependencySummary? = nil
    @State private var showDeleteBundleAlert = false
    @State private var isDetailedExpanded: Bool? = nil

    private var isPackagesBreakdownExpanded: Bool {
        isDetailedExpanded ?? (store.projectDepsDisplayMode == .detailedList)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                tabPicker

                switch selectedTab {
                case .globalCli:
                    globalCliSection
                case .projectDeps:
                    projectDepsSection
                case .cacheRepos:
                    cacheReposSection
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: store.selectedEcosystem) { _, _ in
            displayLimit = 60
        }
        .onChange(of: store.selectedProjectSummary?.id) { _, _ in
            isDetailedExpanded = nil
        }
        .alert(isPresented: $showUninstallAlert) {
            let item = itemToUninstall
            let name = item?.name ?? ""
            let cmd = item?.uninstallCommand ?? ""
            return Alert(
                title: Text(l10n.uninstallConfirmTitle(name)),
                message: Text(l10n.uninstallConfirmMessage(name, cmd)),
                primaryButton: .destructive(Text(l10n.confirmUninstallInTerminal)) {
                    if let it = item {
                        store.uninstallInTerminal(item: it)
                    }
                },
                secondaryButton: .cancel(Text(l10n.cancel))
            )
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.packagesTitle)
                    .font(.title2.weight(.bold))
                Text(l10n.packagesSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    store.scanAll()
                } label: {
                    Label(store.isScanning ? l10n.loading : l10n.refreshNow, systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(store.isScanning)
            }
        }
    }

    // MARK: - Tab Picker
    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Label(l10n.tabGlobalCli, systemImage: "bolt.fill").tag(PackageTab.globalCli)
            Label(l10n.tabProjectDeps, systemImage: "folder.fill").tag(PackageTab.projectDeps)
            Label(l10n.tabCacheRepos, systemImage: "archivebox.fill").tag(PackageTab.cacheRepos)
        }
        .pickerStyle(.segmented)
        .controlSize(.regular)
    }

    // MARK: - Tab 1: Global CLI Section
    private var globalCliSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Metrics Cards (Click to filter)
            HStack(spacing: 10) {
                totalCliFilterCard()
                featuredCliFilterCard()
                ecosystemFilterCard(title: "Node.js", ecosystem: .node, icon: "hexagon.fill", color: .green)
                ecosystemFilterCard(title: "Homebrew", ecosystem: .homebrew, icon: "mug.fill", color: .orange)
                ecosystemFilterCard(title: "Python", ecosystem: .python, icon: "snake.fill", color: .blue)
                ecosystemFilterCard(title: "Rust", ecosystem: .rust, icon: "gearshape.fill", color: .purple)
                ecosystemFilterCard(title: "Go", ecosystem: .go, icon: "arrow.right.circle.fill", color: .cyan)
            }

            // Featured Software & AI Tools Shelf (Prominently Placed at the Top)
            featuredToolsShelf

            // Filter Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(l10n.searchPackages, text: $store.cliSearchQuery)
                        .textFieldStyle(.plain)
                    if !store.cliSearchQuery.isEmpty {
                        IconButton(systemImage: "xmark.circle.fill", help: l10n.cancel) {
                            store.cliSearchQuery = ""
                        }
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                .frame(maxWidth: 320)

                Spacer()
                Text(l10n.showingCount(shown: min(displayLimit, store.filteredCliTools.count), total: store.filteredCliTools.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Full List
            if store.filteredCliTools.isEmpty {
                if store.isScanning {
                    loadingPlaceholder
                } else {
                    ContentUnavailableView(l10n.noPackagesFound, systemImage: "shippingbox", description: Text(l10n.searchPackages))
                        .frame(maxWidth: .infinity, minHeight: 180)
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(store.filteredCliTools.prefix(displayLimit)) { item in
                        cliRow(item)
                    }

                    if store.filteredCliTools.count > displayLimit {
                        Button {
                            displayLimit += 60
                        } label: {
                            Text(l10n.loadMore)
                                .font(.system(size: 11, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - Featured Tools Shelf
    private var featuredToolsShelf: some View {
        let tools = store.featuredShelfTools
        return Group {
            if !tools.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.yellow)

                        Text(l10n.featuredToolsTitle)
                            .font(.system(size: 13, weight: .bold))

                        Text(l10n.readyToolsCount(tools.count))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.yellow.opacity(0.15)))

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isFeaturedShelfExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isFeaturedShelfExpanded ? l10n.collapseSection : l10n.expandSection)
                                Image(systemName: isFeaturedShelfExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if isFeaturedShelfExpanded {
                        Text(l10n.featuredToolsSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(tools) { item in
                                featuredToolCard(item)
                            }
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.025))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private func featuredToolCard(_ item: LocalPackageItem) -> some View {
        let color = featuredColor(for: item)
        return VStack(alignment: .leading, spacing: 8) {
            // Header: Icon, Name, Category Tag, Version, Ecosystem
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: featuredIcon(for: item))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)

                        if let tag = item.categoryTag {
                            Text(tag)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(color.opacity(0.12)))
                        }
                    }

                    if let v = item.installedVersion {
                        Text(v.hasPrefix("v") ? v : "v\(v)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(item.ecosystem.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.05)))
            }

            // Description
            if let sum = item.summary, !sum.isEmpty {
                Text(sum)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 26, alignment: .topLeading)
            } else {
                Spacer().frame(height: 26)
            }

            // Path hint
            if let exec = item.executablePath ?? Optional(item.installPath) {
                Text(exec)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Divider().opacity(0.4)

            // Quick Action Buttons
            HStack(spacing: 6) {
                Button {
                    store.testInTerminal(command: item.name)
                } label: {
                    Label(l10n.runInTerminal, systemImage: "terminal.fill")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help(l10n.runCommandTest)

                Button(role: .destructive) {
                    itemToUninstall = item
                    showUninstallAlert = true
                } label: {
                    Label(l10n.uninstall, systemImage: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help(l10n.uninstallHelp(item.name))

                if let exec = item.executablePath {
                    IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                        store.revealInFinder(path: exec)
                    }
                }

                Spacer()

                Button {
                    let textToCopy = item.executablePath ?? item.name
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToCopy, forType: .string)
                    copiedFeedbackId = item.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedFeedbackId == item.id { copiedFeedbackId = nil }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copiedFeedbackId == item.id ? "checkmark" : "doc.on.doc")
                        Text(copiedFeedbackId == item.id ? l10n.commandCopied : l10n.copyPath)
                    }
                    .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(copiedFeedbackId == item.id ? Color.green : Color.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }

    private func featuredColor(for item: LocalPackageItem) -> Color {
        guard let tag = item.categoryTag else { return Color.accentColor }
        switch tag {
        case "AI 助手": return Color.purple
        case "开发构建": return Color.blue
        case "包管理": return Color.orange
        case "终端效率": return Color.green
        default: return Color.accentColor
        }
    }

    private func featuredIcon(for item: LocalPackageItem) -> String {
        guard let tag = item.categoryTag else { return "bolt.fill" }
        switch tag {
        case "AI 助手": return "sparkles"
        case "开发构建": return "hammer.fill"
        case "包管理": return "shippingbox.fill"
        case "终端效率": return "bolt.fill"
        default: return "bolt.fill"
        }
    }

    private func cliRow(_ item: LocalPackageItem) -> some View {
        let isSelected = (store.selectedCliId == item.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: item.ecosystem.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(ecosystemColor(item.ecosystem))
                    .frame(width: 20)

                Text(item.name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))

                if item.isFeatured {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8))
                        Text(item.categoryTag ?? l10n.coreSoftwareBadge)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Color.yellow)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.yellow.opacity(0.15)))
                }

                if let v = item.installedVersion {
                    Text(v.hasPrefix("v") ? v : "v\(v)")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }

                Text(item.ecosystem.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.04)))

                if let lic = item.license {
                    Text(lic)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.05)))
                }

                Spacer()

                HStack(spacing: 6) {
                    Button(role: .destructive) {
                        itemToUninstall = item
                        showUninstallAlert = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                            Text(l10n.uninstall)
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(Color.red.opacity(0.85))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help(l10n.uninstallHelp(item.name))

                    if let exec = item.executablePath {
                        IconButton(systemImage: "terminal", help: l10n.testInTerminal) {
                            store.testInTerminal(command: item.name)
                        }
                        IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                            store.revealInFinder(path: exec)
                        }
                    } else {
                        IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                            store.revealInFinder(path: item.installPath)
                        }
                    }

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.executablePath ?? item.name, forType: .string)
                        copiedFeedbackId = item.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if copiedFeedbackId == item.id { copiedFeedbackId = nil }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: copiedFeedbackId == item.id ? "checkmark" : "doc.on.doc")
                            Text(copiedFeedbackId == item.id ? l10n.commandCopied : l10n.copyCliCommand)
                        }
                        .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            if let summary = item.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if let exec = item.executablePath {
                    Text(exec)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                if item.fileSizeBytes > 0 {
                    Text(ByteFormat.short(item.fileSizeBytes))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : (item.isFeatured ? Color.yellow.opacity(0.04) : Color.primary.opacity(0.03)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : (item.isFeatured ? Color.yellow.opacity(0.25) : Color.primary.opacity(0.06)), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectedCliId = (isSelected ? nil : item.id)
        }
    }

    // MARK: - Tab 2: Project Dependencies Section
    private var projectDepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Project Selector Bar
            HStack(spacing: 12) {
                Menu {
                    ForEach(PackageEcosystem.allCases) { eco in
                        let ecoProjects = store.detectedProjects.filter { $0.ecosystem == eco }
                        if !ecoProjects.isEmpty {
                            Section("\(eco.displayName) (\(ecoProjects.count))") {
                                ForEach(ecoProjects) { p in
                                    Button {
                                        store.selectedProjectSummary = p
                                    } label: {
                                        HStack {
                                            Image(systemName: "folder.fill")
                                            Text(p.name)
                                            Spacer()
                                            if let cacheName = p.cacheDirectoryName, p.dependenciesSizeBytes > 0 {
                                                Text("[\(cacheName): \(ByteFormat.short(p.dependenciesSizeBytes))]")
                                            } else {
                                                Text("\(p.directDependenciesCount) deps")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(store.selectedProjectSummary != nil ? ecosystemColor(store.selectedProjectSummary!.ecosystem) : Color.accentColor)
                        Text(store.selectedProjectSummary?.name ?? l10n.selectProjectPrompt)
                            .font(.system(size: 13, weight: .semibold))
                        if let current = store.selectedProjectSummary {
                            Text("(\(current.ecosystem.displayName))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            if let cacheName = current.cacheDirectoryName, current.dependenciesSizeBytes > 0 {
                                Text("[\(cacheName): \(ByteFormat.short(current.dependenciesSizeBytes))]")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
                .menuStyle(.borderlessButton)

                if let current = store.selectedProjectSummary {
                    Text(current.rootPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                        store.revealInFinder(path: current.rootPath)
                    }
                }
            }

            if let summary = store.selectedProjectSummary {
                // Primary Big Dependency Bundle Hero Card
                primaryBundleHeroCard(summary)

                // Detailed Package Breakdown (only when expanded)
                if isPackagesBreakdownExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        // Filter & Search
                        HStack(spacing: 10) {
                            HStack {
                                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                                TextField(l10n.searchPackages, text: $store.projectSearchQuery)
                                    .textFieldStyle(.plain)
                                if !store.projectSearchQuery.isEmpty {
                                    IconButton(systemImage: "xmark.circle.fill", help: l10n.cancel) {
                                        store.projectSearchQuery = ""
                                    }
                                }
                            }
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                            .frame(maxWidth: 280)

                            Picker("", selection: $store.projectFilter) {
                                Text(l10n.showAll).tag(ProjectDepFilter.all)
                                Text(l10n.prodDependencies).tag(ProjectDepFilter.prod)
                                Text(l10n.devDependencies).tag(ProjectDepFilter.dev)
                                if summary.missingDependenciesCount > 0 {
                                    Text("\(l10n.statusMissing) (\(summary.missingDependenciesCount))").tag(ProjectDepFilter.missing)
                                }
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)

                            Spacer()
                            Text(l10n.showingCount(shown: store.filteredProjectPackages.count, total: summary.packages.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Packages List
                        if store.filteredProjectPackages.isEmpty {
                            ContentUnavailableView(l10n.noPackagesFound, systemImage: "shippingbox")
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(store.filteredProjectPackages) { pkg in
                                    projectPackageRow(pkg)
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                ContentUnavailableView(l10n.noProjects, systemImage: "folder.badge.questionmark", description: Text(l10n.selectProjectPrompt))
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
    }

    // MARK: - Primary Bundle Hero Card
    private func primaryBundleHeroCard(_ summary: ProjectDependencySummary) -> some View {
        let bundleName = summary.primaryBundleName
        let bundlePath = summary.primaryBundlePath
        let exists = summary.isBundleInstalled
        let color = ecosystemColor(summary.ecosystem)
        let isExpanded = isPackagesBreakdownExpanded

        return VStack(alignment: .leading, spacing: 14) {
            // 1. Top row: Bundle Icon, Name, Ecosystem, Subtitle & Ready status
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(bundleName)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)

                        Text(summary.ecosystem.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(color.opacity(0.12)))

                        Spacer()

                        // Status Badge
                        if exists && summary.missingDependenciesCount == 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text(l10n.bundleInstalledReady)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.green.opacity(0.12)))
                        } else if summary.missingDependenciesCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("\(summary.missingDependenciesCount) \(l10n.statusMissing)")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red.opacity(0.12)))
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle.fill")
                                Text(l10n.bundleNotInstalled)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange.opacity(0.12)))
                        }
                    }

                    Text(l10n.bundleSubtitle(for: summary.ecosystem, bundleName: bundleName))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            // 2. Middle Row: Prominent Disk Size & Stats Pills
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.bundleTotalSize)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(summary.dependenciesSizeBytes > 0 ? ByteFormat.short(summary.dependenciesSizeBytes) : (exists ? "0 B" : l10n.noCacheYet))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Stat Pills
                HStack(spacing: 8) {
                    statPill(label: l10n.totalPackagesCountLabel, value: "\(summary.packages.count)", icon: "shippingbox")
                    statPill(label: l10n.declaredCountLabel, value: "\(summary.directDependenciesCount)", icon: "checkmark.seal")
                    statPill(label: l10n.devDepsCountLabel, value: "\(summary.packages.filter(\.isDevDependency).count)", icon: "hammer")
                    if summary.missingDependenciesCount > 0 {
                        statPill(label: l10n.missingDepsCountLabel, value: "\(summary.missingDependenciesCount)", icon: "exclamationmark.triangle.fill", color: .red)
                    }
                }
            }

            // 3. Bundle Path & Quick Actions
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(bundlePath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if exists {
                    Button {
                        store.revealInFinder(path: bundlePath)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.forward.circle")
                            Text(l10n.revealInFinder)
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bundlePath, forType: .string)
                    copiedFeedbackId = bundlePath
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await MainActor.run {
                            if copiedFeedbackId == bundlePath { copiedFeedbackId = nil }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedFeedbackId == bundlePath ? "checkmark" : "doc.on.doc")
                        Text(copiedFeedbackId == bundlePath ? l10n.commandCopied : l10n.copyPath)
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if exists {
                    Button {
                        bundleToDelete = summary
                        showDeleteBundleAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            if store.isDeletingBundle {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(l10n.deleteDependencyBundle)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.isDeletingBundle)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.035)))

            if let successName = store.deleteBundleSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(l10n.deleteBundleSuccessNotice(successName))
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Spacer()
                    IconButton(systemImage: "xmark", help: l10n.cancel) {
                        store.deleteBundleSuccess = nil
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.08)))
            }

            if let err = store.deleteBundleError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    Spacer()
                    IconButton(systemImage: "xmark", help: l10n.cancel) {
                        store.deleteBundleError = nil
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.08)))
            }

            // 4. Missing warning / install tip (if any)
            if summary.missingDependenciesCount > 0 || !exists {
                let installCmd = l10n.missingInstallCommand(for: summary.ecosystem)
                HStack(spacing: 10) {
                    Image(systemName: "terminal")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.missingDependenciesWarn)
                            .font(.system(size: 11, weight: .semibold))
                        Text(installCmd)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(installCmd, forType: .string)
                    } label: {
                        Text(l10n.copyCliCommand)
                    }
                    .controlSize(.small)
                }
                .padding(9)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
            }

            Divider()

            // 5. Expand / Collapse Trigger Bar
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isDetailedExpanded = !isExpanded
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)

                    Text(isExpanded ? l10n.collapseDetailedDependencies : l10n.expandDetailedDependencies(summary.packages.count))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(l10n.modeConfigNotice)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .alert(isPresented: $showDeleteBundleAlert) {
            let s = bundleToDelete ?? summary
            let name = s.primaryBundleName
            let sizeStr = s.dependenciesSizeBytes > 0 ? ByteFormat.short(s.dependenciesSizeBytes) : ""
            let installCmd = l10n.missingInstallCommand(for: s.ecosystem)

            return Alert(
                title: Text(l10n.deleteBundleConfirmTitle(name)),
                message: Text(l10n.deleteBundleConfirmMessage(name, sizeStr, installCmd)),
                primaryButton: .destructive(Text(l10n.deleteBundleAction)) {
                    store.deleteDependencyBundle(for: s)
                },
                secondaryButton: .cancel(Text(l10n.cancel))
            )
        }
    }


    private func statPill(label: String, value: String, icon: String, color: Color = .primary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color == .primary ? Color.secondary : color)
            Text(label + ":")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
    }

    private func projectPackageRow(_ pkg: LocalPackageItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Status Icon & Badge
            healthBadge(pkg.healthStatus)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(pkg.name)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))

                    if pkg.isDevDependency {
                        Text("dev")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.06)))
                    }

                    if let lic = pkg.license {
                        Text(lic)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.04)))
                    }

                    Spacer()

                    // Versions Comparison
                    HStack(spacing: 6) {
                        if let dec = pkg.declaredVersion {
                            Text("\(l10n.declaredVersion): \(dec)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        if let inst = pkg.installedVersion {
                            Text("→")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text("\(l10n.installedVersion): \(inst)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(pkg.healthStatus == .mismatched ? Color.orange : Color.primary)
                        }
                    }
                }

                if let summary = pkg.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if pkg.fileSizeBytes > 0 {
                Text(ByteFormat.short(pkg.fileSizeBytes))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                store.revealInFinder(path: pkg.installPath)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private func healthBadge(_ status: DependencyHealthStatus) -> some View {
        switch status {
        case .normal:
            return Text(l10n.statusNormal)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green.opacity(0.12)))
        case .missing:
            return Text(l10n.statusMissing)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.red.opacity(0.15)))
        case .symlinkedWorkspace:
            return Text(l10n.statusWorkspace)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.blue.opacity(0.12)))
        case .mismatched:
            return Text(l10n.statusMismatched)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
        }
    }

    // MARK: - Tab 3: Cache Repositories Section
    private var cacheReposSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                statCard(l10n.cacheSize, ByteFormat.disk(store.totalCacheSize), icon: "archivebox.fill")
                statCard(l10n.fileCount, "\(store.totalCacheCount) repos", icon: "folder.fill")

                Spacer()
            }

            // Informative Notice Banner linking directly to Disk Cleanup
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)

                Text(l10n.cleanLanguageCachesBannerText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    WindowRouter.shared.cleanupTargetGroup = .packages
                    UserDefaults.standard.set(true, forKey: "cleanupGroupExpanded.packages")
                    CleanupStoreHolder.shared.scan()
                    WindowRouter.shared.request = .diskCleanup
                } label: {
                    HStack(spacing: 4) {
                        Text(l10n.goToDiskCleanup)
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.link)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.025)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.06), lineWidth: 1))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(store.cacheRepos) { repo in
                    cacheCard(repo)
                }
            }
        }
    }

    private func cacheCard(_ repo: PackageCacheRepoSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: repo.ecosystem.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(ecosystemColor(repo.ecosystem))

                VStack(alignment: .leading, spacing: 1) {
                    Text(repo.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text(repo.ecosystem.displayName)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                    store.revealInFinder(path: repo.rootPath)
                }
            }


            HStack(alignment: .firstTextBaseline) {
                Text(ByteFormat.disk(repo.fileSizeBytes))
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                Spacer()
                Text("\(repo.itemCount) \(l10n.fileCount.lowercased())")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(repo.description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(repo.rootPath)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Helper Views
    private func totalCliFilterCard() -> some View {
        let isSelected = (store.selectedEcosystem == nil && !store.onlyFeatured)
        let activeColor = Color.accentColor
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                store.selectedEcosystem = nil
                store.onlyFeatured = false
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(l10n.totalCliToolsCount, systemImage: "terminal.fill")
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? activeColor : .secondary)
                        .lineLimit(1)
                    Spacer()
                    if isSelected {
                        Circle()
                            .fill(activeColor)
                            .frame(width: 5, height: 5)
                    }
                }
                Text("\(store.globalCliCount)")
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(isSelected ? activeColor : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? activeColor.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? activeColor.opacity(0.8) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l10n.showAllCliTools)
    }

    private func featuredCliFilterCard() -> some View {
        let isSelected = store.onlyFeatured
        let activeColor = Color.yellow
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                store.onlyFeatured.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(l10n.featuredSoftwareCard, systemImage: "sparkles")
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? activeColor : .secondary)
                        .lineLimit(1)
                    Spacer()
                    if isSelected {
                        Circle()
                            .fill(activeColor)
                            .frame(width: 5, height: 5)
                    }
                }
                Text("\(store.featuredCliCount)")
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(isSelected ? activeColor : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? activeColor.opacity(0.14) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? activeColor.opacity(0.8) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l10n.filterByFeaturedHelp)
    }

    private func ecosystemFilterCard(
        title: String,
        ecosystem: PackageEcosystem,
        icon: String,
        color: Color
    ) -> some View {
        let count = store.cliCount(for: ecosystem)
        let isSelected = (store.selectedEcosystem == ecosystem)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if store.selectedEcosystem == ecosystem {
                    store.selectedEcosystem = nil
                } else {
                    store.selectedEcosystem = ecosystem
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? color : .secondary)
                        .lineLimit(1)
                    Spacer()
                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                }
                Text("\(count)")
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(isSelected ? color : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.14) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.85) : color.opacity(0.18), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l10n.filterByEcosystemHelp(title))
    }

    private func statCard(_ title: String, _ value: String, icon: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 11))
                .foregroundStyle(color ?? .secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                .foregroundStyle(color ?? .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color?.opacity(0.25) ?? Color.clear, lineWidth: 1)
        )
    }

    private var loadingPlaceholder: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(l10n.loading).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func ecosystemColor(_ eco: PackageEcosystem) -> Color {
        switch eco {
        case .node: return .green
        case .python: return .blue
        case .java: return .orange
        case .rust: return .purple
        case .go: return .cyan
        case .swift: return .red
        case .homebrew: return .yellow
        }
    }
}
