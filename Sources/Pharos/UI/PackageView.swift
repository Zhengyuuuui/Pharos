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
    @ObservedObject var store = PackageStore.shared
    @ObservedObject var l10n = L10n.shared

    @State var selectedTab: PackageTab = .globalCli
    @State var displayLimit = 60
    @State var copiedFeedbackId: String? = nil
    @State var isFeaturedShelfExpanded = true
    @State var itemToUninstall: LocalPackageItem? = nil
    @State var showUninstallAlert = false
    @State var bundleToDelete: ProjectDependencySummary? = nil
    @State var showDeleteBundleAlert = false
    @State var isDetailedExpanded: Bool? = nil

    var isPackagesBreakdownExpanded: Bool {
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
        .onAppear {
            store.scanIfNeeded()
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

            // Homebrew dedicated management and control bar
            if store.selectedEcosystem == .homebrew {
                homebrewControlBar
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

    // MARK: - Homebrew Control Bar
    private var homebrewControlBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "mug.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14))
                Text(l10n.homebrewControlTitle)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if let feedback = store.homebrewCleanFeedback {
                    Text(l10n.homebrewCleanDirectlySuccess(feedback))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Text(l10n.homebrewControlSubtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    store.runHomebrewCleanup()
                } label: {
                    Label(l10n.homebrewCleanCacheBtn, systemImage: "trash")
                }
                .help(l10n.homebrewCleanCacheHelp)

                Button {
                    store.runHomebrewOutdated()
                } label: {
                    Label(l10n.homebrewOutdatedBtn, systemImage: "arrow.triangle.2.circlepath")
                }
                .help(l10n.homebrewOutdatedHelp)

                Button {
                    store.runHomebrewDoctor()
                } label: {
                    Label(l10n.homebrewDoctorBtn, systemImage: "stethoscope")
                }
                .help(l10n.homebrewDoctorHelp)

                Button {
                    store.runHomebrewServices()
                } label: {
                    Label(l10n.homebrewServicesBtn, systemImage: "gearshape.2")
                }
                .help(l10n.homebrewServicesHelp)

                Spacer()

                Button {
                    store.cleanHomebrewCacheDirectly()
                } label: {
                    Label(l10n.homebrewCleanDirectlyBtn, systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.18), lineWidth: 1))
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


}
