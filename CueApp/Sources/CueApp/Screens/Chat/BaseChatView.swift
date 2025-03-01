//
//  BaseChatView.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

// MARK: - Chat View Model Protocol
@MainActor
protocol ChatViewModel: ObservableObject {
    var cueChatMessages: [CueChatMessage] { get set }
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
    @FocusState var isFocused: Bool
    @Namespace var bottomID

    var provider: Provider
    var availableModels: [ChatModel]
    var storedModel: Binding<ChatModel>
    var isCompanion: Bool
    var showVoiceChat: Bool
    var showingSidebar: Binding<Bool>
    var isHovering: Binding<Bool>
    var scrollThrottleWorkItem: Binding<DispatchWorkItem?>
    var showingToolsList: Binding<Bool>
    var isShowingProviderDetails: Binding<Bool>

    var isStreamingEnabled: Binding<Bool>?
    var isToolEnabled: Binding<Bool>?
    var storedConversationId: String?

    let onAppear: () -> Void
    var onReloadProviderSettings: (() -> Void)?

    init(
        viewModel: ViewModel,
        provider: Provider,
        availableModels: [ChatModel],
        storedModel: Binding<ChatModel>,
        isCompanion: Bool,
        showVoiceChat: Bool,
        showingSidebar: Binding<Bool>,
        isHovering: Binding<Bool>,
        scrollThrottleWorkItem: Binding<DispatchWorkItem?>,
        showingToolsList: Binding<Bool>,
        isShowingProviderDetails: Binding<Bool>,
        isStreamingEnabled: Binding<Bool>? = nil,
        isToolEnabled: Binding<Bool>? = nil,
        storedConversationId: String? = nil,
        onAppear: @escaping () -> Void,
        onReloadProviderSettings: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.provider = provider
        self.availableModels = availableModels
        self.storedModel = storedModel
        self.isCompanion = isCompanion
        self.showVoiceChat = showVoiceChat
        self.showingSidebar = showingSidebar
        self.isHovering = isHovering
        self.scrollThrottleWorkItem = scrollThrottleWorkItem
        self.showingToolsList = showingToolsList
        self.isShowingProviderDetails = isShowingProviderDetails
        self.isStreamingEnabled = isStreamingEnabled
        self.isToolEnabled = isToolEnabled
        self.storedConversationId = storedConversationId
        self.onAppear = onAppear
        self.onReloadProviderSettings = onReloadProviderSettings

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
            if isCompanion {
                CompanionHeaderView(isHovering: isHovering)
            }
        }
        .slidingSidebar(
            isShowing: showingSidebar,
            width: 280,
            edge: .trailing,
            sidebarOpacity: 0.95
        ) {
            ConversationsView(
                isShowing: showingSidebar,
                provider: provider,
                selectedConversationId: storedConversationId ?? viewModel.selectedConversationId
            ) { conversationId in
                viewModel.selectedConversationId = conversationId
            }
        }
        .withCoordinatorAlert(isCompanion: isCompanion)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            toolbarContent
            #if os(macOS)
            macToolbarContent
            #endif
        }
        .onAppear {
            onAppear()
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
        .sheet(isPresented: showingToolsList) {
            ToolsListView(tools: viewModel.availableTools)
        }
        .sheet(
            isPresented: isShowingProviderDetails,
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
            withAnimation(.easeInOut(duration: 0.2)) { isHovering.wrappedValue = hovering }
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
                    showingSidebar.wrappedValue.toggle()
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
                    isShowingProviderDetails.wrappedValue = true
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.cueChatMessages) { message in
                        MessageBubble(message: message).contextMenu {
                            Button {
                                Task {
                                    await viewModel.deleteMessage(message)
                                }
                            } label: {
                                Text("Delete")
                            }
                        }
                    }
                    // Invisible marker view at bottom
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.top)
            }
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
            .onChange(of: viewModel.cueChatMessages.count) { _, _ in
                throttledScroll(proxy: proxy)
            }
            // Add streaming message content change handler if needed
            .onChange(of: (viewModel as? LocalChatViewModel)?.streamingMessageContent) { _, _ in
                throttledScroll(proxy: proxy)
            }
        }
    }

    private func throttledScroll(proxy: ScrollViewProxy) {
        guard scrollThrottleWorkItem.wrappedValue == nil else { return }

        let workItem = DispatchWorkItem {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
                scrollThrottleWorkItem.wrappedValue = nil
            }
        }

        scrollThrottleWorkItem.wrappedValue = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    // MARK: - Rich Text Field
    private var richTextField: some View {
        RichTextField(
            showVoiceChat: showVoiceChat,
            showAXapp: true,
            onShowTools: {
                showingToolsList.wrappedValue = true
            },
            onOpenVoiceChat: openLiveChat,
            onStartAXApp: { app in
                viewModel.updateObservedApplication(to: app)
            },
            onSend: {
                Task {
                    await viewModel.sendMessage()
                }
            },
            onAttachmentPicked: { attachment in
                viewModel.addAttachment(attachment)
            },
            toolCount: (isToolEnabled?.wrappedValue ?? true) ? viewModel.availableTools.count : 0,
            inputMessage: Binding(
                get: { viewModel.newMessage },
                set: { viewModel.newMessage = $0 }
            ),
            isFocused: $isFocused
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
                    showingSidebar.wrappedValue = false
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
