import SwiftUI
import Dependencies

public struct SettingsView: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var providersViewModel: ProvidersViewModel
    @StateObject private var viewModel: SettingsViewModel
    @ObservedObject var router: AppDestinationRouter

    public init(viewModelFactory: @escaping () -> SettingsViewModel, router: AppDestinationRouter) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        self.router = router
    }

    public var body: some View {
        Group {
            #if os(iOS)
            SettingsListIOS(
                viewModel: viewModel,
                dismiss: dismiss
            )
            .navigationBarTitleDisplayMode(.inline)
            .defaultNavigationBar(title: "Settings")
            .toolbar {
                if !featureFlags.enableTabView {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        DismissButton(action: { dismiss() })
                    }
                }
            }
            #else
            NavigationStack(path: $router.navigationPath) {
                SettingsListMacOS(
                    viewModel: viewModel,
                    router: router,
                    dismiss: dismiss
                )
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 4) {
                            Text("Settings")
                                .font(.headline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .withAppDestinations(router: router)
            }
            #endif
        }
        .onAppear {
            viewModel.refreshUserProfile()
        }
        .onChange(of: viewModel.error) { _, error in
            if let error = error {
                coordinator.showError(error)
                viewModel.clearError()
            }
        }
    }
}
