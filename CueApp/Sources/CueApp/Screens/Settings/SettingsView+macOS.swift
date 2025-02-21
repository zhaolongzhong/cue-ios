import Foundation
import SwiftUI
import Dependencies

struct SettingsListMacOS: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @ObservedObject var viewModel: SettingsViewModel
    @AppStorage("colorScheme") private var colorScheme: ColorSchemeOption = .system
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled: Bool = true
    @Binding var navigationPath: NavigationPath
    let dismiss: DismissAction

    var body: some View {
        #if os(macOS)
        ScrollView {
            HStack {
                Spacer()
                contentView
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        #endif
    }

    var contentView: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            Section {
                GroupBox {
                    if let user = viewModel.currentUser {
                        UserInfoView(email: user.email)
                    }
                }
            } header: {
                SettingsHeader(title: "Account")
            }

            Section {
                GroupBox {
                    if featureFlags.enableProviders {
                        SettingsRow(systemIcon: "key.viewfinder", title: "Providers", showChevron: true, showDivider: true) {
                            navigationPath.append(SettingsRoute.providers)
                        }
                    }
                    if featureFlags.enableAssistants {
                        SettingsRow(systemIcon: "key", title: "API Keys", showChevron: true, showDivider: true) {
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
                }
            } header: {
                SettingsHeader(title: "Services")
            }

            Section {
                GroupBox {
                    SettingsRow(
                        systemIcon: "flag",
                        title: "Feature Flags",
                        value: "",
                        showChevron: true,
                        showDivider: true
                    ) {
                        navigationPath.append(SettingsRoute.featureFlags)
                    }
                    SettingsRow(
                        systemIcon: "hammer",
                        title: "Integrations",
                        value: "",
                        showChevron: true
                    ) {
                        navigationPath.append(SettingsRoute.developer)
                    }
                }
            } header: {
                SettingsHeader(title: "Developer")
            }

            Section {
                GroupBox {
                    if let appcastUrl = viewModel.appConfig?.appcastUrl {
                        SettingsRow(
                            systemIcon: "arrow.triangle.2.circlepath",
                            title: "Check for Updates",
                            showDivider: true
                        ) {
                            coordinator.checkForUpdates(withAppcastUrl: appcastUrl)
                        }
                    }

                    SettingsRow(
                        systemIcon: "info.circle",
                        title: "Version",
                        value: "\(viewModel.getVersionInfo())"
                    )
                }
            }

            Section {
                GroupBox {
                    LogoutSection {
                        Task {
                            await viewModel.logout()
                            dismiss()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 600)
    }
}
