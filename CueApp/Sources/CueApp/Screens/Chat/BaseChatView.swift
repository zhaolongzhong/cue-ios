//
//  BaseChatView.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

// MARK: - Chat View Model Protocol
@MainActor
protocol ChatViewModel: ObservableObject {
    var attachments: [Attachment] { get set }
    var cueChatMessages: [CueChatMessage] { get set }
    var richTextFieldState: RichTextFieldState { get set }
    var newMessage: String { get set }
    var error: ChatError? { get }
    var observedApp: AccessibleApplication? { get }
    var focusedLines: String? { get }
    var selectedConversationId: String? { get set }
    var availableTools: [Tool] { get }
    var model: ChatModel { get set }
    var isStreamingEnabled: Bool { get set }
    var isToolEnabled: Bool { get set }

    func startServer() async
    func updateObservedApplication(to app: AccessibleApplication?)
    func stopObserveApp()
    func addAttachment(_ attachment: Attachment)
    func sendMessage() async
    func stopAction() async
    func deleteMessage(_ message: CueChatMessage) async
    func clearError()
}

// MARK: - Base Chat View
struct BaseChatView<ViewModel: ChatViewModel>: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var windowManager: CompanionWindowManager
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var viewModel: ViewModel
    @StateObject private var conversationsViewModel: ConversationsViewModel

    @SceneStorage("shouldAutoScroll") private var shouldAutoScroll = true
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isFocused: Bool
    @State private var scrollThrottleWorkItem: DispatchWorkItem?

    @State private var chatViewState: ChatViewState

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
                selectedConversationId: storedConversationId ?? viewModel.selectedConversationId,
                provider: provider
            )
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                messageList
                observedAppView
                richTextField
            }
            if chatViewState.isCompanion {
                CompanionHeaderView(isHovering: $chatViewState.isHovering)
            }
        }
        .slidingSidebar(
            isShowing: $chatViewState.showingSidebar,
            width: 280,
            edge: .trailing,
            sidebarOpacity: 0.95
        ) {
            ConversationsView(
                viewModel: conversationsViewModel,
                isShowing: $chatViewState.showingSidebar,
                provider: provider
            ) { conversationId in
                viewModel.selectedConversationId = conversationId
            }
        }
        .withCoordinatorAlert(isCompanion: chatViewState.isCompanion)
        .navigationBarBackButtonHidden(true)
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
        .sheet(isPresented: $chatViewState.showingToolsList) {
            ToolsListView(tools: viewModel.availableTools)
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
            withAnimation(.easeInOut(duration: 0.2)) { $chatViewState.isHovering.wrappedValue = hovering }
        }
        #endif
    }

    // MARK: Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ModelSelectorToolbar(
            currentModel: viewModel.model,
            models: ChatModel.models(for: provider),
            iconView: AnyView(Provider.local.iconView),
            getModelName: { $0.displayName },
            onModelSelected: { model in
                storedModel.wrappedValue = model
                viewModel.model = model
            },
            isStreamingEnabled: $viewModel.isStreamingEnabled,
            isToolEnabled: $viewModel.isToolEnabled
        )
    }

    #if os(macOS)
    @ToolbarContentBuilder
    private var macToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Spacer()
            Button {
                createNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("Create New Session")
            Button {
                withAnimation(.easeInOut) {
                    $chatViewState.showingSidebar.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: "list.bullet")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("Open Sessions")
            Menu {
                Button("Open companion chat") {
                    openCompanionChat(viewModel.model)
                }
                Button("Provider Details") {
                    $chatViewState.isShowingProviderDetails.wrappedValue = true
                }
                Button("Clear Messages") {
                    if let localVM = viewModel as? LocalChatViewModel {
                       localVM.resetMessages()
                   }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .modifier(ToolbarIconStyle())
                    .foregroundStyle(.primary)
            }
            .help("More Options")
            .menuIndicator(.hidden)
        }
    }
    #endif

    // MARK: - Message List
    private var messageList: some View {
        MessagesListView(
            messages: viewModel.cueChatMessages,
            shouldAutoScroll: shouldAutoScroll,
            onScrollProxyReady: { proxy in
                scrollProxy = proxy
            },
            onLoadMore: {},
            onShowMore: { _ in }
        )
        .scrollDismissesKeyboard(.never)
        .id(viewModel.selectedConversationId)
        #if os(macOS)
        .safeAreaInset(edge: .top) {
            if chatViewState.isCompanion {
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
            inputMessage: Binding(
                get: { viewModel.newMessage },
                set: { viewModel.newMessage = $0 }
            ),
            isFocused: $isFocused,
            richTextFieldState: viewModel.richTextFieldState,
            richTextFieldDelegate: richTextFieldDelegate
        )
    }

    private var richTextFieldDelegate: RichTextFieldDelegate {
        ChatViewDelegate(
            chatViewModel: viewModel,
            showToolsAction: {
                $chatViewState.showingToolsList.wrappedValue = true
            },
            openLiveChatAction: {
                self.openLiveChat()
            },
            scrollToBottomAction: {
                withAnimation {
                    scrollProxy?.scrollTo(viewModel.cueChatMessages.last?.id, anchor: .bottom)
                }
            },
            sendAction: {
                Task {
                    await viewModel.sendMessage()
                }
            },
            stopAction: {
                print("ix")
            }
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

    func createNewConversation() {
        Task {
            if let newId = await conversationsViewModel.createConversation(provider: provider) {
                viewModel.selectedConversationId = newId
                withAnimation(.easeInOut(duration: 0.3)) {
                    $chatViewState.showingSidebar.wrappedValue = false
                }
            }
        }
    }

    // MARK: - Companion Chat
    func openCompanionChat(_ model: ChatModel) {
        let config = CompanionWindowConfig(
            model: model.rawValue,
            provider: provider,
            additionalSettings: [:]
        )
        let windowId = windowManager.openCompanionWindow(id: UUID().uuidString, config: config)
        openWindow(id: WindowId.compainionChatWindow.rawValue, value: windowId.id)
    }

    func openLiveChat() {
        switch provider {
        case .openai:
            openWindow(id: WindowId.openaiLiveChatWindow.rawValue, value: WindowId.openaiLiveChatWindow.rawValue)
        case .gemini:
            openWindow(id: WindowId.geminiLiveChatWindow.rawValue, value: WindowId.geminiLiveChatWindow.rawValue)
        default:
            break
        }
    }
}
