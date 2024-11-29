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

    init(authService: AuthService) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(authService: authService))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title)
                    .padding()
                Spacer()
            }

            List {
                Section("Account") {
                    if let user = viewModel.currentUser {
                        UserInfoView(email: user.email, name: user.name)
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    LogoutButtonView {
                        Task {
                            await viewModel.logout()
                            dismiss()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.inset)
            .background(Color.clear)
        }
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity, alignment: .center)
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
