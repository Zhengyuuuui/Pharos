import SwiftUI
import PharosCore

/// Quick-launch matrix offering isolated browser instances:
/// 1. Original/Main profile with pure direct connection (direct://)
/// 2. Isolated profile with Proxy A (e.g. 7890)
/// 3. Isolated profile with Proxy B (e.g. 7897 / custom)
struct BrowserProxyMatrixSection: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var chrome = ChromeStore.shared
    @ObservedObject private var l10n = L10n.shared

    @State private var targetBrowser: ChromiumBrowser?

    var body: some View {
        let b = targetBrowser ?? chrome.defaultBrowser
        let mainRunning = store.chrome.first(where: { $0.config.browser == b && $0.config.isDefaultProfile })
        let isMainDirect = mainRunning?.config.proxyStrategy == .direct

        PharosSection(title: l10n.browserProxyMatrix, systemImage: "network") {
            VStack(alignment: .leading, spacing: PharosSpacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Text(l10n.browserProxyMatrixSubtitle)
                        .font(PharosFont.caption)
                        .foregroundStyle(PharosColor.textSecondary)

                    Spacer()

                    if chrome.installedBrowsers.count > 1 {
                        Picker("", selection: Binding(
                            get: { targetBrowser ?? chrome.defaultBrowser },
                            set: { targetBrowser = $0 }
                        )) {
                            ForEach(chrome.installedBrowsers, id: \.self) { browser in
                                Text(browser.appName).tag(browser)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .controlSize(.small)
                    }
                }

                HStack(spacing: PharosSpacing.m) {
                    // Card 1: Main Profile with Direct
                    let mainBadge = mainRunning != nil ? (isMainDirect ? "运行中 · 已直连" : "运行中 · 跟随系统") : "未运行"
                    let mainBadgeColor = isMainDirect ? PharosColor.success : (mainRunning != nil ? PharosColor.warning : PharosColor.textTertiary)
                    let mainBtnTitle = mainRunning != nil ? l10n.relaunchMainDirect : l10n.launchMainDirect

                    matrixCard(
                        title: l10n.mainProfileTitle,
                        badge: mainBadge,
                        badgeColor: mainBadgeColor,
                        desc: l10n.mainProfileDirectDesc,
                        icon: "bolt.shield.fill",
                        iconColor: PharosColor.success,
                        buttonTitle: mainBtnTitle,
                        buttonIcon: "bolt.fill"
                    ) {
                        chrome.launchMainWithProxy(
                            browser: b,
                            strategy: .direct,
                            running: store.chrome,
                            listening: store.state.listeningPorts,
                            then: { await store.refresh() }
                        )
                    }

                    // Card 2: Isolated Instance with Proxy A (7890)
                    matrixCard(
                        title: l10n.proxyATitle,
                        badge: ":7890",
                        badgeColor: PharosColor.accent,
                        desc: l10n.proxyADesc,
                        icon: "globe.asia.australia.fill",
                        iconColor: PharosColor.accent,
                        buttonTitle: l10n.launchProxyA,
                        buttonIcon: "network"
                    ) {
                        chrome.launchIsolated(
                            name: "\(b.appName) · 代理 A",
                            folderName: "\(b.rawValue)-proxyA",
                            strategy: .clashMixedPort(7890),
                            browser: b,
                            port: 9222,
                            running: store.chrome,
                            listening: store.state.listeningPorts
                        )
                    }

                    // Card 3: Isolated Instance with Proxy B (7897)
                    matrixCard(
                        title: l10n.proxyBTitle,
                        badge: ":7897",
                        badgeColor: PharosColor.warning,
                        desc: l10n.proxyBDesc,
                        icon: "shield.lefthalf.filled",
                        iconColor: PharosColor.warning,
                        buttonTitle: l10n.launchProxyB,
                        buttonIcon: "arrow.triangle.branch"
                    ) {
                        chrome.launchIsolated(
                            name: "\(b.appName) · 代理 B",
                            folderName: "\(b.rawValue)-proxyB",
                            strategy: .clashMixedPort(7897),
                            browser: b,
                            port: 9223,
                            running: store.chrome,
                            listening: store.state.listeningPorts
                        )
                    }
                }
            }
        }
    }

    private func matrixCard(
        title: String,
        badge: String,
        badgeColor: Color,
        desc: String,
        icon: String,
        iconColor: Color,
        buttonTitle: String,
        buttonIcon: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: PharosSpacing.s) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PharosColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(badge)
                    .font(PharosFont.captionDigits)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(badgeColor.opacity(0.12)))
                    .foregroundStyle(badgeColor)
            }

            Text(desc)
                .font(.system(size: 10))
                .foregroundStyle(PharosColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 28, alignment: .topLeading)

            HStack {
                Spacer()
                PharosActionButton(buttonTitle, systemImage: buttonIcon, role: .standard, action: action)
                    .controlSize(.small)
            }
            .padding(.top, 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PharosColor.surfaceSecondary.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PharosColor.separator.opacity(0.25), lineWidth: 0.5)
        )
    }
}
