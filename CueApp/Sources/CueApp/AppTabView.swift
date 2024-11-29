import SwiftUI

enum TabSelection: String {
    case chat = "Chat"
    case assistants = "Assistants"
    case settings = "Settings"
    case web = "WebSocket"
}

public struct AppTabView: View {
    @State private var selectedTab: TabSelection = .chat
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var conversationManager: ConversationManager
    @EnvironmentObject private var webSocketManagerStore: WebSocketManagerStore

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            #if os(iOS)
            CueAppView()
                .tabItem {
                    Label("Chat", systemImage: "wand.and.stars")
                }
                .tag(TabSelection.chat)
            #endif
            AssistantsView(webSocketStore: webSocketManagerStore)
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
        .onAppear {

        }
        .onChange(of: authService.currentUser) { _, newUser in
            if let userId = newUser?.id {
                webSocketManagerStore.initialize(for: userId)
            }
        }
        #if os(macOS)
        .onChange(of: selectedTab) { _, newTab in
            if let window = NSApplication.shared.windows.first {
                window.title = newTab.rawValue
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }
}
