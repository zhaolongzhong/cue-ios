//
//  SingleChatView.swift
//  CueApp
//

import SwiftUI
import Dependencies
import CueOpenAI

/// A modular view for displaying a single chat conversation
struct AssistantChatViewV2: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var windowManager: CompanionWindowManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Properties
    private let assistant: Assistant
    private let conversationId: String
    let provider: Provider
    @StateObject var viewModel: AssistantChatViewModelV2
    @ObservedObject var conversationsVM: ConversationsViewModel
    @ObservedObject var assistantsViewModel: AssistantsViewModel
    @FocusState private var isFocused: Bool
    @State private var shouldScrollToBottom = false
    @State private var isCompanion: Bool
    @State private var isHovering: Bool = false
    @State private var selectedMessage: CueChatMessage?

    // MARK: - Initialization
    init(
        assistant: Assistant,
        conversationId: String,
        provider: Provider,
        isCompanion: Bool = false,
        dependencies: AppDependencies
    ) {

        self.assistant = assistant
        self._viewModel = StateObject(
            wrappedValue: dependencies.viewModelFactory.makeAssistantChatViewModelV2(assistant: assistant)
        )
        self.conversationsVM = dependencies.viewModelFactory.makeConversationViewModel(provider: provider)
        self.assistantsViewModel = dependencies.viewModelFactory.makeAssistantsViewModel()
        self.conversationId = conversationId
        self.provider = provider
        self._isCompanion = State(initialValue: isCompanion)
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 4) {
                messageList
                richTextField
            }

            if isCompanion {
                CompanionHeaderView(isHovering: $isHovering)
            }
        }
        .background(isCompanion ? nil : (colorScheme == .light ? Color.white.opacity(0.9) : AppTheme.Colors.background.opacity(0.9)))
        .ignoresSafeArea(edges: .bottom)
        .toolbar {
            toolbarContent
        }
        .sheet(item: $selectedMessage) { message in
            FullMessageView(message: message)
        }
        #if os(iOS)
        .defaultNavigationBar(showCustomBackButton: featureFlags.enableTabView)
        #endif
        #if os(macOS)
        .sheet(isPresented: $viewModel.showAssistantDetails) {
            detailsSheet
        }
        #endif
        .onChange(of: viewModel.initialMessagesLoaded) { _, newValue in
            if newValue {
                shouldScrollToBottom = true
            }
        }
        .onChange(of: viewModel.cueChatMessages.count) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onChange(of: viewModel.error) { _, error in
            if let error = error {
                coordinator.showError(error.message)
                viewModel.clearError()
            }
        }
        .onChange(of: viewModel.showLiveChat) { _, newValue in
            if newValue {
                openCompanionChat(isLive: true)
                viewModel.showLiveChat = false
            }
        }
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        #endif
        .onAppear {
            Task {
                await viewModel.setUpInitialMessages()
                await viewModel.startServer()
            }
        }
    }

    // MARK: - Message List
    private var messageList: some View {
        MessageListView(
            conversatonId: conversationId,
            messages: viewModel.cueChatMessages,
            onLoadMore: {},
            onShowMore: { message in
                selectedMessage = message
            },
            shouldScrollToBottom: $shouldScrollToBottom,
            isLoadingMore: $viewModel.isLoadingMore
        )
        .scrollDismissesKeyboard(.never)
        #if os(macOS)
        .safeAreaInset(edge: .top) {
            if isCompanion {
                Color.clear.frame(height: 36)
            }
        }
        #endif
    }

    // MARK: - Rich Text Field
    private var richTextField: some View {
        RichTextField(
            isFocused: $isFocused,
            richTextFieldState: viewModel.richTextFieldState,
            richTextFieldDelegate: viewModel
        )
    }

    private var detailsSheet: some View {
        AssistantDetailView(
            assistant: viewModel.assistant,
            onUpdate: { assistant in
                viewModel.assistant = assistant
            }
        )
        .standardSheet()
        .presentationCompactAdaptation(.popover)
    }
}

extension AssistantChatViewV2 {
    func createNewConversation() {
        Task {
            if let newItem = await conversationsVM.createConversation(provider: provider) {
                viewModel.conversationId = newItem.id
            }
        }
    }

    func openCompanionChat(isLive: Bool = false) {
        let config = CompanionWindowConfig(
            model: viewModel.model.rawValue,
            provider: provider,
            conversationId: viewModel.conversationId,
            additionalSettings: [:]
        )
        if !isLive {
            let windowId = windowManager.openCompanionWindow(id: UUID().uuidString, config: config)
            openWindow(id: WindowId.compainionChatWindow.rawValue, value: windowId.id)
        } else {
            #if os(iOS)
            coordinator.showLiveChatSheet(config)
            #else
            if windowManager.activeLiveChatWindow?.conversationId != config.conversationId {
                windowManager.activeLiveChatWindow = config
                openWindow(id: WindowId.liveChatWindow.rawValue, value: WindowId.liveChatWindow.rawValue)
            }
            #endif
        }
    }
}

extension AssistantChatViewV2 {
    // MARK: Toolbar
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(viewModel.assistant.name)
                .font(.headline)
        }
        #if os(iOS)
        ToolbarItem(placement: .automatic) {
            NavigationLink(destination: AssistantDetailView(
                assistant: viewModel.assistant,
                onUpdate: { assistant in
                    viewModel.assistant = assistant
                })) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary.opacity(0.9))
            }
        }
        #endif
        ToolbarItemGroup(placement: .primaryAction) {
            #if os(macOS)
            Spacer()
            Menu {
                Button("Open companion chat") {
                    openCompanionChat()
                }
                Button("Details") {
                    viewModel.showAssistantDetails = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("More options")
            .menuIndicator(.hidden)
            #endif
        }
    }
}
