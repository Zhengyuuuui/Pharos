import AppKit
import SwiftUI
import PharosCore

extension PackageView {
    // MARK: - Featured Tools Shelf
    var featuredToolsShelf: some View {
        let tools = store.featuredShelfTools
        return Group {
            if !tools.isEmpty {
                VStack(alignment: .leading, spacing: PharosSpacing.titleToCard) {
                    PharosSectionHeader(title: l10n.featuredToolsTitle, systemImage: "sparkles.rectangle.stack") {
                        HStack(spacing: PharosSpacing.s) {
                            PharosTag(l10n.readyToolsCount(tools.count), tint: PharosColor.warning)

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isFeaturedShelfExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: PharosSpacing.xxs) {
                                    Text(isFeaturedShelfExpanded ? l10n.collapseSection : l10n.expandSection)
                                    Image(systemName: isFeaturedShelfExpanded ? "chevron.up" : "chevron.down")
                                }
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, PharosSpacing.xs)

                    if isFeaturedShelfExpanded {
                        Text(l10n.featuredToolsSubtitle)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                            .padding(.horizontal, PharosSpacing.xs)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: PharosSpacing.m)],
                            spacing: PharosSpacing.m
                        ) {
                            ForEach(tools) { item in
                                featuredToolCard(item)
                            }
                        }
                    }
                }
            }
        }
    }

    func featuredToolCard(_ item: LocalPackageItem) -> some View {
        let color = featuredColor(for: item)
        return PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                // Header: Icon, Name, Category Tag, Version, Ecosystem
                HStack(alignment: .center, spacing: PharosSpacing.s) {
                    Image(systemName: featuredIcon(for: item))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 24, height: 24)
                        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: PharosSpacing.xs) {
                            Text(item.name)
                                .font(PharosFont.rowLabel)
                                .fontWeight(.semibold)

                            if let tag = item.categoryTag {
                                PharosTag(tag, tint: color)
                            }
                        }

                        if let v = item.installedVersion {
                            Text(v.hasPrefix("v") ? v : "v\(v)")
                                .font(PharosFont.captionDigits)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                    }

                    Spacer()

                    Text(item.ecosystem.displayName)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                                .fill(PharosColor.fill)
                        )
                }

                // Description
                if let sum = item.summary, !sum.isEmpty {
                    Text(sum)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 26, alignment: .topLeading)
                } else {
                    Spacer().frame(height: 26)
                }

                // Path hint
                if let exec = item.executablePath ?? Optional(item.installPath) {
                    Text(exec)
                        .font(PharosFont.technical)
                        .foregroundStyle(PharosColor.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                PharosListDivider()

                // Quick Action Buttons
                HStack(spacing: PharosSpacing.xs) {
                    Button {
                        store.testInTerminal(command: item.name)
                    } label: {
                        Label(l10n.runInTerminal, systemImage: "terminal")
                    }
                    .buttonStyle(.pharos)
                    .controlSize(.small)
                    .help(l10n.runCommandTest)

                    Button(role: .destructive) {
                        itemToUninstall = item
                        showUninstallAlert = true
                    } label: {
                        Label(l10n.uninstall, systemImage: "trash")
                    }
                    .buttonStyle(.pharosDestructive)
                    .controlSize(.small)
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
                        .font(PharosFont.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(copiedFeedbackId == item.id ? PharosColor.success : PharosColor.textSecondary)
                }
            }
        }
    }

    func featuredColor(for item: LocalPackageItem) -> Color {
        guard let tag = item.categoryTag else { return Color.accentColor }
        switch tag {
        case "AI 助手": return Color.purple
        case "开发构建": return Color.blue
        case "包管理": return Color.orange
        case "终端效率": return Color.green
        default: return Color.accentColor
        }
    }

    func featuredIcon(for item: LocalPackageItem) -> String {
        guard let tag = item.categoryTag else { return "bolt.fill" }
        switch tag {
        case "AI 助手": return "sparkles"
        case "开发构建": return "hammer.fill"
        case "包管理": return "shippingbox.fill"
        case "终端效率": return "bolt.fill"
        default: return "bolt.fill"
        }
    }

    func cliRow(_ item: LocalPackageItem) -> some View {
        let isSelected = (store.selectedCliId == item.id)
        return VStack(alignment: .leading, spacing: PharosSpacing.xs) {
            HStack(alignment: .center, spacing: PharosSpacing.s) {
                Image(systemName: item.ecosystem.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(ecosystemColor(item.ecosystem))
                    .frame(width: 20)

                Text(item.name)
                    .font(PharosFont.rowLabel)
                    .fontWeight(.semibold)

                if item.isFeatured {
                    PharosTag(item.categoryTag ?? l10n.coreSoftwareBadge, systemImage: "sparkles", tint: PharosColor.warning)
                }

                if let v = item.installedVersion {
                    Text(v.hasPrefix("v") ? v : "v\(v)")
                        .font(PharosFont.captionDigits)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(PharosColor.fill))
                }

                Text(item.ecosystem.displayName)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                            .fill(PharosColor.fill)
                    )

                if let lic = item.license {
                    Text(lic)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                                .fill(PharosColor.fill)
                        )
                }

                Spacer()

                HStack(spacing: PharosSpacing.xs) {
                    Button(role: .destructive) {
                        itemToUninstall = item
                        showUninstallAlert = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                            Text(l10n.uninstall)
                        }
                    }
                    .buttonStyle(.pharosDestructive)
                    .controlSize(.small)
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
                        .font(PharosFont.caption)
                    }
                    .buttonStyle(.pharos)
                    .controlSize(.small)
                }
            }

            if let summary = item.summary, !summary.isEmpty {
                Text(summary)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: PharosSpacing.s) {
                if let exec = item.executablePath {
                    Text(exec)
                        .font(PharosFont.technical)
                        .foregroundStyle(PharosColor.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                if item.fileSizeBytes > 0 {
                    Text(ByteFormat.short(item.fileSizeBytes))
                        .font(PharosFont.captionDigits)
                        .foregroundStyle(PharosColor.textSecondary)
                }
            }
        }
        .padding(PharosSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                .fill(isSelected ? PharosColor.accent.opacity(0.12) : PharosColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                .stroke(isSelected ? PharosColor.accent.opacity(0.4) : PharosColor.separator.opacity(0.25), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectedCliId = (isSelected ? nil : item.id)
        }
    }


    // MARK: - Primary Bundle Hero Card
    func primaryBundleHeroCard(_ summary: ProjectDependencySummary) -> some View {
        let bundleName = summary.primaryBundleName
        let bundlePath = summary.primaryBundlePath
        let exists = summary.isBundleInstalled
        let color = ecosystemColor(summary.ecosystem)
        let isExpanded = isPackagesBreakdownExpanded

        return PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                // 1. Top row: Bundle Icon, Name, Ecosystem, Subtitle & Ready status
                HStack(alignment: .top, spacing: PharosSpacing.m) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 42, height: 42)
                        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous))

                    VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                        HStack(spacing: PharosSpacing.s) {
                            Text(bundleName)
                                .font(PharosFont.sectionTitle)
                                .foregroundStyle(PharosColor.textPrimary)

                            Text(summary.ecosystem.displayName)
                                .font(PharosFont.caption)
                                .foregroundStyle(color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(color.opacity(0.12)))

                            Spacer()

                            // Status Badge
                            if exists && summary.missingDependenciesCount == 0 {
                                PharosTag(l10n.bundleInstalledReady, systemImage: "checkmark.circle.fill", tint: PharosColor.success)
                            } else if summary.missingDependenciesCount > 0 {
                                PharosTag("\(summary.missingDependenciesCount) \(l10n.statusMissing)", systemImage: "exclamationmark.triangle.fill", tint: PharosColor.error)
                            } else {
                                PharosTag(l10n.bundleNotInstalled, systemImage: "info.circle.fill", tint: PharosColor.warning)
                            }
                        }

                        Text(l10n.bundleSubtitle(for: summary.ecosystem, bundleName: bundleName))
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                    }
                }

                // 2. Middle Row: Prominent Disk Size & Stats Pills
                HStack(alignment: .firstTextBaseline, spacing: PharosSpacing.l) {
                    VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                        Text(l10n.bundleTotalSize)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                        Text(summary.dependenciesSizeBytes > 0 ? ByteFormat.short(summary.dependenciesSizeBytes) : (exists ? "0 B" : l10n.noCacheYet))
                            .font(PharosFont.metricValue)
                            .foregroundStyle(PharosColor.textPrimary)
                    }

                    Spacer()

                    // Stat Pills
                    HStack(spacing: PharosSpacing.s) {
                        statPill(label: l10n.totalPackagesCountLabel, value: "\(summary.packages.count)", icon: "shippingbox")
                        statPill(label: l10n.declaredCountLabel, value: "\(summary.directDependenciesCount)", icon: "checkmark.seal")
                        statPill(label: l10n.devDepsCountLabel, value: "\(summary.packages.filter(\.isDevDependency).count)", icon: "hammer")
                        if summary.missingDependenciesCount > 0 {
                            statPill(label: l10n.missingDepsCountLabel, value: "\(summary.missingDependenciesCount)", icon: "exclamationmark.triangle.fill", color: PharosColor.error)
                        }
                    }
                }

                // 3. Bundle Path & Quick Actions
                HStack(spacing: PharosSpacing.s) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundStyle(PharosColor.textSecondary)

                    Text(bundlePath.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(PharosFont.technical)
                        .foregroundStyle(PharosColor.textSecondary)
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
                        }
                        .buttonStyle(.pharos)
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
                    }
                    .buttonStyle(.pharos)
                    .controlSize(.small)

                    if exists {
                        Button {
                            bundleToDelete = summary
                            showDeleteBundleAlert = true
                        } label: {
                            HStack(spacing: 4) {
                                if store.isDeletingBundle {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "trash")
                                }
                                Text(l10n.deleteDependencyBundle)
                            }
                        }
                        .buttonStyle(.pharosDestructive)
                        .controlSize(.small)
                        .disabled(store.isDeletingBundle)
                    }
                }
                .padding(.horizontal, PharosSpacing.s)
                .padding(.vertical, PharosSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                        .fill(PharosColor.fill)
                )

                if let successName = store.deleteBundleSuccess {
                    PharosBanner(kind: .info, text: l10n.deleteBundleSuccessNotice(successName)) {
                        IconButton(systemImage: "xmark", help: l10n.cancel) {
                            store.deleteBundleSuccess = nil
                        }
                    }
                }

                if let err = store.deleteBundleError {
                    PharosBanner(kind: .error, text: err) {
                        IconButton(systemImage: "xmark", help: l10n.cancel) {
                            store.deleteBundleError = nil
                        }
                    }
                }

                // 4. Missing warning / install tip (if any)
                if summary.missingDependenciesCount > 0 || !exists {
                    let installCmd = l10n.missingInstallCommand(for: summary.ecosystem)
                    PharosBanner(kind: .warning, text: "\(l10n.missingDependenciesWarn): \(installCmd)") {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(installCmd, forType: .string)
                        } label: {
                            Text(l10n.copyCliCommand)
                        }
                        .buttonStyle(.pharos)
                        .controlSize(.small)
                    }
                }

                PharosListDivider()

                // 5. Expand / Collapse Trigger Bar
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isDetailedExpanded = !isExpanded
                    }
                } label: {
                    HStack(spacing: PharosSpacing.s) {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(PharosColor.accent)

                        Text(isExpanded ? l10n.collapseDetailedDependencies : l10n.expandDetailedDependencies(summary.packages.count))
                            .font(PharosFont.rowLabel)
                            .foregroundStyle(PharosColor.textPrimary)

                        Spacer()

                        Text(l10n.modeConfigNotice)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textTertiary)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
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


    func statPill(label: String, value: String, icon: String, color: Color = .primary) -> some View {
        HStack(spacing: PharosSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color == .primary ? PharosColor.textSecondary : color)
            Text(label + ":")
                .font(PharosFont.caption)
                .foregroundStyle(PharosColor.textSecondary)
            Text(value)
                .font(PharosFont.captionDigits)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, PharosSpacing.s)
        .padding(.vertical, PharosSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                .fill(PharosColor.fill)
        )
    }

    func projectPackageRow(_ pkg: LocalPackageItem) -> some View {
        HStack(alignment: .center, spacing: PharosSpacing.m) {
            // Status Icon & Badge
            healthBadge(pkg.healthStatus)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: PharosSpacing.s) {
                    Text(pkg.name)
                        .font(PharosFont.rowLabel)
                        .fontWeight(.semibold)

                    if pkg.isDevDependency {
                        Text("dev")
                            .font(PharosFont.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(PharosColor.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                                    .fill(PharosColor.fill)
                            )
                    }

                    if let lic = pkg.license {
                        Text(lic)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: PharosRadius.small, style: .continuous)
                                    .fill(PharosColor.fill)
                            )
                    }

                    Spacer()

                    // Versions Comparison
                    HStack(spacing: PharosSpacing.xs) {
                        if let dec = pkg.declaredVersion {
                            Text("\(l10n.declaredVersion): \(dec)")
                                .font(PharosFont.technical)
                                .foregroundStyle(PharosColor.textSecondary)
                        }
                        if let inst = pkg.installedVersion {
                            Text("→")
                                .font(PharosFont.caption)
                                .foregroundStyle(PharosColor.textSecondary)
                            Text("\(l10n.installedVersion): \(inst)")
                                .font(PharosFont.technical)
                                .fontWeight(.medium)
                                .foregroundStyle(pkg.healthStatus == .mismatched ? PharosColor.warning : PharosColor.textPrimary)
                        }
                    }
                }

                if let summary = pkg.summary, !summary.isEmpty {
                    Text(summary)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if pkg.fileSizeBytes > 0 {
                Text(ByteFormat.short(pkg.fileSizeBytes))
                    .font(PharosFont.captionDigits)
                    .foregroundStyle(PharosColor.textSecondary)
            }

            IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                store.revealInFinder(path: pkg.installPath)
            }
        }
        .padding(PharosSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                .fill(PharosColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                .stroke(PharosColor.separator.opacity(0.25), lineWidth: 0.5)
        )
    }

    func healthBadge(_ status: DependencyHealthStatus) -> some View {
        switch status {
        case .normal:
            return PharosTag(l10n.statusNormal, tint: PharosColor.success)
        case .missing:
            return PharosTag(l10n.statusMissing, tint: PharosColor.error)
        case .symlinkedWorkspace:
            return PharosTag(l10n.statusWorkspace, tint: PharosColor.accent)
        case .mismatched:
            return PharosTag(l10n.statusMismatched, tint: PharosColor.warning)
        }
    }


    func cacheCard(_ repo: PackageCacheRepoSummary) -> some View {
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.s) {
                HStack(alignment: .center, spacing: PharosSpacing.s) {
                    Image(systemName: repo.ecosystem.iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(ecosystemColor(repo.ecosystem))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(repo.name)
                            .font(PharosFont.rowLabel)
                            .fontWeight(.semibold)
                        Text(repo.ecosystem.displayName)
                            .font(PharosFont.caption)
                            .foregroundStyle(PharosColor.textSecondary)
                    }
                    Spacer()

                    HStack(spacing: PharosSpacing.xs) {
                        if repo.id == "homebrew-cache" {
                            Button {
                                store.runHomebrewCleanup()
                            } label: {
                                Label("brew cleanup", systemImage: "sparkles")
                            }
                            .controlSize(.small)
                            .buttonStyle(.pharos)
                            .help(l10n.homebrewCleanCacheHelp)

                            Button {
                                store.cleanHomebrewCacheDirectly()
                            } label: {
                                Label(l10n.cleanRow, systemImage: "trash")
                            }
                            .controlSize(.small)
                            .buttonStyle(.pharosDestructive)
                            .help(l10n.homebrewCleanDirectlyBtn)
                        }

                        IconButton(systemImage: "folder", help: l10n.revealInFinder) {
                            store.revealInFinder(path: repo.rootPath)
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(ByteFormat.disk(repo.fileSizeBytes))
                        .font(PharosFont.metricValue)
                    Spacer()
                    Text("\(repo.itemCount) \(l10n.fileCount.lowercased())")
                        .font(PharosFont.captionDigits)
                        .foregroundStyle(PharosColor.textSecondary)
                }

                Text(repo.description)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                    .lineLimit(2)

                Text(repo.rootPath)
                    .font(PharosFont.technical)
                    .foregroundStyle(PharosColor.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }


    // MARK: - Helper Views
    func totalCliFilterCard() -> some View {
        let isSelected = (store.selectedEcosystem == nil && !store.onlyFeatured)
        let activeColor = PharosColor.accent
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                store.selectedEcosystem = nil
                store.onlyFeatured = false
            }
        } label: {
            VStack(alignment: .leading, spacing: PharosSpacing.xs) {
                HStack {
                    Label(l10n.totalCliToolsCount, systemImage: "terminal.fill")
                        .font(PharosFont.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? activeColor : PharosColor.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if isSelected {
                        Circle()
                            .fill(activeColor)
                            .frame(width: 5, height: 5)
                    }
                }
                Text("\(store.globalCliCount)")
                    .font(Font.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(isSelected ? activeColor : PharosColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(PharosSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                    .fill(isSelected ? activeColor.opacity(0.12) : PharosColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                    .stroke(isSelected ? activeColor.opacity(0.8) : PharosColor.separator.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l10n.showAllCliTools)
    }

    func featuredCliFilterCard() -> some View {
        let isSelected = store.onlyFeatured
        let activeColor = PharosColor.warning
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                store.onlyFeatured.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: PharosSpacing.xs) {
                HStack {
                    Label(l10n.featuredSoftwareCard, systemImage: "sparkles")
                        .font(PharosFont.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? activeColor : PharosColor.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if isSelected {
                        Circle()
                            .fill(activeColor)
                            .frame(width: 5, height: 5)
                    }
                }
                Text("\(store.featuredCliCount)")
                    .font(Font.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(isSelected ? activeColor : PharosColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(PharosSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                    .fill(isSelected ? activeColor.opacity(0.14) : PharosColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                    .stroke(isSelected ? activeColor.opacity(0.8) : PharosColor.separator.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l10n.filterByFeaturedHelp)
    }

    func ecosystemFilterCard(
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
            VStack(alignment: .leading, spacing: PharosSpacing.xs) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(PharosFont.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? color : PharosColor.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                }
                Text("\(count)")
                    .font(Font.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(isSelected ? color : PharosColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(PharosSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                    .fill(isSelected ? color.opacity(0.14) : PharosColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
                    .stroke(isSelected ? color.opacity(0.85) : PharosColor.separator.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(l10n.filterByEcosystemHelp(title))
    }

    func statCard(_ title: String, _ value: String, icon: String, color: Color? = nil) -> some View {
        PharosCard {
            PharosMetricValue(title: title, value: value, systemImage: icon)
        }
    }

    var loadingPlaceholder: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(l10n.loading).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    func ecosystemColor(_ eco: PackageEcosystem) -> Color {
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
