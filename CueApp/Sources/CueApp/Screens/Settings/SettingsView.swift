import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @StateObject private var viewModel: SettingsViewModel

    public init(viewModelFactory: @escaping () -> SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        AppLog.log.debug("SettingsView init()")
    }

    public var body: some View {
        #if os(iOS)
        SettingsView_iOS(viewModel: viewModel).onAppear {
            AppLog.log.debug("SettingsView onAppear")
        }
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

private struct VersionSection: View {
    private var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildVersion: String {
        Bundle.main.infoDictionary?["BUILD_VERSION"] as? String ?? "1"
    }

    var body: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(marketingVersion)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Build")
                Spacer()
                Text(buildVersion)
                    .foregroundColor(.secondary)
            }
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

                VersionSection()
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

                VersionSection()
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
