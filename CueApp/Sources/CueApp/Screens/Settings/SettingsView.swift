import SwiftUI
import Dependencies

enum SettingsRoute: Hashable {
    case providers
    case assistantAPIKeys
    case connectedApps
    #if os(macOS)
    case developer
    #endif
    case featureFlags
}

public struct SettingsView: View {
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel: SettingsViewModel

    public init(viewModelFactory: @escaping () -> SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
    }

    public var body: some View {
        SettingsContentView(viewModel: viewModel)
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

private struct SettingsContentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var providersViewModel: ProvidersViewModel
    @ObservedObject var viewModel: SettingsViewModel
    @State private var navigationPath = NavigationPath()

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                #if os(iOS)
                SettingsListIOS(
                    viewModel: viewModel,
                    navigationPath: $navigationPath,
                    dismiss: dismiss
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        DismissButton(action: { dismiss() })
                    }
                }
                #else
                SettingsListMacOS(
                    viewModel: viewModel,
                    navigationPath: $navigationPath,
                    dismiss: dismiss
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #endif
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 4) {
                        Text("Settings")
                            .font(.headline)
                    }
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .providers:
                    ProvidersScreen(providersViewModel: providersViewModel)
                case .assistantAPIKeys:
                    APIKeysView()
                case .connectedApps:
                    ConnectedAppsView()
                #if os(macOS)
                case .developer:
                    DeveloperView()
                #endif
                case .featureFlags:
                    FeatureFlagsView()
                }
            }
        }
    }
}
