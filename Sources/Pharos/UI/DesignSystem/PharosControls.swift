import SwiftUI

/// Button roles from DESIGN.md §2.3/§2.4: neutral fill by default, accent fill for the
/// single primary action, destructive = neutral fill with red text (never a red fill).
/// Hover brightens the fill, press dims and scales slightly (no scale with Reduce Motion).
struct PharosActionButtonStyle: ButtonStyle {
    enum Role { case standard, primary, destructive }

    var role: Role = .standard

    func makeBody(configuration: Configuration) -> some View {
        PharosActionButtonBody(configuration: configuration, role: role)
    }
}

private struct PharosActionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let role: PharosActionButtonStyle.Role

    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    private var compact: Bool { controlSize == .small || controlSize == .mini }

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(compact ? .system(size: 11.5, weight: .medium) : .system(size: 13, weight: role == .primary ? .semibold : .medium))
            .labelStyle(PharosButtonLabelStyle())
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 11 : 16)
            .frame(minHeight: compact ? 24 : 30)
            .background(Capsule(style: .continuous).fill(background(pressed: pressed)))
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { hovering = $0 && isEnabled }
            .animation(.easeOut(duration: 0.12), value: pressed)
            .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var foreground: Color {
        switch role {
        case .standard: return PharosColor.textPrimary
        case .primary: return PharosColor.onAccent
        case .destructive: return PharosColor.error
        }
    }

    private func background(pressed: Bool) -> Color {
        switch role {
        case .primary:
            return PharosColor.accentFill.opacity(pressed ? 0.78 : (hovering ? 0.9 : 1))
        case .standard:
            return pressed ? PharosColor.fillPressed : (hovering ? PharosColor.fillHover : PharosColor.fill)
        case .destructive:
            return pressed ? PharosColor.error.opacity(0.22) : (hovering ? PharosColor.error.opacity(0.14) : PharosColor.fill)
        }
    }
}

/// Icon + title with tight, consistent spacing inside capsule buttons.
struct PharosButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

extension ButtonStyle where Self == PharosActionButtonStyle {
    static var pharos: PharosActionButtonStyle { PharosActionButtonStyle() }
    static var pharosPrimary: PharosActionButtonStyle { PharosActionButtonStyle(role: .primary) }
    static var pharosDestructive: PharosActionButtonStyle { PharosActionButtonStyle(role: .destructive) }
}

/// Convenience view for action buttons following DESIGN.md §2.3/§2.4.
struct PharosActionButton: View {
    let title: String
    var systemImage: String? = nil
    var role: PharosActionButtonStyle.Role = .standard
    var action: () -> Void

    init(_ title: String, systemImage: String? = nil, role: PharosActionButtonStyle.Role = .standard, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(PharosActionButtonStyle(role: role))
    }
}

/// Circular icon-only button. `ghost` is transparent until hovered (dense rows),
/// `filled` sits on a neutral disc (standalone). `help` doubles as the accessibility label.
struct PharosIconButton: View {
    enum Variant { case ghost, filled }

    let systemImage: String
    let help: String
    var tint: Color = PharosColor.textSecondary
    var variant: Variant = .ghost
    var size: CGFloat = 24
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
        .buttonStyle(PharosIconButtonStyle(variant: variant))
        .help(help)
        .accessibilityLabel(help)
    }
}

struct PharosIconButtonStyle: ButtonStyle {
    var variant: PharosIconButton.Variant = .ghost

    func makeBody(configuration: Configuration) -> some View {
        PharosIconButtonBody(configuration: configuration, variant: variant)
    }
}

private struct PharosIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let variant: PharosIconButton.Variant
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(Circle().fill(fill(pressed: pressed)))
            .contentShape(Circle())
            .scaleEffect(pressed && !reduceMotion ? 0.92 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovering = $0 && isEnabled }
            .animation(.easeOut(duration: 0.12), value: pressed)
            .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private func fill(pressed: Bool) -> Color {
        if pressed { return PharosColor.fillPressed }
        if hovering { return PharosColor.fillHover }
        return variant == .filled ? PharosColor.fill : .clear
    }
}

