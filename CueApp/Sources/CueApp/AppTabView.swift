import SwiftUI

enum TabSelection: String {
    case chat = "Chat"
    case assistants = "Assistants"
    case settings = "Settings"
}

public struct AppTabView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @State private var selectedTab: TabSelection = .chat

    public init() { }

    public var body: some View {
        let viewModel = dependencies.viewModelFactory.makeAssistantsViewModel()
        TabView(selection: $selectedTab) {
            PrimaryChatView(webSocketManagerStore: self.dependencies.webSocketStore, assistantsViewModel: viewModel)
                .tabItem {
                    Label("Chat", systemImage: "wand.and.stars")
                }
                .tag(TabSelection.chat)
            AssistantsView(viewModel: viewModel)
                .tabItem {
                    Label("Assistants", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(TabSelection.assistants)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(TabSelection.settings)
        }
        .accentColor(Color(.darkGray))
        .onAppear {

        }
        .onChange(of: dependencies.authService.currentUser) { _, newUser in
            if let userId = newUser?.id {
                viewModel.webSocketManagerStore.initialize(for: userId)
            }
        }
    }
}
