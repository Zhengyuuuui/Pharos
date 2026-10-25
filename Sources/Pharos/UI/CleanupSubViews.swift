import SwiftUI
import PharosCore

// MARK: - Sub-Items Breakdown List View

struct SubItemsListView: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    let target: DiskCleaner.Target

    var body: some View {
        let items = cleanup.subItemsCache[target.id] ?? []
        let isLoading = cleanup.loadingSubItemIds.contains(target.id)

        VStack(alignment: .leading, spacing: PharosSpacing.xs) {
            if isLoading {
                HStack(spacing: PharosSpacing.xs) {
                    ProgressView().controlSize(.mini)
                    Text(l10n.inspectingSubItems)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                }
                .padding(.vertical, PharosSpacing.xs)
                .padding(.leading, 24)
            } else if items.isEmpty {
                Text(l10n.noSubItems)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textTertiary)
                    .padding(.vertical, PharosSpacing.xxs)
                    .padding(.leading, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        SubItemRowView(item: item, target: target)
                            .padding(.leading, 24)
                            .padding(.trailing, PharosSpacing.xs)
                            .padding(.vertical, 4)

                        if item.id != items.last?.id {
                            Divider()
                                .opacity(0.3)
                                .padding(.leading, 24)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                        .fill(PharosColor.fill.opacity(0.4))
                )
            }
        }
        .padding(.top, 4)
    }
}

private struct SubItemRowView: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    let item: DiskCleaner.SubItem
    let target: DiskCleaner.Target

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 10))
                .foregroundStyle(PharosColor.accent.opacity(0.7))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(item.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(PharosColor.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(ByteFormat.short(item.size))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(PharosColor.textSecondary)
                .frame(width: 48, alignment: .trailing)

            ConfirmButton(
                title: l10n.cleanSubItem,
                icon: "trash",
                small: true,
                busy: cleanup.cleaning == .subItem(item.id),
                disabled: cleanup.isBusy
            ) {
                cleanup.cleanSubItem(item, under: target)
            }
            .frame(width: 72, alignment: .trailing)
        }
    }
}

// MARK: - App Leftovers View

struct AppLeftoversView: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared

    private var totalBytes: UInt64 {
        cleanup.leftoverItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PharosSpacing.m) {
            PharosCard {
                HStack(alignment: .center, spacing: PharosSpacing.m) {
                    Image(systemName: "app.badge.xmark")
                        .font(.system(size: 20))
                        .foregroundStyle(PharosColor.accent)
                        .frame(width: 40, height: 40)
                        .background(PharosColor.fill, in: RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous))

                    VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                        Text(l10n.leftoversTitle)
                            .font(PharosFont.rowLabel)
                        Text(l10n.leftoversSubtitle)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: PharosSpacing.xxs) {
                        Text(cleanup.leftoverItems.isEmpty ? "–" : ByteFormat.short(totalBytes))
                            .font(PharosFont.metricValue)
                            .foregroundStyle(totalBytes == 0 ? PharosColor.textSecondary : PharosColor.textPrimary)
                            .contentTransition(.numericText())
                        Text(l10n.cacheSize)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textTertiary)
                    }
                }
            }

            HStack {
                Text(l10n.leftoversCountText(cleanup.leftoverItems.count, ByteFormat.short(totalBytes)))
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)

                Spacer()

                Button {
                    cleanup.scanLeftovers()
                } label: {
                    Label(cleanup.isScanningLeftovers ? l10n.scanning : l10n.scanLeftovers, systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(cleanup.isScanningLeftovers)

                ConfirmButton(
                    title: l10n.cleanAllLeftovers,
                    icon: "trash",
                    prominent: true,
                    busy: false,
                    disabled: cleanup.isBusy || cleanup.leftoverItems.isEmpty
                ) {
                    cleanup.deleteAllLeftovers()
                }
            }

            if cleanup.isScanningLeftovers {
                HStack(spacing: PharosSpacing.s) {
                    ProgressView().controlSize(.small)
                    Text(l10n.scanning).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
            } else if cleanup.leftoverItems.isEmpty {
                VStack(spacing: PharosSpacing.s) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                    Text(l10n.noLeftoversFound)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
            } else {
                PharosCard {
                    VStack(spacing: 0) {
                        ForEach(cleanup.leftoverItems) { item in
                            LeftoverItemRow(item: item)
                                .padding(.horizontal, PharosSpacing.xs)
                                .padding(.vertical, PharosSpacing.s)

                            if item.id != cleanup.leftoverItems.last?.id {
                                PharosListDivider()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if cleanup.leftoverItems.isEmpty, !cleanup.isScanningLeftovers {
                cleanup.scanLeftovers()
            }
        }
    }
}

private struct LeftoverItemRow: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    let item: AppLeftoversScanner.LeftoverItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.app.dashed")
                .font(.system(size: 14))
                .foregroundStyle(PharosColor.accent.opacity(0.8))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.appName)
                        .font(.system(size: 12, weight: .semibold))

                    LeftoverCategoryBadge(category: item.category)
                }

                Text(item.path)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(PharosColor.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 8)

            Text(ByteFormat.short(item.size))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(PharosColor.textPrimary)
                .frame(width: 52, alignment: .trailing)

            ConfirmButton(
                title: l10n.cleanRow,
                icon: "trash",
                small: true,
                busy: false,
                disabled: cleanup.isBusy
            ) {
                cleanup.deleteLeftover(item)
            }
            .frame(width: 84, alignment: .trailing)
        }
    }
}

