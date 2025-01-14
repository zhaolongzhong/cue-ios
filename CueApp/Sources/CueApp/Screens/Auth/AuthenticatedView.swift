import SwiftUI

public struct AuthenticatedView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    public init() {}

    public var body: some View {
        AuthenticatedContent(viewModel: dependencies.appStateViewModel)
    }
}

private struct AuthenticatedContent: View {
    @ObservedObject var viewModel: AppStateViewModel
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator

    init(viewModel: AppStateViewModel) {
        self.viewModel = viewModel
        AppLog.log.debug("AuthenticatedContent initialized")
    }

    var body: some View {
        Group {
            if !viewModel.state.isAuthenticated {
                LoginView(loginViewModelFactory: dependencies.viewModelFactory.makeLoginViewModel)
                    .authWindowSize()
            } else if viewModel.state.isAuthenticated, let user = viewModel.state.currentUser {
                #if os(iOS)
                HomeView(userId: user.id)
                #else
                MainWindowView(userId: user.id, viewModelFactory: dependencies.viewModelFactory.makeAssistantsViewModel)
                    .frame(minWidth: 600, minHeight: 220)
                #endif
            } else {
                #if os(iOS)
                ProgressView()
                    .progressViewStyle(.circular)
                #else
                ProgressView("Loading...")
                #endif
            }
        }
        .environmentObject(viewModel)
        .environmentObject(dependencies.apiKeysProviderViewModel)
        .onChange(of: viewModel.state.error) { _, error in
            if let error = error {
                coordinator.showError(error)
                viewModel.clearError()
            }

        }
        .sheet(isPresented: $coordinator.showSettings) {
            NavigationStack {
                SettingsView(viewModelFactory: dependencies.viewModelFactory.makeSettingsViewModel)
                    .environmentObject(dependencies.apiKeysProviderViewModel)
            }
        }
        .withCoordinatorAlert()
        .onAppear {
            AppLog.log.debug("AuthenticatedContent onAppear isAuthenticated: \(viewModel.state.isAuthenticated)")
        }
    }
}