/// Dismiss button for banners, sheets and panels: a small neutral disc with a bold ×.
/// Only for closing UI — cancelling a confirmation is done by `PharosConfirmButton` itself.
struct PharosCloseButton: View {
    let help: String
    var size: CGFloat = 20
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(PharosColor.textSecondary)
                .frame(width: size, height: size)
        }
        .buttonStyle(PharosIconButtonStyle(variant: .filled))
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Two-step destructive action in place: the first click turns the same capsule into a red
/// "confirm" prompt (no extra × button, no layout jump); a second click runs `action`.
/// It disarms on its own after `timeout`, when the pointer leaves, or with Esc.
/// While `isWorking`, it shows a spinner with `workingTitle` and ignores clicks.
struct PharosConfirmButton: View {
    let title: String
    var systemImage: String? = nil
    let confirmTitle: String
    var workingTitle: String? = nil
    var isWorking = false
    /// Icon-only resting state for dense rows; still expands into the confirm capsule.
    var iconOnly = false
    var timeout: Double = 3
    let action: () -> Void

    @State private var armed = false

    var body: some View {
        Group {
            if isWorking {
                HStack(spacing: 5) {
                    ProgressView().controlSize(.mini)
                    if let workingTitle { Text(workingTitle) }
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(PharosColor.textSecondary)
                .padding(.horizontal, 11)
                .frame(minHeight: 24)
                .background(Capsule(style: .continuous).fill(PharosColor.fill))
                .fixedSize()
            } else if armed {
                Button {
                    armed = false
                    action()
                } label: {
                    Label(confirmTitle, systemImage: "exclamationmark.circle")
                }
                .buttonStyle(.pharosDestructive)
                // No Return shortcut: with several rows armed, or focus in a text field,
                // Return could kill the wrong process. Destructive confirm must be a click.
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .task {
                    try? await Task.sleep(for: .seconds(timeout))
                    withAnimation(.easeOut(duration: 0.15)) { armed = false }
                }
                .background(
                    // Esc disarms without needing a separate cancel button.
                    Button("") { withAnimation(.easeOut(duration: 0.15)) { armed = false } }
                        .keyboardShortcut(.cancelAction)
                        .opacity(0)
                        .allowsHitTesting(false)
                )
            } else if iconOnly, let systemImage {
                PharosIconButton(systemImage: systemImage, help: title, tint: PharosColor.error.opacity(0.85)) {
                    withAnimation(.easeOut(duration: 0.15)) { armed = true }
                }
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { armed = true }
                } label: {
                    if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
                }
                .buttonStyle(.pharosDestructive)
            }
        }
        .controlSize(.small)
        .accessibilityHint(armed ? confirmTitle : "")
    }
}

/// "⋯" overflow menu for secondary row actions, styled like a ghost icon button.
struct PharosMoreMenu<Content: View>: View {
    let help: String
    @ViewBuilder let content: Content

    var body: some View {
        Menu {
            content
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PharosColor.textSecondary)
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Standard scrolling page: title row, then sections spaced by `PharosSpacing.section`,
/// on the shared window background.
struct PharosPage<Header: View, Content: View>: View {
    var maxWidth: CGFloat = .infinity
    @ViewBuilder var header: Header
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PharosSpacing.section) {
                header.padding(.horizontal, PharosSpacing.xs)
                content
            }
            .padding(PharosSpacing.page)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pharosSlimScroller()
        }
        .background(Color.clear)
    }
}

/// Title + optional subtitle + trailing accessories, used as `PharosPage` header.
struct PharosPageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: PharosSpacing.m) {
            VStack(alignment: .leading, spacing: PharosSpacing.xxs) {
                Text(title).font(PharosFont.pageTitle).lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: PharosSpacing.s)
            trailing
        }
    }
}

