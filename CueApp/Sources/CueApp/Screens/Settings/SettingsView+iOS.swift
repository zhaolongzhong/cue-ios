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
            .padding(.trailing, 0)
            .listSectionSpacing(.compact)

            if featureFlags.enableAssistants || featureFlags.enableThirdPartyProvider {
                Section {
                    if featureFlags.enableThirdPartyProvider {
                        APIKeysButton(title: "Third Party Providers", horizontal: true, onTap: {
                            navigationPath.append(SettingsRoute.providerAPIKeys)
                        })
                    }
                    if featureFlags.enableAssistants {
                        APIKeysButton(title: "Assistant API Keys", horizontal: false, onTap: {
                            navigationPath.append(SettingsRoute.assistantAPIKeys)
                        })
                    }
                } header: {
                    SettingsHeader(title: "API Keys")
                }
                .listSectionSpacing(.compact)
            }

            Section {
                NavigationLink {
                    ConnectedAppsView()
                } label: {
                    SettingsRow(
                        systemName: "shield.checkerboard",
                        title: "Google Apps",
                        value: "",
                        showChevron: false
                    )
                }
            } header: {
                SettingsHeader(title: "Connected Apps")
            }

            Section {
                SettingsRow(
                    systemName: "sun.max",
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
                    systemName: "iphone.radiowaves.left.and.right",
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
                SettingsHeader(title: "Appearance")
            }
            .listSectionSpacing(.compact)
            Section {
                NavigationLink {
                    FeatureFlagsView()
                } label: {
                    SettingsRow(
                        systemName: "flag",
                        title: "Feature Flags",
                        value: ""
                    )
                }
            } header: {
                SettingsHeader(title: "Development")
            }
            Section {
                SettingsRow(
                    systemName: "info.circle",
                    title: "Version",
                    value: "\(viewModel.getVersionInfo())",
                    showChevron: false
                )
            } header: {
                SettingsHeader(title: "About")
            }
            .listSectionSpacing(.compact)
            LogoutSection {
                Task {
                    await viewModel.logout()
                    dismiss()
                }
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
