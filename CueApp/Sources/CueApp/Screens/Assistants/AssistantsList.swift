import SwiftUI

@MainActor
protocol AssistantActions {
    func onDelete(assistant: Assistant)
    func onDetails(assistant: Assistant)
    func onSetPrimary(assistant: Assistant) async
    func onChat(assistant: Assistant)
}

struct AssistantsList: View {
    @ObservedObject var assistantsViewModel: AssistantsViewModel
    let actions: AssistantActions

    var body: some View {
        List {
            ForEach(assistantsViewModel.assistants) { assistant in
                AssistantRow(
                    assistant: assistant,
                    status: assistantsViewModel.getClientStatus(for: assistant),
                    actions: actions
                )
                .onTapGesture {
                    actions.onChat(assistant: assistant)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        actions.onDelete(assistant: assistant)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.orange)
                }
            }
        }
        .refreshable {
            assistantsViewModel.refreshAssistants()
        }
        .overlay {
            if assistantsViewModel.isLoading {
                ProgressView()
            }
        }
    }
}