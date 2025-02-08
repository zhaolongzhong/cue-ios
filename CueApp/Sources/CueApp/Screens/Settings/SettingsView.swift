import SwiftUI

private enum SettingsRoute: Hashable {
    case providerAPIKeys
    case assistantAPIKeys
    case connectedApps
    #if os(macOS)
    case developer
    #endif
}

public struct SettingsView: View {
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel: SettingsViewModel

    public init(viewModelFactory: @escaping () -> SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
    }

    public var body: some View {
        SettingsContentView(viewModel: viewModel)
            .onChange(of: viewModel.error) { _, error in
                if let error = error {
                    coordinator.showError(error)
                    viewModel.clearError()
                }
            }
    }
}

private struct SettingsContentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var apiKeysProviderViewModel: APIKeysProviderViewModel
    @ObservedObject var viewModel: SettingsViewModel
    @State private var navigationPath = NavigationPath()

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SettingsList(
                viewModel: viewModel,
                navigationPath: $navigationPath,
                dismiss: dismiss
            )
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    DismissButton(action: { dismiss() })
                }
            }
            #else
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .providerAPIKeys:
                    APIKeysProviderView(apiKeysProviderViewModel: apiKeysProviderViewModel)
                case .assistantAPIKeys:
                    APIKeysView()
                case .connectedApps:
                    ConnectedAppsView()
                #if os(macOS)
                case .developer:
                    DeveloperView()
                #endif
                }
            }
        }
    }
}

enum ColorSchemeOption: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

private struct SettingsList: View {
    @EnvironmentObject private var coordinator: AppCoordinator
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

            Section {
                APIKeysButton(title: "Provider API Keys", horizontal: true, onTap: {
                    navigationPath.append(SettingsRoute.providerAPIKeys)
                })
                APIKeysButton(title: "Assistant API Keys", horizontal: false, onTap: {
                    navigationPath.append(SettingsRoute.assistantAPIKeys)
                })
            } header: {
                SettingsHeader(title: "API Keys")
            }
            .listSectionSpacing(.compact)

            Section {
                NavigationLink {
                    ConnectedAppsView()
                } label: {
                    SettingsRow(
                        systemName: "shield.checkerboard",
                        title: "Google Apps",
                        value: "",
                        showChevron: true
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
                #if os(iOS)
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
                #endif
            } header: {
                SettingsHeader(title: "Appearance")
            }
            .listSectionSpacing(.compact)
            Section {
                Button(action: {}) {
                    SettingsRow(
                        systemName: "info.circle",
                        title: "Version",
                        value: "\(viewModel.getVersionInfo())",
                        showChevron: false
                    )
                }
                .buttonStyle(.plain)
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
        #else
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

                Section {
                    GroupBox {
                        APIKeysButton(title: "Provider API Keys", horizontal: true, onTap: {
                            navigationPath.append(SettingsRoute.providerAPIKeys)
                        })
                            .padding(.horizontal, 6)
                        Divider()
                        APIKeysButton(title: "Assistant API Keys", horizontal: false, onTap: {
                            navigationPath.append(SettingsRoute.assistantAPIKeys)
                        })
                            .padding(.horizontal, 6)
                    }
                } header: {
                    SettingsHeader(title: "API Keys")
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

private struct SettingsHeader: View {
    let title: String
    var body: some View {
        Text(title)
            #if os(macOS)
            .font(.headline)
            .padding(.leading, 8)
            #else
            .font(.footnote.bold())
            .padding(.leading, -8)
            #endif
    }
}

private struct UserInfoView: View {
    let email: String

    var body: some View {
            SettingsRow(
                systemName: "envelope",
                title: "Email",
                value: email,
                showChevron: false
            )
    }
}

private struct APIKeysButton: View {
    let title: String
    let horizontal: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
            onTap()
        } label: {
            SettingsRow(
                systemName: horizontal ? "key.horizontal" : "key",
                title: title,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LogoutSection: View {
    let onLogout: () -> Void
    @State private var showingLogoutConfirmation = false

    var body: some View {
        Section {
            Button {
                showingLogoutConfirmation = true
            } label: {
                SettingsRow(
                    systemName: "rectangle.portrait.and.arrow.right",
                    title: "Log out",
                    showChevron: false
                )
            }
            .buttonStyle(.plain)
            .logoutConfirmation(
                isPresented: $showingLogoutConfirmation,
                onConfirm: onLogout
            )
        }
    }
}

extension View {
    func logoutConfirmation(
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) -> some View {
        confirmationDialog(
            "Log out",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button("Log out", role: .destructive) {
                onConfirm()
            }
            Button("Cancel", role: .cancel) {
                isPresented.wrappedValue = false
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
}
