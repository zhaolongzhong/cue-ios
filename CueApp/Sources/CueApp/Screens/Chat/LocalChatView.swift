import SwiftUI
import CueOpenAI

public struct LocalChatView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var windowManager: CompanionWindowManager

    @StateObject private var viewModel: LocalChatViewModel
    @FocusState private var isFocused: Bool
    @Namespace private var bottomID
    @State private var scrollThrottleWorkItem: DispatchWorkItem?
    @AppStorage("selectedLocalModel") private var storedModel: ChatModel = .deepSeekR17B
    @AppStorage(ProviderSettingsKeys.MaxMessage.local) private var maxMessages = 20
    @AppStorage(ProviderSettingsKeys.MaxTurns.local) private var maxTurns = 20
    @AppStorage(ProviderSettingsKeys.Streaming.local) private var storedStreamingEnabled: Bool = true
    @AppStorage(ProviderSettingsKeys.ToolEnabled.local) private var storedToolEnabled: Bool = true
    @AppStorage(ProviderSettingsKeys.BaseURL.local) private var storedBaseURL: String?
    @State private var showingToolsList = false
    @State private var selectedApp: AccessibleApplication = .textEdit
    @State private var isHovering = false
    @State private var expandedMessageIds: Set<String> = []
    @State private var isShowingProviderDetails = false

    private let showAXapp: Bool
    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping () -> LocalChatViewModel, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        self.isCompanion = isCompanion

        #if os(macOS)
        self.showAXapp = true
        #else
        self.showAXapp = false
        #endif
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack {
                messageList
                observedAppView
                RichTextField(
                    showAXapp: true,
                    onShowTools: {
                        showingToolsList = true
                    },
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
                    toolCount: viewModel.model.isToolSupported && viewModel.isToolEnabled ? viewModel.availableTools.count : 0,
                    inputMessage: $viewModel.newMessage,
                    isFocused: $isFocused
                )
            }
            if isCompanion {
                CompanionHeaderView(isHovering: $isHovering)
            }
        }
        .withCoordinatorAlert(isCompanion: isCompanion)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            toolbarContent
            #if os(macOS)
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Menu {
                    Button("Open companion chat") {
                        openCompanionChat(with: viewModel.model)
                    }
                    Button("Details") {
                        showProviderDetails()
                    }
                    Button("Clear Messages") {
                        viewModel.resetMessages()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.primary)
                }
                .menuIndicator(.hidden)
            }
            #endif
        }
        .onAppear {
            viewModel.model = storedModel
            viewModel.isStreamingEnabled = storedStreamingEnabled
            viewModel.isToolEnabled = storedToolEnabled
            // Set the base URL if available, otherwise use default
            if let baseURL = storedBaseURL, !baseURL.isEmpty {
                viewModel.baseURL = baseURL
            } else {
                viewModel.baseURL = UserDefaults.standard.baseURLWithDefault(for: .local)
            }
            Task {
                await viewModel.startServer()
            }
        }
        .onChange(of: viewModel.messages.count) { _, _ in
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
        .onChange(of: viewModel.isStreamingEnabled) { _, newValue in
            storedStreamingEnabled = newValue
        }
        .onChange(of: viewModel.isToolEnabled) { _, newValue in
            storedToolEnabled = newValue
        }
        .sheet(isPresented: $showingToolsList) {
            ToolsListView(tools: viewModel.availableTools)
        }
        .sheet(
            isPresented: $isShowingProviderDetails,
            onDismiss: {
                reloadProviderSettings()
            },
            content: {
                ProviderDetailView(provider: .local)
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
            withAnimation(.easeInOut(duration: 0.2)) { isHovering = hovering }
        }
        #endif
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ModelSelectorToolbar(
            currentModel: viewModel.model,
            models: ChatModel.models(for: .local),
            iconView: AnyView(Provider.local.iconView),
            getModelName: { $0.displayName },
            onModelSelected: { model in
                storedModel = model
                viewModel.model = model
            },
            isStreamingEnabled: $viewModel.isStreamingEnabled,
            isToolEnabled: $viewModel.isToolEnabled
        )
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isExpanded: expandedMessageIds.contains(message.id),
                            onShowMore: { expandMessage($0) },
                            onToggleThinking: { message, blockId in
                                toggleThinkingBlock(for: message, blockId: blockId)
                            }
                        )
                    }
                    // Invisible marker view at bottom with a fixed ID
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.top)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                throttledScroll(proxy: proxy)
            }
            .onChange(of: viewModel.streamingMessageContent) { _, _ in
                throttledScroll(proxy: proxy)
            }
        }
    }

    private func throttledScroll(proxy: ScrollViewProxy) {
        guard scrollThrottleWorkItem == nil else { return }

        let workItem = DispatchWorkItem {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                self.scrollThrottleWorkItem = nil
            }
        }

        scrollThrottleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

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

    // MARK: Navigation
    private func showProviderDetails() {
        isShowingProviderDetails = true
    }

    func openCompanionChat(with model: ChatModel) {
        let config = CompanionWindowConfig(
            model: model.rawValue,
            provider: .local,
            additionalSettings: [:]
        )
        windowManager.openCompanionWindow(id: UUID().uuidString, config: config)
    }

    private func expandMessage(_ message: CueChatMessage) {
        if expandedMessageIds.contains(message.id) {
            expandedMessageIds.remove(message.id)
        } else {
            expandedMessageIds.insert(message.id)
        }
    }

    private func reloadProviderSettings() {
        viewModel.maxMessages = maxMessages
        viewModel.maxTurn = maxTurns
        viewModel.isStreamingEnabled = storedStreamingEnabled
        viewModel.isToolEnabled = storedToolEnabled
        if let baseURL = storedBaseURL, !baseURL.isEmpty {
            viewModel.baseURL = baseURL
        } else {
            viewModel.baseURL = UserDefaults.standard.baseURLWithDefault(for: .local)
        }
    }
}
extension LocalChatView {
    private func toggleThinkingBlock(for message: CueChatMessage, blockId: String) {
        // Find the message in the viewModel
        guard let index = viewModel.messages.firstIndex(where: { $0.id == message.id }) else {
            return
        }

        // Create a message with toggled thinking block state
        let updatedMessage = message.toggleThinkingBlock(id: blockId)

        // Handle type conversion for OpenAI messages to preserve state
        let finalMessage: CueChatMessage
        if case .openAI = message, let streamingState = updatedMessage.streamingState {
            switch updatedMessage {
            case .openAI(let msg):
                finalMessage = .local(msg, stableId: message.id, streamingState: streamingState)
            default:
                finalMessage = updatedMessage
            }
        } else {
            finalMessage = updatedMessage
        }

        viewModel.messages[index] = finalMessage
        viewModel.objectWillChange.send()
    }
}
