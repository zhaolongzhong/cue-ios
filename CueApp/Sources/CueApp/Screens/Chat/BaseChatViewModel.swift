import Foundation
import Combine
import Dependencies
import CueCommon
import CueOpenAI

@MainActor
public class BaseChatViewModel: ObservableObject, ChatViewModelProtocol {
    @Dependency(\.conversationRepository) var conversationRepository
    @Dependency(\.messageRepository) var messageRepository

    @Published var conversationId: String
    @Published var conversations: [ConversationModel] = []
    @Published var cueChatMessages: [CueChatMessage] = []
    @Published var isLoadingMore = false
    @Published var shouldScrollToUserMessage: Bool = false
    @Published var initialRichTextFieldState: RichTextFieldState
    @Published var richTextFieldState: RichTextFieldState

    @Published var model: ChatModel
    @Published var availableCapabilities: [Capability] = [] {
        didSet { updateTools() }
    }
    @Published var selectedCapabilities: [Capability] = []
    @Published var attachments: [Attachment] = []
    @Published var isStreamingEnabled: Bool = true
    @Published var showLiveChat: Bool = false
    @Published var isToolEnabled: Bool = true
    @Published var isRunning: Bool = false {
        didSet {
            // Update the immutable state with the new running status
            richTextFieldState = richTextFieldState.copy(isRunning: isRunning)
        }
    }
    @Published var maxMessages: Int = 10
    @Published var maxTurns: Int = 10

    @Published var observedApp: AccessibleApplication?
    @Published var focusedLines: String?
    @Published var isLoading = false
    @Published var error: ChatError?
    @Published var apiKey: String

    private var selectedConversation: ConversationModel?
    let toolManager: ToolManager
    var tools: [JSONValue] = []

    #if os(macOS)
    let axManager: AXManager
    private var textAreaContent: TextAreaContent?
    private var textAreaContents: [TextAreaContent] = []
    #endif

    var cancellables = Set<AnyCancellable>()
    let provider: Provider

    init(
        apiKey: String,
        provider: Provider,
        model: ChatModel,
        conversationId: String,
        richTextFieldState: RichTextFieldState? = nil
    ) {
        self.apiKey = apiKey
        self.provider = provider
        self.model = model
        self.toolManager = ToolManager()

        #if os(macOS)
        self.axManager = AXManager()
        #endif

        self.availableCapabilities = toolManager.getAllAvailableCapabilities()
        self.conversationId = conversationId
        let richTextFieldState = richTextFieldState ?? RichTextFieldState(conversationId: conversationId)
        self.initialRichTextFieldState = richTextFieldState
        self.richTextFieldState = richTextFieldState.copy()

        #if os(macOS)
        setupToolsSubscription()
        setupTextAreaContentSubscription()
        #endif
        Task {
            self.selectedConversation = try? await conversationRepository.getConversation(id: conversationId)
        }
    }

    func clearError() {
        error = nil
    }

    private func lastSelectedModelKey(for providerId: String) -> String {
        return "lastSelectedModel_\(providerId)"
    }

    // MARK: - Tools management
    func updateTools() {
        var capabilityNames = self.selectedConversation?.metadata?.capabilities ?? []
        capabilityNames = capabilityNames.map { $0.lowercased() }

        let predicateBlock: (Capability) -> Bool = { capability in
                switch capability {
                case .tool(let tool):
                    return capabilityNames.contains(tool.name.lowercased())
                #if os(macOS)
                case .mcpServer(let server):
                    return capabilityNames.contains(server.serverName.lowercased())
                #endif
                }
            }
        self.selectedCapabilities = self.availableCapabilities.filter(predicateBlock)

        // Update the immutable state with new capabilities
        richTextFieldState = richTextFieldState.copy(
            availableCapabilities: availableCapabilities,
            selectedCapabilities: selectedCapabilities
        )

        tools = toolManager.getJSONValues(selectedCapabilities, model: model.id)
        AppLog.log.debug("Update capabilities, selected capabilities: \(self.selectedCapabilities.map {$0.name}), tools: \(self.tools.count)")
    }