private struct LeftoverCategoryBadge: View {
    let category: AppLeftoversScanner.Category

    var body: some View {
        let (name, color): (String, Color) = switch category {
        case .applicationSupport: ("App Support", .indigo)
        case .savedState: ("Saved State", .orange)
        case .containers: ("Container", .purple)
        case .webKit: ("WebKit", .teal)
        case .httpStorages: ("HTTP Storage", .blue)
        }

        Text(name)
            .font(.system(size: 8.5, weight: .medium))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.14)))
            .foregroundStyle(color)
    }
}

// MARK: - Project Purge View (npkill style)

struct ProjectPurgeView: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared

    private var totalBytes: UInt64 {
        cleanup.purgeableBundles.reduce(0) { $0 + $1.size }
    }
    private var dormantCount: Int {
        cleanup.purgeableBundles.filter { $0.isDormant }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PharosSpacing.m) {
            PharosCard {
                HStack(alignment: .center, spacing: PharosSpacing.m) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 20))
                        .foregroundStyle(PharosColor.accent)
                        .frame(width: 40, height: 40)
                        .background(PharosColor.fill, in: RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous))

                    VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                        Text(l10n.projectPurgeTitle)
                            .font(PharosFont.rowLabel)
                        Text(l10n.projectPurgeSubtitle)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: PharosSpacing.xxs) {
                        Text(cleanup.purgeableBundles.isEmpty ? "–" : ByteFormat.short(totalBytes))
                            .font(PharosFont.metricValue)
                            .foregroundStyle(totalBytes == 0 ? PharosColor.textSecondary : PharosColor.textPrimary)
                            .contentTransition(.numericText())
                        Text(l10n.cacheSize)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textTertiary)
                    }
                }
            }

            HStack {
                Text(l10n.purgeSummaryText(cleanup.purgeableBundles.count, ByteFormat.short(totalBytes), dormantCount: dormantCount))
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)

                Spacer()

                Button {
                    cleanup.scanProjectPurges()
                } label: {
                    Label(cleanup.isScanningPurges ? l10n.scanning : l10n.scanProjects, systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .disabled(cleanup.isScanningPurges)

                ConfirmButton(
                    title: l10n.purgeAllDormant,
                    icon: "sparkles",
                    prominent: true,
                    busy: false,
                    disabled: cleanup.isBusy || dormantCount == 0
                ) {
                    cleanup.purgeAllDormantBundles()
                }
            }

            if cleanup.isScanningPurges {
                HStack(spacing: PharosSpacing.s) {
                    ProgressView().controlSize(.small)
                    Text(l10n.scanning).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
            } else if cleanup.purgeableBundles.isEmpty {
                VStack(spacing: PharosSpacing.s) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 28))
                        .foregroundStyle(PharosColor.textTertiary)
                    Text(l10n.noPurgeableFound)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
            } else {
                PharosCard {
                    VStack(spacing: 0) {
                        ForEach(cleanup.purgeableBundles) { bundle in
                            ProjectBundleRow(bundle: bundle)
                                .padding(.horizontal, PharosSpacing.xs)
                                .padding(.vertical, PharosSpacing.s)

                            if bundle.id != cleanup.purgeableBundles.last?.id {
                                PharosListDivider()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if cleanup.purgeableBundles.isEmpty, !cleanup.isScanningPurges {
                cleanup.scanProjectPurges()
            }
        }
    }
}

private struct ProjectBundleRow: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared
    let bundle: ProjectPurgeScanner.PurgeableBundle

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 13))
                .foregroundStyle(PharosColor.accent.opacity(0.85))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bundle.projectName)
                        .font(.system(size: 12, weight: .semibold))

                    BundleTypeBadge(type: bundle.bundleType)

                    if bundle.isDormant {
                        Text(l10n.dormantBadge)
                            .font(.system(size: 8.5, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.14)))
                            .foregroundStyle(Color.orange)
                    } else {
                        Text(l10n.activeBadge)
                            .font(.system(size: 8.5, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.green.opacity(0.14)))
                            .foregroundStyle(Color.green)
                    }
                }

                Text(bundle.bundlePath)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(PharosColor.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 8)

            Text(ByteFormat.short(bundle.size))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(PharosColor.textPrimary)
                .frame(width: 52, alignment: .trailing)

            ConfirmButton(
                title: l10n.cleanRow,
                icon: "trash",
                small: true,
                busy: false,
                disabled: cleanup.isBusy
            ) {
                cleanup.purgeBundle(bundle)
            }
            .frame(width: 84, alignment: .trailing)
        }
    }
}

