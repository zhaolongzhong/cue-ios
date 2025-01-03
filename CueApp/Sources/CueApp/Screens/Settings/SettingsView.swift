import SwiftUI

private enum SettingsRoute: Hashable {
    case providerAPIKeys
    case apiKeys
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
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var apiKeysProviderViewModel: APIKeysProviderViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var isShowingProviderAPIKeys = false
    @State private var isShowingAPIKeys = false
    @State private var navigationPath = NavigationPath()

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SettingsList(
                viewModel: viewModel,
                showProviderAPIKeys: {
                    navigationPath.append(SettingsRoute.providerAPIKeys)
                },
                showAPIKeys: {
                    navigationPath.append(SettingsRoute.apiKeys)
                },
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
                case .apiKeys:
                    APIKeysView()
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
    @ObservedObject var viewModel: SettingsViewModel
    @AppStorage("colorScheme") private var colorScheme: ColorSchemeOption = .system
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled: Bool = true
    let showProviderAPIKeys: () -> Void
    let showAPIKeys: () -> Void
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
                APIKeysButton(title: "Provider API Keys", horizontal: true, onTap: showProviderAPIKeys)
                APIKeysButton(title: "Assistant API Keys", horizontal: false, onTap: showAPIKeys)
            } header: {
                SettingsHeader(title: "API Keys")
            }
            .listSectionSpacing(.compact)

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
        .background(AppTheme.Colors.secondaryBackground)
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
                        APIKeysButton(title: "Provider API Keys", horizontal: true, onTap: showProviderAPIKeys)
                            .padding(.horizontal, 6)
                        Divider()
                        APIKeysButton(title: "Assistant API Keys", horizontal: false, onTap: showAPIKeys)
                            .padding(.horizontal, 6)
                    }
                } header: {
                    SettingsHeader(title: "API Keys")
                }

                Section {
                    GroupBox {
                        SettingsRow(
                            systemName: "info.circle",
                            title: "Version",
                            value: "\(viewModel.getVersionInfo())",
                            showChevron: false
                        ).padding(.horizontal, 6)
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
            "Log Out",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) {
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
