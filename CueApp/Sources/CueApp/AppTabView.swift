import SwiftUI

enum TabSelection: String {
    case assistants = "Assistants"
    case settings = "Settings"
}

public struct AppTabView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @State private var selectedTab: TabSelection = .assistants

    public init() { }

    public var body: some View {
        TabView(selection: $selectedTab) {
            AssistantsView(viewModelFactory: dependencies.viewModelFactory.makeAssistantsViewModel)
                .tabItem {
                    Label("Assistants", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(TabSelection.assistants)

            SettingsView(viewModelFactory: dependencies.viewModelFactory.makeSettingsViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(TabSelection.settings)
        }
        .navigationTitle(selectedTab.rawValue)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accentColor(Color(.darkGray))
        .onAppear {
            AppLog.log.debug("AppTabView onAppear isAuthenticated:\(appStateViewModel.state.isAuthenticated)")
            self.initialize(userId: appStateViewModel.state.currentUser?.id)
        }
        .onChange(of: appStateViewModel.state.currentUser) { _, _ in
            AppLog.log.debug("AppTabView onChange")
            self.initialize(userId: appStateViewModel.state.currentUser?.id)
        }
    }

    private func initialize(userId: String?) {
        guard let userId = userId else {
            return
        }
        dependencies.webSocketStore.initialize(for: userId)
    }
}
