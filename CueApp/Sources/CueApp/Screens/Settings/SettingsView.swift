import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel: SettingsViewModel

    public init(viewModelFactory: @escaping () -> SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
    }

    public var body: some View {
        SettingsContentView(viewModel: viewModel)
    }
}

private struct SettingsContentView: View {
    private let viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAPIKeys = false

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        #if os(iOS)
        NavigationView {
            SettingsList(
                viewModel: viewModel,
                isShowingAPIKeys: $isShowingAPIKeys,
                dismiss: dismiss
            )
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $isShowingAPIKeys) {
                APIKeysManagementView()
            }
        }
        #else
        SettingsList(
            viewModel: viewModel,
            isShowingAPIKeys: $isShowingAPIKeys,
            dismiss: dismiss
        )
        .background(Color.clear)
        .frame(maxWidth: .infinity, alignment: .center)
        .sheet(isPresented: $isShowingAPIKeys) {
            APIKeysManagementView()
        }
        #endif
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
    @Binding var isShowingAPIKeys: Bool
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
                APIKeysButton(isShowingAPIKeys: $isShowingAPIKeys)
                    .padding(.horizontal, 0)
            } header: {
                SettingsHeader(title: "Configuration")
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
                    )
                )
            } header: {
                SettingsHeader(title: "Appearance")
            }
            .listSectionSpacing(.compact)

            Section {
                TokenGenerationView(viewModel: viewModel)
                    .listRowSeparator(.hidden)
            }  header: {
                SettingsHeader(title: "Access Token")
            }
            .listSectionSpacing(.compact)
            Section {
                Button(action: {}) {
                    SettingsRow(
                        systemName: "info.circle",
                        title: "Version",
                        value: "\(viewModel.marketingVersion) (\(viewModel.buildVersion))",
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
        .background(Color.cyan)
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
            VStack(alignment: .leading, spacing: 12) {
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
                        APIKeysButton(isShowingAPIKeys: $isShowingAPIKeys)
                            .padding(.horizontal, 6)
                    }
                } header: {
                    SettingsHeader(title: "Configuration")
                }

                Section {
                    GroupBox {
                        TokenGenerationView(viewModel: viewModel)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 6)
                    }
                } header: {
                    SettingsHeader(title: "Access Token")
                }

                Section {
                    GroupBox {
                        SettingsRow(
                            systemName: "info.circle",
                            title: "Version",
                            value: "\(viewModel.marketingVersion) (\(viewModel.buildVersion))",
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
            .padding(.horizontal, 32)
            .padding(.vertical, 32)
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

    @Binding var isShowingAPIKeys: Bool

    init(isShowingAPIKeys: Binding<Bool>) {
        _isShowingAPIKeys = isShowingAPIKeys
    }

    var body: some View {
        Button {
            Task { @MainActor in
                #if os(iOS)
                HapticManager.shared.impact(style: .light)
                #endif
                isShowingAPIKeys = true
            }
        } label: {
            SettingsRow(
                systemName: "key",
                title: "API Keys",
                showChevron: true
            )
        }
        .padding(.horizontal, 0)
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