private struct BundleTypeBadge: View {
    let type: ProjectPurgeScanner.BundleType

    var body: some View {
        let (name, color): (String, Color) = switch type {
        case .nodeModules: ("node_modules", .green)
        case .rustTarget: ("target", .orange)
        case .swiftBuild: (".build", .blue)
        case .pythonVenv, .venv: (".venv", .yellow)
        case .nextBuild: (".next", .primary)
        case .nuxtBuild: (".nuxt", .mint)
        case .outputDir: (".output", .teal)
        case .dist, .build: ("dist", .indigo)
        case .cocoaPods: ("Pods", .red)
        case .derivedData: ("DerivedData", .purple)
        }

        Text(name)
            .font(.system(size: 8.5, weight: .medium))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.12)))
            .foregroundStyle(color)
    }
}

// MARK: - Dev & AI Tools View

struct DevAndAIView: View {
    @ObservedObject private var cleanup = CleanupStoreHolder.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: PharosSpacing.l) {
            // 1. Homebrew Deep Cleanup
            homebrewSection

            // 2. Local AI Models
            aiModelsSection

            // 3. Container & Toolchain
            containersSection
        }
        .onAppear {
            if cleanup.homebrewItems.isEmpty, !cleanup.isScanningHomebrew {
                cleanup.scanHomebrew()
            }
            if cleanup.aiModels.isEmpty, !cleanup.isScanningAIModels {
                cleanup.scanAIModels()
            }
            if cleanup.toolchainItems.isEmpty, !cleanup.isScanningToolchain {
                cleanup.scanToolchain()
            }
        }
    }

    // MARK: - Homebrew Section

    private var homebrewSection: some View {
        let total = cleanup.homebrewItems.reduce(0) { $0 + $1.size }
        return VStack(alignment: .leading, spacing: PharosSpacing.s) {
            PharosSectionHeader(title: l10n.homebrewSectionTitle, systemImage: "mug.fill")

            PharosCard {
                VStack(spacing: PharosSpacing.m) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.homebrewSectionSubtitle)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                        Spacer()
                        Text(cleanup.homebrewItems.isEmpty ? "–" : ByteFormat.short(total))
                            .font(PharosFont.captionDigits)
                            .foregroundStyle(total == 0 ? PharosColor.textSecondary : PharosColor.textPrimary)

                        Button {
                            cleanup.scanHomebrew()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .disabled(cleanup.isScanningHomebrew)

                        ConfirmButton(
                            title: l10n.cleanHomebrewAll,
                            icon: "trash",
                            small: true,
                            busy: false,
                            disabled: cleanup.isBusy || cleanup.homebrewItems.isEmpty
                        ) {
                            cleanup.cleanAllHomebrew()
                        }
                    }

                    if cleanup.isScanningHomebrew {
                        ProgressView().controlSize(.small).padding(.vertical, 8)
                    } else if cleanup.homebrewItems.isEmpty {
                        Text(l10n.noSubItems)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textTertiary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(cleanup.homebrewItems) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "shippingbox")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PharosColor.accent)
                                    VStack(alignment: .leading, spacing: 1) {
                                        HStack(spacing: 4) {
                                            Text(item.name).font(.system(size: 11.5, weight: .medium))
                                            if let ver = item.version {
                                                Text(ver)
                                                    .font(.system(size: 8.5, design: .monospaced))
                                                    .padding(.horizontal, 3)
                                                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                                            }
                                        }
                                        Text(item.path)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(PharosColor.textTertiary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(ByteFormat.short(item.size))
                                        .font(.system(size: 10.5).monospacedDigit())
                                        .foregroundStyle(PharosColor.textSecondary)

                                    ConfirmButton(
                                        title: l10n.cleanRow,
                                        icon: "trash",
                                        small: true,
                                        busy: false,
                                        disabled: cleanup.isBusy
                                    ) {
                                        cleanup.cleanHomebrewItem(item)
                                    }
                                    .frame(width: 72, alignment: .trailing)
                                }
                                .padding(.vertical, 4)

                                if item.id != cleanup.homebrewItems.last?.id {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Local AI Models Section

    private var aiModelsSection: some View {
        let total = cleanup.aiModels.reduce(0) { $0 + $1.size }
        return VStack(alignment: .leading, spacing: PharosSpacing.s) {
            PharosSectionHeader(title: l10n.aiModelsSectionTitle, systemImage: "sparkles")

            PharosCard {
                VStack(spacing: PharosSpacing.m) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.aiModelsSectionSubtitle)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                            Text(l10n.aiModelLayerGCNotice)
                                .font(.system(size: 9.5))
                                .foregroundStyle(PharosColor.accent.opacity(0.9))
                        }
                        Spacer()
                        Text(cleanup.aiModels.isEmpty ? "–" : ByteFormat.short(total))
                            .font(PharosFont.captionDigits)
                            .foregroundStyle(total == 0 ? PharosColor.textSecondary : PharosColor.textPrimary)

                        Button {
                            cleanup.scanAIModels()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .disabled(cleanup.isScanningAIModels)
                    }

                    if cleanup.isScanningAIModels {
                        ProgressView().controlSize(.small).padding(.vertical, 8)
                    } else if cleanup.aiModels.isEmpty {
                        Text(l10n.noSubItems)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textTertiary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(cleanup.aiModels) { model in
                                HStack(spacing: 8) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PharosColor.accent)
                                    VStack(alignment: .leading, spacing: 1) {
                                        HStack(spacing: 4) {
                                            Text(model.fullName).font(.system(size: 11.5, weight: .semibold))
                                            Text(model.framework.rawValue)
                                                .font(.system(size: 8.5, weight: .medium))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(Color.teal.opacity(0.14)))
                                                .foregroundStyle(Color.teal)
                                        }
                                        Text(model.path)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(PharosColor.textTertiary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(ByteFormat.short(model.size))
                                        .font(.system(size: 10.5).monospacedDigit())
                                        .foregroundStyle(PharosColor.textSecondary)

                                    ConfirmButton(
                                        title: l10n.cleanAIModel,
                                        icon: "trash",
                                        small: true,
                                        busy: false,
                                        disabled: cleanup.isBusy
                                    ) {
                                        cleanup.deleteAIModel(model)
                                    }
                                    .frame(width: 80, alignment: .trailing)
                                }
                                .padding(.vertical, 4)

                                if model.id != cleanup.aiModels.last?.id {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Container & Simulators Section

    private var containersSection: some View {
        let total = cleanup.toolchainItems.reduce(0) { $0 + $1.size }
        return VStack(alignment: .leading, spacing: PharosSpacing.s) {
            PharosSectionHeader(title: l10n.containersSectionTitle, systemImage: "externaldrive.connected.to.line.below")

            PharosCard {
                VStack(spacing: PharosSpacing.m) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.containersSectionSubtitle)
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                        Spacer()
                        Text(cleanup.toolchainItems.isEmpty ? "–" : ByteFormat.short(total))
                            .font(PharosFont.captionDigits)
                            .foregroundStyle(total == 0 ? PharosColor.textSecondary : PharosColor.textPrimary)

                        Button {
                            cleanup.scanToolchain()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .disabled(cleanup.isScanningToolchain)
                    }

                    if cleanup.isScanningToolchain {
                        ProgressView().controlSize(.small).padding(.vertical, 8)
                    } else if cleanup.toolchainItems.isEmpty {
                        Text(l10n.noSubItems)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textTertiary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(cleanup.toolchainItems) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "cube")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PharosColor.accent)
                                    VStack(alignment: .leading, spacing: 1) {
                                        HStack(spacing: 4) {
                                            Text(item.name).font(.system(size: 11.5, weight: .semibold))
                                            Text(item.category.rawValue)
                                                .font(.system(size: 8.5, weight: .medium))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(Color.indigo.opacity(0.14)))
                                                .foregroundStyle(Color.indigo)
                                        }
                                        if let sub = item.subtitle {
                                            Text(sub)
                                                .font(.system(size: 9.5))
                                                .foregroundStyle(PharosColor.textSecondary)
                                        }
                                        Text(item.path)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(PharosColor.textTertiary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(ByteFormat.short(item.size))
                                        .font(.system(size: 10.5).monospacedDigit())
                                        .foregroundStyle(PharosColor.textSecondary)

                                    ConfirmButton(
                                        title: l10n.cleanToolchainItem,
                                        icon: "trash",
                                        small: true,
                                        busy: false,
                                        disabled: cleanup.isBusy
                                    ) {
                                        cleanup.cleanToolchainItem(item)
                                    }
                                    .frame(width: 80, alignment: .trailing)
                                }
                                .padding(.vertical, 4)

                                if item.id != cleanup.toolchainItems.last?.id {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
