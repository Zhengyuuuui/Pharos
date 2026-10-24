import SwiftUI
import PharosCore

/// Used vs. available on one volume; turns orange / red as it fills up.
struct VolumeBar: View {
    let volume: DiskVolume
    var height: CGFloat = 8

    static func tint(_ fraction: Double) -> Color {
        fraction >= 0.95 ? PharosColor.error : fraction >= 0.85 ? PharosColor.warning : PharosColor.accent
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(PharosColor.fill)
                Capsule(style: .continuous)
                    .fill(Self.tint(volume.usedFraction))
                    .frame(width: max(0, min(geo.size.width, geo.size.width * volume.usedFraction)))
            }
        }
        .frame(height: height)
    }
}

enum VolumeIcon {
    static func name(_ k: DiskVolume.Kind) -> String {
        switch k {
        case .startup, .internalDisk: return "internaldrive"
        case .external: return "externaldrive"
        case .network: return "server.rack"
        case .diskImage: return "opticaldiscdrive"
        }
    }
}

/// Popover overview: one compact row per volume, under system memory.
struct PopoverDiskSection: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.diskUsage).font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    AppDelegate.shared?.showMainWindow(selecting: .diskUsage)
                } label: {
                    Text(l10n.manage).font(.system(size: 10))
                }
                .buttonStyle(.borderless)
            }
            ForEach(store.volumes) { v in
                Button { store.revealVolume(v) } label: { row(v) }
                    .buttonStyle(.plain)
                    .help("\(l10n.diskOpenInFinder) · \(v.path)")
            }
        }
    }

    private func row(_ v: DiskVolume) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: VolumeIcon.name(v.kind))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(v.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                if v.kind != .startup {
                    Text(l10n.diskKind(v.kind)).font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 4)
                Text("\(ByteFormat.disk(v.used)) / \(ByteFormat.disk(v.total))")
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                Text("· \(l10n.diskAvailable) \(ByteFormat.disk(v.available))")
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(v.usedFraction >= 0.85 ? VolumeBar.tint(v.usedFraction) : .green)
            }
            VolumeBar(volume: v, height: 6)
        }
        .contentShape(Rectangle())
    }
}

/// Main window page: every mounted volume with capacity, format and connection.
struct DiskUsageView: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared

    private let metricColumns = [GridItem(.adaptive(minimum: 150), spacing: PharosSpacing.l, alignment: .top)]

    var body: some View {
        let volumes = store.volumes
        let startup = volumes.first { $0.kind == .startup }
        let others = volumes.filter { $0.kind != .startup }

        PharosPage {
            PharosPageHeader(title: l10n.diskUsage) {
                PharosActionButton(l10n.diskFreeUpSpace, systemImage: "trash", role: .standard) {
                    AppDelegate.shared?.showMainWindow(selecting: .diskCleanup)
                }
                .controlSize(.small)
            }
        } content: {
            if let s = startup {
                PharosSection(title: l10n.overview, systemImage: "internaldrive") {
                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: PharosSpacing.l) {
                        PharosMetricValue(
                            title: l10n.diskUsed,
                            value: ByteFormat.disk(s.used),
                            detail: "/ \(ByteFormat.disk(s.total)) · \(Int((s.usedFraction * 100).rounded()))%",
                            systemImage: "internaldrive"
                        )
                        PharosMetricValue(
                            title: l10n.diskAvailable,
                            value: ByteFormat.disk(s.available),
                            detail: s.name,
                            systemImage: "checkmark.circle"
                        )
                        PharosMetricValue(
                            title: l10n.diskVolumes,
                            value: "\(volumes.count)",
                            systemImage: "square.stack.3d.up"
                        )
                        PharosMetricValue(
                            title: l10n.diskExternalCount,
                            value: "\(others.filter { $0.kind == .external || $0.kind == .network }.count)",
                            systemImage: "externaldrive"
                        )
                    }
                }
            } else {
                PharosCard {
                    ProgressView().frame(maxWidth: .infinity).padding(PharosSpacing.xxl)
                }
            }

            VStack(alignment: .leading, spacing: PharosSpacing.titleToCard) {
                PharosSectionHeader(title: l10n.diskVolumes, systemImage: "square.stack.3d.up")
                    .padding(.horizontal, PharosSpacing.xs)
                VStack(spacing: PharosSpacing.m) {
                    ForEach(volumes) { VolumeCard(volume: $0) }
                }
            }

            if !others.contains(where: { $0.kind == .external || $0.kind == .network }) {
                Label(l10n.diskNoExternal, systemImage: "externaldrive.badge.plus")
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                    .padding(.horizontal, PharosSpacing.xs)
            }

            PharosBanner(kind: .info, text: l10n.diskNotice)
        }
    }
}

private struct VolumeCard: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let volume: DiskVolume

    var body: some View {
        let v = volume
        PharosCard {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack(spacing: PharosSpacing.s) {
                    Image(systemName: VolumeIcon.name(v.kind))
                        .font(.system(size: 18))
                        .foregroundStyle(PharosColor.textSecondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                        HStack(spacing: PharosSpacing.xs + 2) {
                            Text(v.name).font(PharosFont.rowLabel).lineLimit(1)
                            PharosTag(text: l10n.diskKind(v.kind))
                            if v.isReadOnly {
                                PharosTag(text: l10n.diskReadOnly, tint: PharosColor.textTertiary)
                            }
                            if v.usedFraction >= 0.9 {
                                PharosTag(text: l10n.diskLow, systemImage: "exclamationmark.triangle.fill", tint: PharosColor.error)
                            }
                        }
                        Text(l10n.diskFreeOf(ByteFormat.disk(v.available), ByteFormat.disk(v.total)))
                            .font(PharosFont.captionDigits)
                            .foregroundStyle(PharosColor.textSecondary)
                    }
                    Spacer()
                    Text("\(Int((v.usedFraction * 100).rounded()))%")
                        .font(PharosFont.metricValue)
                        .foregroundStyle(v.usedFraction >= 0.85 ? VolumeBar.tint(v.usedFraction) : PharosColor.textPrimary)
                    IconButton(systemImage: "folder", help: l10n.diskOpenInFinder) { store.revealVolume(v) }
                }

                VolumeBar(volume: v, height: 8)

                HStack {
                    Text("\(l10n.diskUsed) \(ByteFormat.disk(v.used))")
                        .foregroundStyle(PharosColor.textSecondary)
                    Spacer()
                    Text("\(l10n.diskAvailable) \(ByteFormat.disk(v.available))")
                        .foregroundStyle(PharosColor.success)
                }
                .font(PharosFont.captionDigits)

                Grid(alignment: .leading, horizontalSpacing: PharosSpacing.m, verticalSpacing: PharosSpacing.xs) {
                    if let f = v.format { row(l10n.diskFormat, f) }
                    if let c = v.connection { row(l10n.diskConnection, c) }
                    row(l10n.diskMountPoint, v.path)
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).font(PharosFont.caption).foregroundStyle(PharosColor.textSecondary)
            Text(value).font(PharosFont.technical).textSelection(.enabled).lineLimit(1)
        }
    }
}
