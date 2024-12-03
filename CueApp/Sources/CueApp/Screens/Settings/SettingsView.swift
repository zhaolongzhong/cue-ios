import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    public init() {}

    public var body: some View {
        let viewModel = dependencies.viewModelFactory.makeSettingsViewModel()
        #if os(iOS)
        SettingsView_iOS(viewModel: viewModel)
        #else
        SettingsView_macOS(viewModel: viewModel)
        #endif
    }
}

// MARK: - Common View Sections
private struct AccountSection: View {
    let user: User?

    var body: some View {
        Section("Account") {
            if let user {
                UserInfoView(email: user.email, name: user.name)
            }
        }
    }
}

private struct TokenSection: View {
    let viewModel: SettingsViewModel

    var body: some View {
        Section("Access Token") {
            TokenGenerationView(viewModel: viewModel)
        }
    }
}

private struct LogoutSection: View {
    let onLogout: () -> Void

    var body: some View {
        Section {
            LogoutButtonView(action: onLogout)
        }
    }
}

// MARK: - iOS Implementation
#if os(iOS)
struct SettingsView_iOS: View {
    private let viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            List {
                AccountSection(user: viewModel.currentUser)

                Section("Configuration") {
                    NavigationLink {
                        APIKeysManagementView()
                    } label: {
                        HStack {
                            Text("API Keys")
                            Spacer()
                            Image(systemName: "key.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                TokenSection(viewModel: viewModel)
                LogoutSection {
                    Task {
                        await viewModel.logout()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            #if os(iOS)
            .listStyle(InsetGroupedListStyle())
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
        }
    }
}
#endif

// MARK: - macOS Implementation
#if os(macOS)
struct SettingsView_macOS: View {
    private let viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAPIKeys = false

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                AccountSection(user: viewModel.currentUser)

                Section("Configuration") {
                    apiKeysButton
                }

                TokenSection(viewModel: viewModel)
                LogoutSection {
                    Task {
                        await viewModel.logout()
                        dismiss()
                    }
                }
            }
            .listStyle(.inset)
            .background(Color.clear)
        }
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity, alignment: .center)
        .sheet(isPresented: $isShowingAPIKeys) {
            APIKeysManagementView()
        }
    }

    private var apiKeysButton: some View {
        Button {
            isShowingAPIKeys = true
        } label: {
            HStack {
                Text("API Keys")
                Spacer()
                Image(systemName: "key.fill")
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }
}
#endif
