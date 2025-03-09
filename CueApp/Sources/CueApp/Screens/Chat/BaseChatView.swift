//
//  BaseChatView.swift
//  CueApp
//

import SwiftUI
import CueOpenAI


// MARK: - Base Chat View
struct BaseChatView<ViewModel: ChatViewModelProtocol>: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var windowManager: CompanionWindowManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: ViewModel
    @StateObject private var conversationsViewModel: ConversationsViewModel

    @SceneStorage("shouldAutoScroll") private var shouldAutoScroll = true
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isFocused: Bool
    @State private var scrollThrottleWorkItem: DispatchWorkItem?

    @State var chatViewState: ChatViewState
    @State var shouldScrollToBottom = false
    @State var isScrolledToBottom = true
    @State var selectedConversationId: String? {
        didSet {
            if let conversationId = selectedConversationId, conversationId != oldValue {

            }
        }
    }

    var provider: Provider
    var availableModels: [ChatModel]
    var storedModel: Binding<ChatModel>

    var isStreamingEnabled: Binding<Bool>?
    var isToolEnabled: Binding<Bool>?
    var storedConversationId: String?

    var onReloadProviderSettings: (() -> Void)?

    init(
        viewModel: ViewModel,
        provider: Provider,
        availableModels: [ChatModel],
        storedModel: Binding<ChatModel>,
        isStreamingEnabled: Binding<Bool>? = nil,
        isToolEnabled: Binding<Bool>? = nil,
        storedConversationId: String? = nil,
        onReloadProviderSettings: (() -> Void)? = nil,
        chatViewState: ChatViewState? = nil
    ) {
        self.viewModel = viewModel
        self.provider = provider
        self.availableModels = availableModels
        self.storedModel = storedModel
        self.isStreamingEnabled = isStreamingEnabled
        self.isToolEnabled = isToolEnabled
        self.storedConversationId = storedConversationId
        self.onReloadProviderSettings = onReloadProviderSettings
        self.chatViewState = chatViewState ?? ChatViewState()

        self._conversationsViewModel = StateObject(
            wrappedValue: ConversationsViewModel(
                provider: provider
            )
        )
    }

    var body: some View {
        if let conversationId = viewModel.selectedConversationId {
            SingleChatView(
                conversationId: conversationId,
                provider: provider,
//                viewModel: dependencies.viewModelFactory.makeBaseChatViewModel(conversationId, provider: provider),
                isCompanion: chatViewState.isCompanion,
                isHovering: $chatViewState.isHovering,
                dependencies: dependencies
            )
            .id(conversationId)
            .withCoordinatorAlert(isCompanion: chatViewState.isCompanion)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                toolbarContent
                #if os(macOS)
                macToolbarContent
                #endif
            }
            .onChange(of: viewModel.showLiveChat) { oldValue, newValue in
                if newValue {
                    openCompanionChat(isLive: true)
                    viewModel.showLiveChat = false
                }
            }
            .sheet(
                isPresented: $chatViewState.isShowingProviderDetails,
                onDismiss: {
                    onReloadProviderSettings?()
                },
                content: {
                    ProviderDetailView(provider: provider)
                        .environmentObject(dependencies)
                }
            )
            .slidingSidebar(
                isShowing: $chatViewState.showingSidebar,
                width: 280,
                edge: .trailing,
                sidebarOpacity: 0.95
            ) {
                ConversationsView(
                    viewModel: conversationsViewModel,
//                    isShowing: $chatViewState.showingSidebar,
                    provider: provider
                ) { conversationId in
                    viewModel.selectedConversationId = conversationId
                }
            }
        } else {
            // No conversation selected - show a placeholder or empty state
            VStack {
                Text("No conversation selected")
                Button("Create New Conversation") {
                    createNewConversation()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}


// MARK: - Navigation and Actions

extension BaseChatView {
    func createNewConversation() {
        Task {
            if let newItem = await conversationsViewModel.createConversation(provider: provider) {
                viewModel.selectedConversationId = newItem.id
                withAnimation(.easeInOut(duration: 0.3)) {
                    $chatViewState.showingSidebar.wrappedValue = false
                }
            }
        }
    }

    private var richTextFieldDelegate: RichTextFieldDelegate {
        ChatViewDelegate(
            chatViewModel: viewModel,
            openLiveChatAction: {
                openCompanionChat(isLive: true)
            },
            sendAction: {
                Task {
                    await viewModel.sendMessage()
                }
            }
        )
    }

    // MARK: - Companion Chat
    func openCompanionChat(isLive: Bool = false) {
        let config = CompanionWindowConfig(
            model: viewModel.model.rawValue,
            provider: provider,
            conversationId: viewModel.selectedConversationId,
            additionalSettings: [:]
        )
        if !isLive {
            let windowId = windowManager.openCompanionWindow(id: UUID().uuidString, config: config)
            openWindow(id: WindowId.compainionChatWindow.rawValue, value: windowId.id)
        } else {
            #if os(iOS)
            coordinator.showLiveChatSheet(config)
            #else
            windowManager.activeLiveChatWindow = config
            openWindow(id: WindowId.liveChatWindow.rawValue, value: WindowId.liveChatWindow.rawValue)
            #endif
        }
    }
}
