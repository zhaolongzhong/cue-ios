import SwiftUI

public struct MainWindowView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var assistantViewModel: AssistantsViewModel
    @State private var selectedAssistant: AssistantStatus?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(
                assistantsViewModel: assistantViewModel,
                selectedAssistant: $selectedAssistant
            )
        } detail: {
            NavigationStack {
                DetailContent(
                    assistantsViewModel: assistantViewModel,
                    selectedAssistant: selectedAssistant
                )
            }
            .background(AppTheme.Colors.background)
        }
        .onChange(of: dependencies.authService.currentUser) { _, newUser in
            if let userId = newUser?.id {
                assistantViewModel.webSocketManagerStore.initialize(for: userId)
            }
        }
    }
}

private struct DetailContent: View {
    let assistantsViewModel: AssistantsViewModel
    let selectedAssistant: AssistantStatus?

    var body: some View {
        ZStack {
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
