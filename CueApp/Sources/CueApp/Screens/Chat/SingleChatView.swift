//
//  SingleChatView.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

/// A modular view for displaying a single chat conversation
struct SingleChatView: View {
    // MARK: - Environment & Dependencies
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var windowManager: CompanionWindowManager
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Properties
    private let conversationId: String
    let provider: Provider
    @StateObject var viewModel: BaseChatViewModel
    @ObservedObject var conversationsVM: ConversationsViewModel
    @State private var shouldScrollToBottom = false
    @FocusState private var isFocused: Bool
    @State private var isCompanion: Bool
    @State private var isHovering: Bool = false

    // MARK: - Initialization
    init(
        conversationId: String,
        provider: Provider,
        isCompanion: Bool = false,
        dependencies: AppDependencies
    ) {

        self._viewModel = StateObject(
            wrappedValue: dependencies.viewModelFactory.makeBaseChatViewModel(conversationId, provider: provider)
        )
        self.conversationsVM = dependencies.viewModelFactory.makeConversationViewModel(provider: provider)
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
            .background(isCompanion ? nil : (colorScheme == .light ? Color.white.opacity(0.9) : AppTheme.Colors.background.opacity(0.9)))

            if isCompanion {
                CompanionHeaderView(isHovering: $isHovering)
            }
        }
        .background(isCompanion ? nil : (colorScheme == .light ? Color.white.opacity(0.9) : AppTheme.Colors.background.opacity(0.9)))
        .ignoresSafeArea(edges: .bottom)
        .toolbar {
            toolbarContent
            #if os(macOS)
            macToolbarContent
            #endif
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
            onShowMore: { _ in },
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
        #if os(iOS)
        .simultaneousGesture(DragGesture().onChanged { _ in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                          to: nil, from: nil, for: nil)
        })
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
}

extension SingleChatView {
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

extension SingleChatView {
    // MARK: Toolbar
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ModelSelectorToolbar(
            currentModel: viewModel.model,
            models: ChatModel.models(for: provider),
            iconView: AnyView(Provider.local.iconView),
            getModelName: { $0.displayName },
            onModelSelected: { model in
                viewModel.model = model
            },
            isStreamingEnabled: $viewModel.isStreamingEnabled,
            isToolEnabled: $viewModel.isToolEnabled
        )
    }

    #if os(macOS)
    @ToolbarContentBuilder
    var macToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Spacer()
            Button {
                createNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("Create new chat")
            Menu {
                Button("Open companion chat") {
                    openCompanionChat(isLive: false)
                }
                Button("Delete all messages") {
                    viewModel.deleteAllMessages()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("More options")
            .menuIndicator(.hidden)
        }
    }
    #endif
}
