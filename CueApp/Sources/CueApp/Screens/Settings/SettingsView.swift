import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
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
        }
        #else
        VStack(spacing: 0) {
            SettingsList(
                viewModel: viewModel,
                isShowingAPIKeys: $isShowingAPIKeys,
                dismiss: dismiss
            )
            .background(Color.clear)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        #endif
    }
}

private struct SettingsList: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var isShowingAPIKeys: Bool
    let dismiss: DismissAction

    var body: some View {
        #if os(iOS)
        List {
            Section {
                if let user = viewModel.currentUser {
                    UserInfoView(email: user.email, name: user.name)
                }
            } header: {
                Text("Account")
                    .textCase(nil)
                    .foregroundColor(.primary)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            .listSectionSpacing(.compact)

            Section {
                APIKeysButton()
            } header: {
                Text("Configuration")
                    .textCase(nil)
                    .foregroundColor(.primary)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            .listSectionSpacing(.compact)

            Section {
                TokenGenerationView(viewModel: viewModel)
                    .listRowSeparator(.hidden)
            }  header: {
                Text("Access Token")
                    .textCase(nil)
                    .foregroundColor(.primary)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            .listSectionSpacing(.compact)
            VersionSection()
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                .listSectionSpacing(.compact)
            LogoutSection {
                Task {
                    await viewModel.logout()
                    dismiss()
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
        }
        .listStyle(.insetGrouped)
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Section {
                    SectionBackgroundView {
                        if let user = viewModel.currentUser {
                            UserInfoView(email: user.email, name: user.name)
                        }
                    }
                } header: {
                    Text("Account")
                        .textCase(nil)
                        .foregroundColor(.primary)
                        .padding(.leading, 8)
                }

                Section("Configuration") {
                    SectionBackgroundView {
                        APIKeysButton(isShowingAPIKeys: $isShowingAPIKeys)
                    }
                }

                Section("Access Token") {
                    SectionBackgroundView {
                        TokenGenerationView(viewModel: viewModel)
                            .listRowSeparator(.hidden)
                    }
                }

                Section {
                    SectionBackgroundView {
                        VersionSection()
                    }
                }

                Section {
                    SectionBackgroundView {
                        LogoutSection {
                            Task {
                                await viewModel.logout()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $isShowingAPIKeys) {
            APIKeysManagementView()
        }
        #endif
    }
}

private struct SectionBackgroundView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.Colors.lightGray.opacity(0.8))
            )
    }
}

private struct UserInfoView: View {
    let email: String
    let name: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsRow(
                systemName: "envelope.fill",
                title: "Email",
                value: email,
                showChevron: false
            )
            if let name = name {
                SettingsRow(
                    systemName: "person.fill",
                    title: "Name",
                    value: name,
                    showChevron: false
                )
            }
        }
    }
}

private struct APIKeysButton: View {
    #if os(iOS)
    var body: some View {
        NavigationLink {
            APIKeysManagementView()
        } label: {
            SettingsRow(
                systemName: "key.fill",
                title: "API Keys",
                showChevron: false
            )
        }
        .buttonStyle(.plain)
    }
    #else
    @Binding var isShowingAPIKeys: Bool

    init(isShowingAPIKeys: Binding<Bool>) {
        _isShowingAPIKeys = isShowingAPIKeys
    }

    var body: some View {
        Button {
            isShowingAPIKeys = true
        } label: {
            SettingsRow(
                systemName: "key.fill",
                title: "API Keys",
                showChevron: true
            )
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }
    #endif
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

private struct VersionSection: View {
    private var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildVersion: String {
        Bundle.main.infoDictionary?["BUILD_VERSION"] as? String ?? "1"
    }

    var body: some View {
        Section {
            Button(action: {}) {
                SettingsRow(
                    systemName: "info.circle",
                    title: "Version",
                    value: "\(marketingVersion) (\(buildVersion))",
                    showChevron: false
                )
            }
            .buttonStyle(.plain)
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
