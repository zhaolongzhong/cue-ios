import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import Dependencies

public struct AuthenticatedView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State var navigationPath: NavigationPath = NavigationPath()

    public init() {}

    public var body: some View {
        AuthenticatedContent(viewModel: dependencies.appStateViewModel, dependencies: dependencies, navigationPath: $navigationPath)
    }
}

private struct AuthenticatedContent: View {
    @ObservedObject var viewModel: AppStateViewModel
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject var router: AppDestinationRouter

    init(viewModel: AppStateViewModel, dependencies: AppDependencies, navigationPath: Binding<NavigationPath>) {
        self.viewModel = viewModel
        self._router = StateObject(wrappedValue: AppDestinationRouter(
            dependencies: dependencies
        ))
        AppLog.log.debug("AuthenticatedContent initialized")
    }

    var body: some View {
        Group {
            if !viewModel.state.isAuthenticated {
                LoginView(loginViewModelFactory: dependencies.viewModelFactory.makeLoginViewModel)
                    .authWindowSize()
            } else {
                #if os(iOS)
                if featureFlags.enableTabView {
                    AppTabView(router: router)
                } else {
                    HomeView()
                }

                #else
                MainWindowView(viewModelFactory: dependencies.viewModelFactory.makeAssistantsViewModel)
                #endif
            }
        }
        .environmentObject(viewModel)
        .environmentObject(dependencies.providersViewModel)
        .onChange(of: viewModel.state.error) { _, error in
            if let error = error {
                coordinator.showError(error)
                viewModel.clearError()
            }

        }
        .sheet(isPresented: $coordinator.showSettings) {
            NavigationStack {
                SettingsView(viewModelFactory: dependencies.viewModelFactory.makeSettingsViewModel, router: router)
                    .id("SettingsViewSheet")
                    .environmentObject(dependencies.providersViewModel)
            }
        }
        .sheet(isPresented: $coordinator.showProviders) {
            NavigationStack {
                ProvidersScreen(providersViewModel: dependencies.providersViewModel)
            }
        }
        .withCoordinatorAlert()
        .onOpenURL { url in
            GIDSignIn.sharedInstance.handle(url)
        }
        .onAppear {
            AppLog.log.debug("AuthenticatedContent onAppear isAuthenticated: \(viewModel.state.isAuthenticated)")
        }
    }
}
