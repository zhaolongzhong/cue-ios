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
            if viewModel.state.isLoading {
                #if os(iOS)
                ProgressView()
                    .progressViewStyle(.circular)
                #else
                ProgressView("Loading...")
                #endif
            } else if viewModel.state.isAuthenticated {
                #if os(iOS)
                AppTabView(apiKeysViewModelFactory: dependencies.viewModelFactory.makeAPIKeysViewModel)
                    .environmentObject(viewModel)
                #else
                MainWindowView(viewModelFactory: dependencies.viewModelFactory.makeAssistantsViewModel)
                    .environmentObject(viewModel)
                #endif
            } else {
                LoginView(loginViewModelFactory: dependencies.viewModelFactory.makeLoginViewModel)
            }
        }
        .onChange(of: viewModel.state.error) { _, error in
            if let error = error {
                coordinator.showError(error)
                viewModel.clearError()
            }

        }
        .sheet(isPresented: $coordinator.showSettings) {
            SettingsView(viewModelFactory: dependencies.viewModelFactory.makeSettingsViewModel)
        }
        .alert(item: $coordinator.activeAlert) { alertType in
            switch alertType {
            case .error(let message):
                return Alert(
                    title: Text("Error"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )

            case .confirmation(let title, let message):
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    primaryButton: .default(Text("OK")),
                    secondaryButton: .cancel()
                )

            case .custom(let title, let message, let action):
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    primaryButton: .default(Text("OK"), action: action),
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            AppLog.log.debug("AuthenticatedContent onAppear isAuthenticated: \(viewModel.state.isAuthenticated)")
        }
    }
}
