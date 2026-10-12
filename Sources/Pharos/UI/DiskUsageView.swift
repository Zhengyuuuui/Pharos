import SwiftUI
import PharosCore

/// Used vs. available on one volume; turns orange / red as it fills up.
struct VolumeBar: View {
    let volume: DiskVolume
    var height: CGFloat = 8

    static func tint(_ fraction: Double) -> Color {
        fraction >= 0.95 ? .red : fraction >= 0.85 ? .orange : .blue
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.primary.opacity(0.08))
                Rectangle()
                    .fill(Self.tint(volume.usedFraction))
                    .frame(width: geo.size.width * volume.usedFraction)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 3))
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

    var body: some View {
        let volumes = store.volumes
        let startup = volumes.first { $0.kind == .startup }
        let others = volumes.filter { $0.kind != .startup }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.diskUsage).font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button {
                        AppDelegate.shared?.showMainWindow(selecting: .diskCleanup)
                    } label: {
                        Label(l10n.diskFreeUpSpace, systemImage: "trash")
                    }
                    .controlSize(.small)
                }

                if let s = startup {
                    HStack(spacing: 12) {
                        StatCard(title: l10n.diskUsed, value: ByteFormat.disk(s.used),
                                 detail: "/ \(ByteFormat.disk(s.total)) · \(Int((s.usedFraction * 100).rounded()))%",
                                 icon: "internaldrive", tint: VolumeBar.tint(s.usedFraction) == .blue ? .secondary : VolumeBar.tint(s.usedFraction))
                        StatCard(title: l10n.diskAvailable, value: ByteFormat.disk(s.available),
                                 detail: s.name, icon: "checkmark.circle", tint: .green)
                        StatCard(title: l10n.diskVolumes, value: "\(volumes.count)", icon: "square.stack.3d.up")
                        StatCard(title: l10n.diskExternalCount,
                                 value: "\(others.filter { $0.kind == .external || $0.kind == .network }.count)",
                                 icon: "externaldrive")
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(30)
                }

                ForEach(volumes) { VolumeCard(volume: $0) }

                if !others.contains(where: { $0.kind == .external || $0.kind == .network }) {
                    Label(l10n.diskNoExternal, systemImage: "externaldrive.badge.plus")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(l10n.diskNotice)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct VolumeCard: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    let volume: DiskVolume

    var body: some View {
        let v = volume
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: VolumeIcon.name(v.kind))
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(v.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Text(l10n.diskKind(v.kind))
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                            .foregroundStyle(.secondary)
                        if v.isReadOnly {
                            Text(l10n.diskReadOnly).font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                        if v.usedFraction >= 0.9 {
                            Label(l10n.diskLow, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(VolumeBar.tint(v.usedFraction))
                        }
                    }
                    Text(l10n.diskFreeOf(ByteFormat.disk(v.available), ByteFormat.disk(v.total)))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int((v.usedFraction * 100).rounded()))%")
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(VolumeBar.tint(v.usedFraction) == .blue ? .primary : VolumeBar.tint(v.usedFraction))
                IconButton(systemImage: "folder", help: l10n.diskOpenInFinder) { store.revealVolume(v) }
            }

            VolumeBar(volume: v, height: 12)
            HStack {
                Text("\(l10n.diskUsed) \(ByteFormat.disk(v.used))")
                Spacer()
                Text("\(l10n.diskAvailable) \(ByteFormat.disk(v.available))").foregroundStyle(.green)
            }
            .font(.system(size: 10.5, weight: .medium).monospacedDigit())

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                if let f = v.format { row(l10n.diskFormat, f) }
                if let c = v.connection { row(l10n.diskConnection, c) }
                row(l10n.diskMountPoint, v.path)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.06)))
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 10.5, design: .monospaced)).textSelection(.enabled).lineLimit(1)
        }
    }
}
