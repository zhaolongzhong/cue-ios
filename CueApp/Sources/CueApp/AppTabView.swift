import SwiftUI
import Dependencies

enum TabSelection: String {
    case home = "Chat"
    case assistants = "Assistants"
    case settings = "Settings"
}

public struct AppTabView: View {
    @Dependency(\.webSocketService) public var webSocketService
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var providersViewModel: ProvidersViewModel
    @State private var selectedTab: TabSelection = .assistants
    @ObservedObject var router: AppDestinationRouter

    public init(router: AppDestinationRouter) {
        self.router = router
    }

    public var body: some View {
        NavigationStack(path: $router.navigationPath) {
            TabView(selection: $selectedTab) {
                if featureFlags.enableEmail {
                    HomeDefaultView(viewModel: dependencies.viewModelFactory.makeHomeViewModel(), onNewSession: {
                        router.navigate(to: AppDestination.email)
                    })
                    .tabItem {
                        Label("Home", systemImage: "wand.and.stars")
                    }
                    .tag(TabSelection.home)
                }

                AssistantsView(
                    viewModelFactory: dependencies.viewModelFactory.makeAssistantsViewModel,
                    navigationPath: $router.navigationPath
                )
                .tabItem {
                    Label("Assistants", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(TabSelection.assistants)
                .id("AssistantsView")
            }
            .toolbar {
                if selectedTab == .assistants {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            router.navigate(to: AppDestination.settings)
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.primary.opacity(0.9))
                        }
                    }
                }
            }
            .navigationTitle(selectedTab.rawValue)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color(uiColor: .systemGray))
            .withAppDestinations(router: router)
            #endif
        }

        .onChange(of: selectedTab) { _, _ in
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
        }
        .onAppear {
            AppLog.log.debug("AppTabView onAppear isAuthenticated:\(appStateViewModel.state.isAuthenticated)")
            self.initialize(userId: appStateViewModel.state.currentUser?.id)
        }
        .onChange(of: appStateViewModel.state.currentUser) { _, _ in
            self.initialize(userId: appStateViewModel.state.currentUser?.id)
        }
    }

    private func initialize(userId: String?) {
        guard userId != nil else {
            return
        }
        Task {
            await webSocketService.connect()
        }
    }
}
