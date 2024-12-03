import SwiftUI

public struct MainWindowView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var assistantsViewModel: AssistantsViewModel
    @State private var selectedAssistant: AssistantStatus?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(
                assistantsViewModel: assistantsViewModel,
                selectedAssistant: $selectedAssistant
            )
        } detail: {
            NavigationStack {
                DetailContent(
                    assistantsViewModel: assistantsViewModel,
                    selectedAssistant: selectedAssistant ?? assistantsViewModel.sortedAssistants.first
                )
            }
        }
        .onChange(of: dependencies.authService.currentUser) { _, newUser in
            if let userId = newUser?.id {
                assistantsViewModel.webSocketManagerStore.initialize(for: userId)
            }
        }
        .onChange(of: assistantsViewModel.assistantStatuses) { _, _ in
            if selectedAssistant == nil && !assistantsViewModel.sortedAssistants.isEmpty {
                selectedAssistant = assistantsViewModel.sortedAssistants.first
            }
        }
        .onAppear {
            if selectedAssistant == nil && !assistantsViewModel.sortedAssistants.isEmpty {
                selectedAssistant = assistantsViewModel.sortedAssistants.first
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
            } else {
                ContentUnavailableView(
                    "No Assistant Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Select an assistant to start chatting")
                )
            }
        }
        #if os(macOS)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        #endif
    }
}
