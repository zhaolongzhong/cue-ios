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
            LazyVStack(alignment: .leading, spacing: 12) {
                Section {
                    GroupBox {
                        if let user = viewModel.currentUser {
                            UserInfoView(email: user.email)
                                .padding(.horizontal, 6)
                        }
                    }
                } header: {
                    SettingsHeader(title: "Account")
                }

                if featureFlags.enableAssistants || featureFlags.enableThirdPartyProvider {
                    Section {
                        GroupBox {
                            if featureFlags.enableOpenAIChat || featureFlags.enableAnthropicChat {
                                APIKeysButton(title: "Provider API Keys", horizontal: true, onTap: {
                                    navigationPath.append(SettingsRoute.providerAPIKeys)
                                })
                                .padding(.horizontal, 6)
                                if featureFlags.enableAssistants {
                                    Divider()
                                }
                            }
                            if featureFlags.enableAssistants {
                                APIKeysButton(title: "Assistant API Keys", horizontal: false, onTap: {
                                    navigationPath.append(SettingsRoute.assistantAPIKeys)
                                })
                                .padding(.horizontal, 6)
                            }
                        }
                    } header: {
                        SettingsHeader(title: "API Keys")
                    }
                }

                Section {
                    GroupBox {
                        Button {
                            navigationPath.append(SettingsRoute.connectedApps)
                        } label: {
                            SettingsRow(
                                systemName: "shield.checkerboard",
                                title: "Google Apps",
                                showChevron: true
                            ).padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    SettingsHeader(title: "Connected Apps")
                }

                Section {
                    GroupBox {
                        Button {
                            navigationPath.append(SettingsRoute.developer)
                        } label: {
                            SettingsRow(
                                systemName: "hammer",
                                title: "Developer",
                                showChevron: true
                            ).padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    GroupBox {
                        Button {
                            navigationPath.append(SettingsRoute.featureFlags)
                        } label: {
                            SettingsRow(
                                systemName: "flag",
                                title: "Feature Flags",
                                showChevron: true
                            ).padding(.horizontal, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    GroupBox {
                        if let appcastUrl = viewModel.appConfig?.appcastUrl {
                            Button {
                                coordinator.checkForUpdates(withAppcastUrl: appcastUrl)
                            } label: {
                                SettingsRow(
                                    systemName: "arrow.triangle.2.circlepath",
                                    title: "Check for Updates",
                                    showChevron: false
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 6)
                            Divider()
                        }

                        SettingsRow(
                            systemName: "info.circle",
                            title: "Version",
                            value: "\(viewModel.getVersionInfo())",
                            showChevron: false
                        )
                        .padding(.horizontal, 6)
                    }
                }

                Section {
                    GroupBox {
                        LogoutSection {
                            Task {
                                await viewModel.logout()
                                dismiss()
                            }
                        }.padding(.horizontal, 6)
                    }
                }
            }
            .padding(.all, 32)
        }
        #endif
    }
}