extension PharosPageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Label (+ optional help / caption) on the left, native control on the right.
struct PharosSettingRow<Control: View>: View {
    let title: String
    var systemImage: String? = nil
    var help: String? = nil
    var caption: String? = nil
    @ViewBuilder var control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: PharosSpacing.xs) {
            HStack(spacing: PharosSpacing.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13))
                        .foregroundStyle(PharosColor.textSecondary)
                        .frame(width: 18)
                }
                Text(title).font(PharosFont.rowLabel)
                if let help {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(PharosColor.textTertiary)
                        .help(help)
                }
                Spacer(minLength: PharosSpacing.m)
                control
            }
            if let caption {
                Text(caption)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, systemImage == nil ? 0 : 26)
            }
        }
    }
}

/// Empty / unavailable / error placeholder inside a card or page.
struct PharosEmptyState<Actions: View>: View {
    let title: String
    let systemImage: String
    var message: String? = nil
    var tint: Color = PharosColor.textTertiary
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: PharosSpacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(tint)
            Text(title).font(PharosFont.rowLabel)
            if let message {
                Text(message)
                    .font(PharosFont.caption)
                    .foregroundStyle(PharosColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            actions.padding(.top, PharosSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PharosSpacing.xxl)
        .padding(.horizontal, PharosSpacing.l)
    }
}

extension PharosEmptyState where Actions == EmptyView {
    init(title: String, systemImage: String, message: String? = nil, tint: Color = PharosColor.textTertiary) {
        self.init(title: title, systemImage: systemImage, message: message, tint: tint) { EmptyView() }
    }
}

/// Result / error banner (DESIGN.md §8): low-opacity semantic tint + symbol + text.
struct PharosBanner<Accessory: View>: View {
    enum Kind { case success, warning, error, info }

    let kind: Kind
    let text: String
    @ViewBuilder var accessory: Accessory

    private var color: Color {
        switch kind {
        case .success: return PharosColor.success
        case .warning: return PharosColor.warning
        case .error: return PharosColor.error
        case .info: return PharosColor.accent
        }
    }

    private var symbol: String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PharosSpacing.s) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text)
                .font(PharosFont.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Spacer(minLength: PharosSpacing.s)
            accessory
        }
        .padding(.horizontal, PharosSpacing.m)
        .padding(.vertical, PharosSpacing.s + 2)
        .background(RoundedRectangle(cornerRadius: PharosRadius.control, style: .continuous)
            .fill(color.opacity(0.1)))
    }
}

extension PharosBanner where Accessory == EmptyView {
    init(kind: Kind, text: String) {
        self.init(kind: kind, text: text) { EmptyView() }
    }
}

/// Small neutral capsule for tags, counts and inline technical values.
struct PharosTag: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color? = nil
    var monospaced = false

    init(_ text: String, systemImage: String? = nil, tint: Color? = nil, monospaced: Bool = false) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
        self.monospaced = monospaced
    }

    init(text: String, systemImage: String? = nil, tint: Color? = nil, monospaced: Bool = false) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
        self.monospaced = monospaced
    }

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(monospaced ? .system(size: 10.5, weight: .medium, design: .monospaced) : .system(size: 10.5, weight: .medium))
        .foregroundStyle(tint ?? PharosColor.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule(style: .continuous).fill(tint.map { $0.opacity(0.12) } ?? PharosColor.fill))
    }
}

/// Inset list inside a card: rows separated by hairlines, no zebra striping.
struct PharosListDivider: View {
    var body: some View {
        Rectangle()
            .fill(PharosColor.separator.opacity(0.6))
            .frame(height: 0.5)
    }
}

/// Capsule search field with wireframe magnifying glass and clear button.
struct PharosSearchField: View {
    @Binding var text: String
    var prompt: String = ""

    var body: some View {
        HStack(spacing: PharosSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(PharosColor.textTertiary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(PharosFont.body)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PharosColor.textTertiary)
                }
                .buttonStyle(.plain)
                .help(L10n.shared.clearSearch)
            }
        }
        .padding(.horizontal, PharosSpacing.s + 2)
        .padding(.vertical, PharosSpacing.xs + 1)
        .background(Capsule(style: .continuous).fill(PharosColor.fill))
    }
}