    private func setupToolsSubscription() {
        #if os(macOS)
        toolManager.mcpToolsPublisher
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.availableCapabilities = self.toolManager.getAllAvailableCapabilities()
            }
            .store(in: &cancellables)
        #endif
    }

    func updateSelectedCapabilities(_ capabilities: [Capability]) async {
        do {            
            guard let coversation = self.selectedConversation else {
                AppLog.log.error("No selected conversation")
                return
            }
            let newConversation = ConversationModel(
                id: coversation.id,
                title: coversation.title,
                createdAt: coversation.createdAt,
                updatedAt: Date(),
                assistantId: nil,
                metadata: ConversationMetadata(isPrimary: coversation.metadata?.isPrimary ?? false, capabilities: capabilities.map { $0.name })
            )
            try await conversationRepository.update(newConversation)
            self.selectedConversation = newConversation

            // Update the immutable state with new selected capabilities
            richTextFieldState = richTextFieldState.copy(selectedCapabilities: capabilities)
            self.selectedCapabilities = capabilities

            updateTools()
        } catch {
            AppLog.log.error("Error getting conversation: \(error)")
        }
    }

    func startServer() async {
        #if os(macOS)
        await self.toolManager.startMcpServer()
        #endif
    }

    // MARK: - Observed app functionality
    func updateObservedApplication(to app: AccessibleApplication?) {
        guard let app = app else {
            stopObserveApp()
            return
        }
        #if os(macOS)
        self.axManager.updateObservedApplication(to: app)
        #endif
        self.observedApp = app
        richTextFieldState = richTextFieldState.copy(observedApp: observedApp)
    }

    func stopObserveApp() {
        #if os(macOS)
        self.axManager.stopObserving()
        self.observedApp = nil
        self.textAreaContent = nil
        self.textAreaContents = []
        richTextFieldState = richTextFieldState.copy(clearObservedApp: true)
        #endif
    }

    private func setupTextAreaContentSubscription() {
        #if os(macOS)
        axManager.$textAreaContentList
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.textAreaContents = newValue
                self.textAreaContent = newValue.first
                self.focusedLines = self.textAreaContent?.focusedLines
                self.richTextFieldState = richTextFieldState.copy(textAreaContents: textAreaContents)
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Message management
    func addAttachment(_ attachment: Attachment) {
        attachments.append(attachment)
    }

    func loadMessages() async {
        switch await messageRepository.fetchCachedMessages(forConversation: conversationId, skip: 0, limit: 50) {
        case .success(let messageModels):
            self.cueChatMessages = messageModels
                .sorted(by: { $0.createdAt < $1.createdAt })
                .compactMap { $0.toCueChatMessage() }
            AppLog.log.debug("Loading messages for conversation \(self.conversationId) succeeded: \(self.cueChatMessages.count)")
        case .failure(let error):
            self.error = ChatError.unknownError(error.localizedDescription)
        }
    }

    func deleteMessage(_ message: CueChatMessage) async {
        await messageRepository.deleteCachedMessage(id: message.id)
        cueChatMessages = cueChatMessages.filter { $0.id != message.id }
    }

    func deleteAllMessages() {
        self.cueChatMessages.removeAll()

        Task {
            await messageRepository.deleteAllCachedMessages(forConversation: conversationId)
        }
    }

    func addOrUpdateMessage(_ message: CueChatMessage, persistInCache: Bool = false) {
        if let existingIndex = self.cueChatMessages.firstIndex(where: { $0.id == message.id }) {
            self.cueChatMessages[existingIndex] = message
        } else {
            self.cueChatMessages.append(message)
        }

        if persistInCache {
            Task {
                await saveMessage(message)
            }
        }
    }

    private func saveMessage(_ message: CueChatMessage) async {
        let messageModel = MessageModel(from: message, conversationId: conversationId)
        let saveResult = await messageRepository.saveMessage(messageModel: messageModel)
        if case .failure(let error) = saveResult {
            self.error = ChatError.unknownError(error.localizedDescription)
        }
    }

    // These methods must be implemented by subclasses
    func sendMessage() async {
        fatalError("sendMessage() must be implemented by subclasses")
    }

    func stopAction() async {
        fatalError("stopAction() must be implemented by subclasses")
    }
}
