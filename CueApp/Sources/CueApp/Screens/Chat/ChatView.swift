import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
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

            MessageInputView(
                inputMessage: $viewModel.inputMessage,
                isFocused: _isFocused,
                isEnabled: viewModel.isInputEnabled,
                onSend: viewModel.handleSendMessage
            )
        }
        .navigationTitle(viewModel.assistant.name)
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
