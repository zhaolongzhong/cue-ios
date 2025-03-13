import SwiftUI
import Dependencies

struct AssistantChatView: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @EnvironmentObject private var windowManager: CompanionWindowManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: AssistantChatViewModel
    @FocusState private var isFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @State private var selectedMessage: CueChatMessage?
    @State private var chatViewState: ChatViewState
    @State private var shouldScroll: Bool = false
    @State var shouldScrollToBottom = false
    @State var shouldScrollToUserMessage: Bool = false

    private let assistantsViewModel: AssistantsViewModel

    init(assistantChatViewModel: AssistantChatViewModel,
         assistantsViewModel: AssistantsViewModel,
         isCompanion: Bool = false
    ) {
        self.assistantsViewModel = assistantsViewModel
        self._viewModel = StateObject(wrappedValue: assistantChatViewModel)
        self.chatViewState = ChatViewState(isCompanion: isCompanion)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 4) {
                messageList
                RichTextField(
                    isFocused: $isFocused,
                    richTextFieldState: viewModel.richTextFieldState,
                    richTextFieldDelegate: richTextFieldDelegate
                )
            }
            if chatViewState.isCompanion {
                CompanionHeaderView(title: viewModel.assistant.name, isHovering: $chatViewState.isHovering)
            }
        }
        .background(chatViewState.isCompanion ? nil : (colorScheme == .light ? Color.white.opacity(0.9) : AppTheme.Colors.background.opacity(0.9)))
        .ignoresSafeArea(edges: .bottom)
        .withCoordinatorAlert(isCompanion: chatViewState.isCompanion)
        #if os(iOS)
        .defaultNavigationBar(showCustomBackButton: featureFlags.enableTabView, title: viewModel.assistant.name)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: AssistantDetailView(
                    assistant: viewModel.assistant,
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
            withAnimation(.easeInOut(duration: 0.2)) { chatViewState.isHovering = hovering }
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
        MessageListView(
            messages: viewModel.messageModels,
            onLoadMore: viewModel.loadMoreMessages,
            onShowMore: { message in
                selectedMessage = message
            },
            shouldScrollToBottom: $shouldScrollToBottom,
            isLoadingMore: $viewModel.isLoadingMore
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

    @MainActor
    private var richTextFieldDelegate: RichTextFieldDelegate {
        ChatViewDelegate(
            sendAction: {
                Task {
                    await viewModel.sendMessage()
                }
                Task { @MainActor in
                    withAnimation {
                        scrollProxy?.scrollTo(viewModel.messageModels.last?.id, anchor: .bottom)
                    }
                }
            }
        )
    }
}
