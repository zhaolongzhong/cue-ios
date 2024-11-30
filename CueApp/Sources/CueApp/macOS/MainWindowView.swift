import SwiftUI

public struct MainWindowView: View {
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var conversationManager: ConversationManager
    @State private var selectedAssistant: AssistantStatus?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init(webSocketManagerStore: WebSocketManagerStore) {
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
        } detail: {
            DetailContent(
                selectedAssistant: selectedAssistant,
                assistantsViewModel: assistantsViewModel
            )
        }
    }
}

private struct DetailContent: View {
    let selectedAssistant: AssistantStatus?
    let assistantsViewModel: AssistantsViewModel

    var body: some View {
        if let assistant = selectedAssistant {
            ChatView(
                assistant: assistant,
                webSocketManagerStore: assistantsViewModel.webSocketManagerStore,
                assistantsViewModel: assistantsViewModel
            )
            .toolbar(.visible, for: .automatic)
            .id(assistant.id)
        } else if let primaryAssistant = assistantsViewModel.assistantStatuses.first(where: { $0.assistant.metadata?.isPrimary == true }) {
            ChatView(
                assistant: primaryAssistant,
                webSocketManagerStore: assistantsViewModel.webSocketManagerStore,
                assistantsViewModel: assistantsViewModel
            )
            .toolbar(.visible, for: .automatic)
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

struct Sidebar: View {
    @ObservedObject var assistantsViewModel: AssistantsViewModel
    @Binding var selectedAssistant: AssistantStatus?
    @State private var isShowingNewAssistantSheet = false

    var body: some View {
        VStack {
            List(selection: $selectedAssistant) {
                Section("Assistants") {
                    ForEach(assistantsViewModel.assistantStatuses.sorted { first, second in
                        if first.assistant.metadata?.isPrimary == true {
                            return true
                        }
                        if second.assistant.metadata?.isPrimary == true {
                            return false
                        }
                        return first.isOnline && !second.isOnline
                    }) { assistant in
                        AssistantRow(
                            assistant: assistant,
                            viewModel: assistantsViewModel
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listItemTint(Color.clear)
                        .tag(assistant)
                    }
                }
            }

            .accentColor(AppTheme.Colors.lightGray)
            .listStyle(.sidebar)
            .listRowInsets(EdgeInsets())
            .scrollContentBackground(.hidden)

            HStack {
                UserAvatarMenu()
                Spacer()
            }
            .padding(.all, 4)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Cue")
        .toolbar {
            ToolbarItem {
                NewAssistantButton(action: { isShowingNewAssistantSheet = true })
            }
        }
        .toolbarBackground(.visible, for: .automatic)
        .sheet(isPresented: $isShowingNewAssistantSheet) {
            NewAssistantSheet(
                isPresented: $isShowingNewAssistantSheet,
                viewModel: assistantsViewModel
            )
        }
    }
}
