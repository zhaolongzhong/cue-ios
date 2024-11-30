import SwiftUI

#if os(iOS)
@MainActor
struct SettingsView_iOS: View {
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(authService: AuthService) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(authService: authService))
    }

    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    if let user = viewModel.currentUser {
                        UserInfoView(email: user.email, name: user.name)
                    }
                }

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

                Section("Access Token") {
                    TokenGenerationView(viewModel: viewModel)
                }

                Section {
                    LogoutButtonView {
                        Task {
                            await viewModel.logout()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
#endif

#if os(macOS)
@MainActor
struct SettingsView_macOS: View {
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAPIKeys = false

    init(authService: AuthService) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(authService: authService))
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Account") {
                    if let user = viewModel.currentUser {
                        UserInfoView(email: user.email, name: user.name)
                    }
                }

                Section("Configuration") {
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

                Section("Access Token") {
                    TokenGenerationView(viewModel: viewModel)
                }

                Section {
                    LogoutButtonView {
                        Task {
                            await viewModel.logout()
                            dismiss()
                        }
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
}
#endif

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        #if os(iOS)
        SettingsView_iOS(authService: authService)
        #else
        SettingsView_macOS(authService: authService)
        #endif
    }
}
