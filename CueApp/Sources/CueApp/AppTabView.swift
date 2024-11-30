import SwiftUI

enum TabSelection: String {
    case chat = "Chat"
    case assistants = "Assistants"
    case settings = "Settings"
}

public struct AppTabView: View {
    @State private var selectedTab: TabSelection = .chat
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var conversationManager: ConversationManager
    @StateObject private var webSocketManagerStore: WebSocketManagerStore

    public init(webSocketManagerStore: WebSocketManagerStore) {
        _webSocketManagerStore = StateObject(wrappedValue: webSocketManagerStore)
        _assistantsViewModel = StateObject(
            wrappedValue: AssistantsViewModel(
                assistantService: AssistantService(),
                webSocketManagerStore: webSocketManagerStore
            )
        )
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            PrimaryChatView(webSocketManagerStore: self.webSocketManagerStore, assistantsViewModel: assistantsViewModel)
                .tabItem {
                    Label("Chat", systemImage: "wand.and.stars")
                }
                .tag(TabSelection.chat)
            AssistantsView(viewModel: assistantsViewModel)
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
        .onChange(of: authService.currentUser) { _, newUser in
            if let userId = newUser?.id {
                webSocketManagerStore.initialize(for: userId)
            }
        }
    }
}
