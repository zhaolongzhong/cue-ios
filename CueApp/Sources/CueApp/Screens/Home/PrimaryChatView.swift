import SwiftUI

struct PrimaryChatView: View {
    @ObservedObject var webSocketManagerStore: WebSocketManagerStore
    @ObservedObject var assistantsViewModel: AssistantsViewModel

    var body: some View {
        NavigationStack {
            VStack {
                if let primary = assistantsViewModel.primaryAssistant {
                    ChatView(
                        assistant: primary,
                        webSocketManagerStore: webSocketManagerStore,
                        assistantsViewModel: assistantsViewModel
                    )
                    .id(primary.id)
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text(assistantsViewModel.primaryAssistant?.name ?? "")
                            .font(.headline)
                    }
                }
            }
        }
    }
}
