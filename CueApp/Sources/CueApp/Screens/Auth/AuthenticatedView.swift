import SwiftUI

public struct AuthenticatedView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    public init() {}

    public var body: some View {
        AuthenticatedContent(viewModel: dependencies.appState)
    }
}

private struct AuthenticatedContent: View {
    @ObservedObject var viewModel: AppStateViewModel
    @EnvironmentObject private var dependencies: AppDependencies

    init(viewModel: AppStateViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                #if os(iOS)
                ProgressView()
                    .progressViewStyle(.circular)  // Specify style for iOS
                #else
                ProgressView("Loading...")
                #endif
            } else if viewModel.isAuthenticated {
                #if os(iOS)
                AppTabView()
                    .environmentObject(dependencies)
                    .environmentObject(viewModel)
                #else
                MainWindowView()
                    .environmentObject(dependencies)
                    .environmentObject(viewModel)
                    .environmentObject(dependencies.viewModelFactory.makeAssistantsViewModel())
                #endif
            } else {
                LoginView()
                    .environmentObject(dependencies)
            }
        }
        .onAppear {
            viewModel.checkAuthStatus()
        }
    }
}
