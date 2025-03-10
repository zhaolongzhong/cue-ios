//
//  AppDestinationRouter.swift
//  CueApp
//

import SwiftUI

enum AppDestination: Hashable {
    case email
    case chat(Assistant)
    case details(Assistant)
    case providers
    case assistantAPIKeys
    case connectedApps
    case developer
    case featureFlags
    case settings
}

@MainActor
public final class AppDestinationRouter: ObservableObject {
    private let dependencies: AppDependencies
    @Published var navigationPath = NavigationPath()

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func navigate(to destination: AppDestination) {
        navigationPath.append(destination)
    }

    @ViewBuilder
    func destinationView(for destination: AppDestination) -> some View {
        switch destination {
        case .email:
            #if os(iOS)
            EmailScreen(emailScreenViewModel: dependencies.viewModelFactory.makeEmailScreenViewModel())
                .defaultNavigationBar()
                .toolbar(.hidden, for: .tabBar)
            #endif
        case .chat(let assistant):
            AssistantChatView(
                assistantChatViewModel: dependencies.viewModelFactory.makeAssistantChatViewModel(assistant: assistant),
                assistantsViewModel: dependencies.viewModelFactory.makeAssistantsViewModel()
            )
            .id(assistant.id)
            .defaultNavigationBar()
        case .details(let assistant):
            AssistantDetailView(
                assistant: assistant,
                assistantsViewModel: dependencies.viewModelFactory.makeAssistantsViewModel(),
                onUpdate: nil
            )
            .defaultNavigationBar()
        case .providers:
            ProvidersScreen(providersViewModel: dependencies.providersViewModel)
        case .assistantAPIKeys:
            APIKeysView()
        case .connectedApps:
            ConnectedAppsView()
        case .developer:
            MCPServersView(viewModelFactory: dependencies.viewModelFactory.makeMCPServersViewModel)
        case .featureFlags:
            FeatureFlagsView()
        case .settings:
            SettingsView(
                viewModelFactory: dependencies.viewModelFactory.makeSettingsViewModel,
                router: self
            )
        }
    }
}

struct AppDestinationNavigationModifier: ViewModifier {
    @ObservedObject var router: AppDestinationRouter

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: AppDestination.self) { destination in
                router.destinationView(for: destination)
            }
    }
}

extension View {
    func withAppDestinations(router: AppDestinationRouter) -> some View {
        self.modifier(AppDestinationNavigationModifier(router: router))
    }
}
