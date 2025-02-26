import SwiftUI

struct AssistantChatView: View {
    @EnvironmentObject private var windowManager: CompanionWindowManager
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel: AssistantChatViewModel
    @SceneStorage("shouldAutoScroll") private var shouldAutoScroll = true
    @SceneStorage("chatScrollPosition") private var scrollPosition: String?
    @FocusState private var isFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @State private var selectedMessage: CueChatMessage?
    @State private var showingToolsList = false
    @State private var isHovering = false
    let assistantsViewModel: AssistantsViewModel
    private let isCompanion: Bool

    init(assistantChatViewModel: AssistantChatViewModel,
         assistantsViewModel: AssistantsViewModel,
         isCompanion: Bool = false
    ) {
        self.assistantsViewModel = assistantsViewModel
        _viewModel = StateObject(wrappedValue: assistantChatViewModel)
        self.isCompanion = isCompanion
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 16) {
                messageList
                RichTextField(
                    isEnabled: viewModel.isInputEnabled,
                    onShowTools: {
                    },
                    onSend: {
                        Task {
                            await viewModel.sendMessage()
                        }
                        withAnimation {
                            scrollProxy?.scrollTo(viewModel.messageModels.last?.id, anchor: .bottom)
                        }
                    },
                    inputMessage: $viewModel.newMessage,
                    isFocused: $isFocused
                )
            }
            if isCompanion {
                CompanionHeaderView(title: viewModel.assistant.name, isHovering: $isHovering)
            }
        }
        .withCoordinatorAlert(isCompanion: isCompanion)
        #if os(iOS)
        .defaultNavigationBar(showCustomBackButton: false, title: viewModel.assistant.name)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: AssistantDetailView(
                    assistant: viewModel.assistant,
                    assistantsViewModel: self.assistantsViewModel,
                    onUpdate: handleAssistantUpdate)) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary.opacity(0.9))
                }
            }
            ToolbarItem(placement: .principal) {
                Text(viewModel.assistant.name)
                    .font(.headline)
            }
            #else
            ToolbarItem(placement: .principal) {
                Text(viewModel.assistant.name)
                    .font(.headline)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Menu {
                    Button("Open companion chat") {
                        openCompanionChat(with: viewModel.assistant.id)
                    }
                    Button("Details") {
                        viewModel.showAssistantDetails = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.primary)
                }
                .menuIndicator(.hidden)
            }
            #endif
        }
        .overlay(
            LoadingOverlay(isVisible: viewModel.isLoading)
        )
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
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { isHovering = hovering }
        }
        #endif
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

    private var messageList: some View {
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
        .scrollDismissesKeyboard(.never)
        .id(viewModel.assistant.id)
    }

    private func handleAssistantUpdate(updatedAssistant: Assistant) {
        viewModel.updateAssistant(updatedAssistant)
    }

    func openCompanionChat(with assistantId: String) {
        let config = CompanionWindowConfig(
            assistantId: assistantId,
            additionalSettings: ["assistant_id": assistantId]
        )
        let windowId = windowManager.openCompanionWindow(id: UUID().uuidString, config: config)
        openWindow(id: WindowId.compainionChatWindow.rawValue, value: windowId.id)
    }
}
