//
//  BaseChatViewModel.swift
//  CueApp
//

import Foundation
import Combine
import Dependencies
import CueCommon
import CueOpenAI

@MainActor
public class BaseChatViewModel: ObservableObject, ChatViewModel {
    @Dependency(\.conversationRepository) var conversationRepository
    @Dependency(\.messageRepository) var messageRepository

    // Common published properties
    @Published var selectedConversationId: String? {
        didSet {
            if oldValue != selectedConversationId && selectedConversationId != nil {
                Task { await loadMessages() }
            }
        }
    }
    @Published var conversations: [ConversationModel] = []
    @Published var cueChatMessages: [CueChatMessage] = []
    @Published var isLoadingMore = false
    @Published var newMessage: String = ""
    @Published var shouldScrollToUserMessage: Bool = false
    @Published var richTextFieldState: RichTextFieldState

    // Configuration
    @Published var model: ChatModel
    @Published var availableTools: [Tool] = [] {
        didSet {
            richTextFieldState.toolCount = availableTools.count
        }
    }
    @Published var attachments: [Attachment] = []
    @Published var isStreamingEnabled: Bool = true
    @Published var isToolEnabled: Bool = true
    @Published var isRunning: Bool = false {
        didSet {
            richTextFieldState.isRunning = isRunning
        }
    }
    @Published var maxMessages: Int = 10
    @Published var maxTurns: Int = 10

    // Observed app state
    @Published var observedApp: AccessibleApplication?
    @Published var focusedLines: String?

    // Status
    @Published var isLoading = false
    @Published var error: ChatError?
    @Published var apiKey: String

    // Common tools
    let toolManager: ToolManager
    var tools: [JSONValue] = []

    #if os(macOS)
    let axManager: AXManager
    private var textAreaContent: TextAreaContent?
    #endif

    var cancellables = Set<AnyCancellable>()
    let provider: Provider

    init(apiKey: String, provider: Provider, model: ChatModel, conversationId: String? = nil, richTextFieldState: RichTextFieldState? = nil) {
        self.apiKey = apiKey
        self.provider = provider
        self.model = model
        self.toolManager = ToolManager()

        #if os(macOS)
        self.axManager = AXManager()
        #endif

        self.availableTools = toolManager.getTools()
        self.selectedConversationId = conversationId
        self.richTextFieldState = richTextFieldState ?? RichTextFieldState()

        updateTools()

        #if os(macOS)
        setupToolsSubscription()
        setupTextAreaContentSubscription()
        #endif
    }

    func setStoredConversationId(_ id: String?) {
        selectedConversationId = id
    }

    // MARK: - Common Functionality for Chat View Models

    // Tools management
    func updateTools() {
        tools = self.toolManager.getToolsJSONValue(model: self.model.id)
    }

    private func setupToolsSubscription() {
        #if os(macOS)
        toolManager.mcpToolsPublisher
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.availableTools = self.toolManager.getTools()
                updateTools()
            }
            .store(in: &cancellables)
        #endif
    }

    func startServer() async {
        #if os(macOS)
        await self.toolManager.startMcpServer()
        #endif
    }

    // Observed app functionality
    func updateObservedApplication(to app: AccessibleApplication?) {
        guard let app = app else { return }
        #if os(macOS)
        self.axManager.updateObservedApplication(to: app)
        #endif
        self.observedApp = app
    }

    func stopObserveApp() {
        #if os(macOS)
        self.axManager.stopObserving()
        self.observedApp = nil
        self.textAreaContent = nil
        #endif
    }

    private func setupTextAreaContentSubscription() {
        #if os(macOS)
        axManager.$textAreaContentList
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.textAreaContent = newValue.first
                self.focusedLines = self.textAreaContent?.focusedLines
            }
            .store(in: &cancellables)
        #endif
    }

    // Message management
    func addAttachment(_ attachment: Attachment) {
        attachments.append(attachment)
    }

    func clearError() {
        error = nil
    }

    func loadConversations() async {
        do {
            let result = try await conversationRepository.fetchConversationsByProvider(
                provider: provider,
                limit: 100,
                offset: 0
            )
            AppLog.log.debug("Fetched \(result.count) conversations for provider: \(self.provider.displayName)")
            if selectedConversationId == nil, let firstId = conversations.first?.id {
                selectedConversationId = firstId
            }
        } catch {
            self.error = ChatError.sessionError(error.localizedDescription)
            AppLog.log.error("Failed to fetch conversations: \(error)")
        }
    }

    func loadMessages() async {
        guard let conversationId = selectedConversationId else { return }
        switch await messageRepository.fetchCachedMessages(forConversation: conversationId, skip: 0, limit: 50) {
        case .success(let messageModels):
            self.cueChatMessages = messageModels
                .sorted(by: { $0.createdAt < $1.createdAt })
                .compactMap { $0.toCueChatMessage() }
            AppLog.log.debug("Loading messages for conversation \(conversationId) succeeded: \(self.cueChatMessages.count)")
        case .failure(let error):
            self.error = ChatError.unknownError(error.localizedDescription)
        }
    }

    func deleteMessage(_ message: CueChatMessage) async {
        await messageRepository.deleteCachedMessage(id: message.id)
        cueChatMessages = cueChatMessages.filter { $0.id != message.id }
    }

    func getOrCreateConversationId() async -> String? {
        if let id = selectedConversationId { return id }
        do {
            let result = try await conversationRepository.createConversation(
                title: "No title",
                assistantId: "",
                isPrimary: false,
                provider: provider
            )
            selectedConversationId = result.id
            return result.id
        } catch {
            self.error = ChatError.unknownError(error.localizedDescription)
            return nil
        }
    }

    func addOrUpdateMessage(_ message: CueChatMessage, persistInCache: Bool = false) {
        if let existingIndex = self.cueChatMessages.firstIndex(where: { $0.id == message.id }) {
            self.cueChatMessages[existingIndex] = message
        } else {
            self.cueChatMessages.append(message)
        }

        if message.isUser {
            DispatchQueue.main.async {
                self.shouldScrollToUserMessage = true
            }
        }

        if persistInCache {
            Task {
                await saveMessage(message)
            }
        }
    }

    private func saveMessage(_ message: CueChatMessage) async {
        guard let conversationId = selectedConversationId else {
            AppLog.log.warning("Cannot save message because no conversation is selected")
            return
        }
        let messageModel = MessageModel(from: message, conversationId: conversationId)
        let saveResult = await messageRepository.saveMessage(messageModel: messageModel)
        if case .failure(let error) = saveResult {
            self.error = ChatError.unknownError(error.localizedDescription)
        }
    }

    // This method must be implemented by subclasses
    func sendMessage() async {
        fatalError("sendMessage() must be implemented by subclasses")
    }

    func stopAction() async {
        fatalError("stopAction() must be implemented by subclasses")
    }
}
