import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @SceneStorage("shouldAutoScroll") private var shouldAutoScroll = true
    @FocusState private var isFocused: Bool

    init(assistant: AssistantStatus,
         status: ClientStatus?,
         webSocketStore: WebSocketManagerStore) {
        _viewModel = StateObject(wrappedValue:
            ChatViewModel(
                assistant: assistant,
                status: status,
                webSocketStore: webSocketStore
            )
        )
        _assistantsViewModel = StateObject(wrappedValue: AssistantsViewModel(webSocketStore: webSocketStore))
    }

    var body: some View {
        VStack(spacing: 0) {
            MessagesListView(
                messages: viewModel.messageModels,
                shouldAutoScroll: shouldAutoScroll
            )
            .overlay(
                LoadingOverlay(isVisible: viewModel.isLoading)
            )
            .background(Color.gray.opacity(0.1))

            MessageInputView(
                inputMessage: $viewModel.inputMessage,
                isFocused: _isFocused,
                isEnabled: viewModel.isInputEnabled,
                onSend: viewModel.handleSendMessage
            )
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(viewModel.assistant.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AssistantDetailView(assistantsViewModel: self.assistantsViewModel, assistant: viewModel.assistant, status: viewModel.status)) {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .task {
            await viewModel.setupChat()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .alert(
            item: $viewModel.errorAlert
        ) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message)
            )
        }
    }
}
