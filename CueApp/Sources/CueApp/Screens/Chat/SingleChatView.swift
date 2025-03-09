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
    @State private var shouldScrollToBottom = false
    @FocusState private var isFocused: Bool
    @State private var isCompanion: Bool
    @Binding private var isHovering: Bool

    // MARK: - Initialization
    init(
        conversationId: String,
        provider: Provider,
//        viewModel: BaseChatViewModel,
        isCompanion: Bool = false,
        isHovering: Binding<Bool> = .constant(false),
        dependencies: AppDependencies
    ) {

        switch provider {
        case .openai:
            print("single chat view, init viewmode with conversation id: \(conversationId)")
            self._viewModel = StateObject(
                wrappedValue: dependencies.viewModelFactory.makeOpenAIChatViewModel(conversationId)
            )
        case .anthropic:
            self._viewModel = StateObject(
                wrappedValue: dependencies.viewModelFactory.makeAnthropicChatViewModel(conversationId)
            )
        default:
            self._viewModel = StateObject(
                wrappedValue: dependencies.viewModelFactory.makeOpenAIChatViewModel(conversationId)
            )
        }

        self.conversationId = conversationId
        self.provider = provider
        self._isCompanion = State(initialValue: isCompanion)
        self._isHovering = isHovering
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 4) {
                messageList
                observedAppView
                richTextField
            }
            .background(colorScheme == .light ? Color.white.opacity(0.9) : AppTheme.Colors.background.opacity(0.9))

            if isCompanion {
                CompanionHeaderView(isHovering: $isHovering)
            }
        }
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
        .onChange(of: viewModel.showLiveChat) { oldValue, newValue in
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
            print("inx onAppear: \(viewModel.cueChatMessages.count), conversationId: \(conversationId), viewModel.selectedConversationId: \(viewModel.selectedConversationId)")
            Task {
                await viewModel.loadMessages()
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

    // MARK: - Observed App View
    private var observedAppView: some View {
        Group {
            if let observedApp = viewModel.observedApp {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Observed app: \(observedApp.name)")
                        if let focusedLines = viewModel.focusedLines {
                            Text(focusedLines)
                        }
                    }
                    Button("Stop") {
                        viewModel.stopObserveApp()
                    }
                }
                .padding(.all, 12)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.separator))
            }
        }
    }
}


// MARK: - Navigation and Actions

extension SingleChatView {
    func createNewConversation() {
        Task {
//            if let newItem = await conversationsViewModel.createConversation(provider: provider) {
//                viewModel.selectedConversationId = newItem.id
//                withAnimation(.easeInOut(duration: 0.3)) {
//                    $chatViewState.showingSidebar.wrappedValue = false
//                }
//            }
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
