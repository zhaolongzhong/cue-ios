import SwiftUI

struct DetailContent: View {
    @EnvironmentObject private var dependencies: AppDependencies
    let assistantsViewModel: AssistantsViewModel
    let selectedAssistant: AssistantStatus?

    var body: some View {
        ZStack {
            if let assistant = selectedAssistant {
                ChatView(
                    assistant: assistant,
                    chatViewModel: dependencies.viewModelFactory.makeChatViewViewModel(assistant: assistant),
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
    }
}
