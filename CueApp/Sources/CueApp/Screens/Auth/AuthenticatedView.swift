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
                AppTabView()
                    .environmentObject(viewModel)
                #else
                MainWindowView(viewModelFactory: dependencies.viewModelFactory.makeAssistantsViewModel)
                    .environmentObject(viewModel)
                #endif
            } else {
                LoginView()
            }
        }
        .onAppear {
            AppLog.log.debug("AuthenticatedContent onAppear isAuthenticated: \(viewModel.state.isAuthenticated)")
        }
    }
}
