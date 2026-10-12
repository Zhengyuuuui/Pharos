import SwiftUI
import ServiceManagement

/// Shared settings controls, used by both the popover and the main window.
struct SettingsForm: View {
    @EnvironmentObject var store: ProjectStore
    @ObservedObject private var l10n = L10n.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(l10n.languageTitle, selection: $l10n.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .font(.system(size: 12))

            Picker(l10n.refreshEvery, selection: $store.refreshSeconds) {
                ForEach([2, 5, 10, 30], id: \.self) { s in
                    Text(l10n.seconds(s)).tag(s)
                }
            }
            .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 3) {
                Toggle(l10n.showSystem, isOn: $store.showSystem)
                    .font(.system(size: 12))
                Text(l10n.showSystemHint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle(l10n.launchAtLogin, isOn: $launchAtLogin)
                .font(.system(size: 12))
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        loginError = nil
                    } catch {
                        loginError = l10n.loginError
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            if let loginError {
                Text(loginError)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { isPresented = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                        Text(l10n.back)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowButtonStyle())
                Spacer()
                Text(l10n.settings)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Color.clear.frame(width: 50, height: 1)
            }

            SettingsForm()
                .padding(.horizontal, 4)

            Text(l10n.dataNotice)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
