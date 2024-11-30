import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    let assistantsViewModel: AssistantsViewModel
    @SceneStorage("shouldAutoScroll") private var shouldAutoScroll = true
    @FocusState private var isFocused: Bool

    init(assistant: AssistantStatus,
         webSocketManagerStore: WebSocketManagerStore,
         assistantsViewModel: AssistantsViewModel) {
        self.assistantsViewModel = assistantsViewModel
        _viewModel = StateObject(wrappedValue:
            ChatViewModel(
                assistant: assistant,
                webSocketManagerStore: webSocketManagerStore
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
            .background(Color.gray.opacity(0.1))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MessageInputView(
                inputMessage: $viewModel.inputMessage,
                isFocused: _isFocused,
                isEnabled: viewModel.isInputEnabled,
                onSend: viewModel.handleSendMessage
            )
        }
        .background(AppTheme.Colors.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(viewModel.assistant.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: AssistantDetailView(
                    assistantsViewModel: self.assistantsViewModel,
                    assistant: viewModel.assistant,
                    onUpdate: handleAssistantUpdate)) {
                    Image(systemName: "ellipsis")
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.showAssistantDetails = true
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            #endif
        }
        #if !os(iOS)
        .sheet(isPresented: $viewModel.showAssistantDetails) {
            AssistantDetailView(
                assistantsViewModel: self.assistantsViewModel,
                assistant: viewModel.assistant,
                onUpdate: handleAssistantUpdate
            )
            .frame(minWidth: 400, minHeight: 300)
            .presentationCompactAdaptation(.popover)
        }
        #endif
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

    private func handleAssistantUpdate(updatedAssistant: AssistantStatus) {
        viewModel.updateAssistant(updatedAssistant)
    }
}
