import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    let assistantsViewModel: AssistantsViewModel
    @SceneStorage("shouldAutoScroll") private var shouldAutoScroll = true
    @SceneStorage("chatScrollPosition") private var scrollPosition: String?
    @FocusState private var isFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @State private var selectedMessage: MessageModel?

    init(assistant: Assistant,
         chatViewModel: ChatViewModel,
         assistantsViewModel: AssistantsViewModel,
         tag: String? = nil) {
        self.assistantsViewModel = assistantsViewModel
        _viewModel = StateObject(wrappedValue: chatViewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            Rectangle()
                .fill(AppTheme.Colors.separator.opacity(0.5))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
            #endif

            MessagesListView(
                messages: viewModel.messageModels,
                shouldAutoScroll: shouldAutoScroll,
                onScrollProxyReady: { proxy in
                    scrollProxy = proxy
                },
                onLoadMore: viewModel.loadMoreMessages,
                onShowMore: { message in
                    selectedMessage = message
                }
            )
            .padding(.horizontal, 10)
            .background(Color.clear)
            .id(viewModel.assistant.id)
            .overlay(
                LoadingOverlay(isVisible: viewModel.isLoading)
            )
            .scrollDismissesKeyboard(.never)

            RichTextField(isEnabled: viewModel.isInputEnabled, onShowTools: {
            }, onSend: {
                Task {
                    await viewModel.sendMessage()
                }
                withAnimation {
                    scrollProxy?.scrollTo(viewModel.messageModels.last?.id, anchor: .bottom)
                }
            }, inputMessage: $viewModel.newMessage, isFocused: $isFocused)
            .padding(.all, 8)
        }
        .background(Color.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    if isFocused {
                        isFocused = false
                    }
                }
        )
        #endif
        .navigationTitle(viewModel.assistant.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: AssistantDetailView(
                    assistant: viewModel.assistant,
                    assistantsViewModel: self.assistantsViewModel,
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
                assistant: viewModel.assistant,
                assistantsViewModel: self.assistantsViewModel,
                onUpdate: handleAssistantUpdate
            )
            .frame(minWidth: 400, minHeight: 300)
            .presentationCompactAdaptation(.popover)
        }
        #endif
        .sheet(item: $selectedMessage) { message in
            FullMessageView(message: message)
        }
        .onAppear {
            Task {
                await viewModel.setupChat()
            }
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

    private func handleAssistantUpdate(updatedAssistant: Assistant) {
        viewModel.updateAssistant(updatedAssistant)
    }
}
