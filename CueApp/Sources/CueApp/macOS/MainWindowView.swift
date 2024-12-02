import SwiftUI

public struct MainWindowView: View {
    @StateObject private var webSocketManagerStore: WebSocketManagerStore
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var conversationManager: ConversationManager
    @State private var selectedAssistant: AssistantStatus?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(
                assistantsViewModel: assistantsViewModel,
                selectedAssistant: $selectedAssistant
            )
            #if os(macOS)
            .toolbarBackground(.clear, for: .windowToolbar)
            #endif
        } detail: {
            NavigationStack {
                DetailContent(
                    selectedAssistant: selectedAssistant,
                    assistantsViewModel: assistantsViewModel
                )
            }
            #if os(macOS)
            .toolbarBackground(Color.white, for: .windowToolbar)
            #endif
        }
        .onChange(of: authService.currentUser) { _, newUser in
            if let userId = newUser?.id {
                webSocketManagerStore.initialize(for: userId)
            }
        }
    }
}

private struct DetailContent: View {
    let selectedAssistant: AssistantStatus?
    let assistantsViewModel: AssistantsViewModel

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if let assistant = selectedAssistant {
                ChatView(
                    assistant: assistant,
                    webSocketManagerStore: assistantsViewModel.webSocketManagerStore,
                    assistantsViewModel: assistantsViewModel
                )
                .id(assistant.id)
            } else if let primaryAssistant = assistantsViewModel.assistantStatuses.first(where: { $0.assistant.metadata?.isPrimary == true }) {
                ChatView(
                    assistant: primaryAssistant,
                    webSocketManagerStore: assistantsViewModel.webSocketManagerStore,
                    assistantsViewModel: assistantsViewModel
                )
                .id(primaryAssistant.id)
            } else {
                ContentUnavailableView(
                    "No Assistant Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Select an assistant to start chatting")
                )
            }
        }
    }
}
