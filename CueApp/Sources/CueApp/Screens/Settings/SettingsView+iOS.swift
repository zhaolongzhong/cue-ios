import Foundation
import SwiftUI
import Dependencies

enum ColorSchemeOption: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

struct SettingsListIOS: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @ObservedObject var viewModel: SettingsViewModel
    @AppStorage("colorScheme") private var colorScheme: ColorSchemeOption = .system
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled: Bool = true
    @Binding var navigationPath: NavigationPath
    @State private var showingLogoutConfirmation = false
    let dismiss: DismissAction

    var body: some View {
        #if os(iOS)
        List {
            Section {
                if let user = viewModel.currentUser {
                    UserInfoView(email: user.email)
                }
            } header: {
                SettingsHeader(title: "Account")
            }
            .listSectionSpacing(.compact)
            Section {
                if featureFlags.enableProviders {
                    SettingsRow(systemIcon: "key.viewfinder", title: "Providers", showChevron: true) {
                        navigationPath.append(SettingsRoute.providers)
                    }
                }
                if featureFlags.enableAssistants {
                    SettingsRow(systemIcon: "key", title: "API Keys", showChevron: true) {
                        navigationPath.append(SettingsRoute.assistantAPIKeys)
                    }
                }
                SettingsRow(
                    systemIcon: "app.connected.to.app.below.fill",
                    title: "Connected Apps",
                    showChevron: true
                ) {
                    navigationPath.append(SettingsRoute.connectedApps)
                }
            } header: {
                SettingsHeader(title: "Services")
            }
            Section {
                SettingsRow(
                    systemIcon: "flag",
                    title: "Feature Flags",
                    value: "",
                    showChevron: true
                ) {
                    navigationPath.append(SettingsRoute.featureFlags)
                }
            } header: {
                SettingsHeader(title: "Developer")
            }
            Section {
                SettingsRow(
                    systemIcon: "sun.max",
                    title: "Color Scheme",
                    value: "",
                    showChevron: false,
                    trailing: AnyView(
                        Picker("", selection: $colorScheme) {
                            ForEach(ColorSchemeOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .font(.system(size: 12))
                        .padding(.vertical, 0)
                        .frame(height: 30)
                        .tint(Color.secondary)
                    )
                )
                SettingsRow(
                    systemIcon: "iphone.radiowaves.left.and.right",
                    title: "Haptic Feedback",
                    value: "",
                    showChevron: false,
                    trailing: AnyView(
                        Toggle("", isOn: $hapticFeedbackEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(.secondary)

                    )
                )
            } header: {
                SettingsHeader(title: "App")
            }
            .listSectionSpacing(.compact)
            Section {
                SettingsRow(
                    systemIcon: "info.circle",
                    title: "Version",
                    value: "\(viewModel.getVersionInfo())",
                    showChevron: false
                )
            } header: {
                SettingsHeader(title: "About")
            }
            .listSectionSpacing(.compact)
            Section {
                SettingsRow(
                    systemIcon: "rectangle.portrait.and.arrow.right",
                    title: "Log out",
                    showChevron: false
                ) {
                    showingLogoutConfirmation = true
                }
                .logoutConfirmation(
                    isPresented: $showingLogoutConfirmation,
                    onConfirm: {
                        Task {
                            await viewModel.logout()
                            dismiss()
                        }
                    }
                )
            } header: {
                SettingsHeader(title: "Developer")
            }
        }
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.secondaryBackground.opacity(0.2))
        .onChange(of: colorScheme) { _, newValue in
            (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.overrideUserInterfaceStyle = {
                switch newValue {
                case .system: return .unspecified
                case .light: return .light
                case .dark: return .dark
                }
            }()
        }
        #endif
    }
}
