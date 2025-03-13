import Foundation
import Combine
import Dependencies
import CueCommon
import CueOpenAI

@MainActor
public class BaseChatViewModel: ObservableObject, ChatViewModelProtocol {
    @Dependency(\.conversationRepository) var conversationRepository
    @Dependency(\.messageRepository) var messageRepository

    @Published var conversationId: String {
        didSet {
            Task {
                if !self.conversationId.isEmpty {
                    self.selectedConversation = try? await conversationRepository.getConversation(id: conversationId)
                    await setUpInitialMessages()
                }
            }
        }
    }
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
    @Published var attachments: [Attachment] = [] {
        didSet {
            self.richTextFieldState = self.richTextFieldState.copy(attachments: attachments)
        }
    }
    @Published var isStreamingEnabled: Bool = true
    @Published var showLiveChat: Bool = false
    @Published var isToolEnabled: Bool = true
    @Published var initialMessagesLoaded: Bool = false
    @Published var isRunning: Bool = false {
        didSet {
            // Update the immutable state with the new running status
            richTextFieldState = richTextFieldState.copy(isRunning: isRunning)
        }
    }
    @Published var maxMessages: Int = 10
    @Published var maxTurns: Int = 10

    @Published var focusedLines: String?
    @Published var isLoading = false
    @Published var error: ChatError?
    @Published var apiKey: String

    private var selectedConversation: ConversationModel?
    private var enabledCapabilities: [Capability] = []
    let toolManager: ToolManager
    var tools: [JSONValue] = []

    #if os(macOS)
    let axManager: AXManager
    private var workingApps: [String: AccessibleApplication] = [:]
    var textAreaContents: [String: TextAreaContent] = [:] {
        didSet {
            self.richTextFieldState = richTextFieldState.copy(textAreaContents: textAreaContents)
            AppLog.log.debug("Text area contents updated: \(self.textAreaContents.values.map(\.app.name))")
        }
    }
    #endif

    var cancellables = Set<AnyCancellable>()
    let provider: Provider
    let enableRemote: Bool

    init(
        apiKey: String,
        provider: Provider,
        model: ChatModel,
        conversationId: String,
        richTextFieldState: RichTextFieldState? = nil,
        enabledTools: [any LocalTool] = [],
        enableRemote: Bool = false
    ) {
        self.apiKey = apiKey
        self.provider = provider
        self.model = model
        self.toolManager = ToolManager(preEnabledTools: enabledTools)
        self.enabledCapabilities = enabledTools.map { $0.toCapability() }
        self.enableRemote = enableRemote

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
            if !conversationId.isEmpty {
                self.selectedConversation = try? await conversationRepository.getConversation(id: conversationId)
            }
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
            case .localTool(let tool):
                return capabilityNames.contains(tool.name.lowercased())
            case .tool(let tool):
                return capabilityNames.contains(tool.name.lowercased())
            #if os(macOS)
            case .mcpServer(let server):
                return capabilityNames.contains(server.serverName.lowercased())
            #endif
            }
        }

        self.selectedCapabilities = self.availableCapabilities.filter(predicateBlock)
        self.selectedCapabilities.append(contentsOf: self.enabledCapabilities)

        // Update the immutable state with new capabilities
        richTextFieldState = richTextFieldState.copy(
            availableCapabilities: availableCapabilities,
            selectedCapabilities: selectedCapabilities
        )

        tools = toolManager.getJSONValues(selectedCapabilities, model: model.id)
        AppLog.log.debug("Update capabilities, selected capabilities: \(self.selectedCapabilities.map {$0.name}), tools: \(self.tools.count)")
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
            try await conversationRepository.update(newConversation, enableRemote: enableRemote)
            self.selectedConversation = newConversation

            // Update the immutable state with new selected capabilities
            richTextFieldState = richTextFieldState.copy(selectedCapabilities: capabilities)
            self.selectedCapabilities = capabilities
            AppLog.log.debug("Updated selected capabilities to: \(capabilities.map(\.name))")

            updateTools()
        } catch {
            AppLog.log.error("Error getting conversation: \(error)")
        }
    }

    // MARK: - Message management
    func addAttachment(_ attachment: Attachment) {
        attachments.append(attachment)
    }

    func setUpInitialMessages() async {
        guard !conversationId.isEmpty else {
            AppLog.log.debug("Skip to load messages: empty conversation ID")
            return
        }
        await loadMessages(conversationId)
    }

    func loadMessages(_ conversationId: String) async {
        guard !conversationId.isEmpty else {
            AppLog.log.error("loadMessages conversationId is empty")
            return
        }
        switch await messageRepository.listMessages(conversationId: conversationId, skip: 0, limit: 50, enableRemote: enableRemote) {
        case .success(let messageModels):
            AppLog.log.debug("Loading messages for conversation \(self.conversationId) succeeded: \(messageModels.count)")
            self.cueChatMessages = messageModels
                .sorted(by: { $0.createdAt < $1.createdAt })
                .compactMap { $0.toCueChatMessage() }
            self.initialMessagesLoaded = true
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

    func addOrUpdateMessage(_ message: CueChatMessage, persistInCache: Bool = false, enableRemote: Bool = false) {
        if let existingIndex = self.cueChatMessages.firstIndex(where: { $0.id == message.id }) {
            self.cueChatMessages[existingIndex] = message
        } else {
            self.cueChatMessages.append(message)
        }

        if persistInCache || enableRemote {
            Task {
                await saveMessage(message, enableRemote: enableRemote)
            }
        }
    }

    private func saveMessage(_ message: CueChatMessage, enableRemote: Bool = false) async {
        let messageModel = MessageModel(from: message, conversationId: conversationId)
        let saveResult = await messageRepository.saveMessage(messageModel: messageModel, enableRemote: enableRemote)
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

// MARK: - MCP Servers
extension BaseChatViewModel {
    func startServer() async {
        #if os(macOS)
        await self.toolManager.startMcpServer()
        #endif
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
}

// MARK: - Working app
extension BaseChatViewModel {

    // MARK: - Observed app functionality
    func onUpdateWorkingApp(to app: AccessibleApplication, working: Bool) {
        #if os(macOS)
        if !working {
            if !app.isVSCodeIDE {
                self.axManager.stopObserving()
            }

            let fileNames = textAreaContents.values.filter { textAreaContent in
                textAreaContent.app.bundleId == app.bundleId
            }.compactMap { $0.fileName }

            for key in fileNames {
                textAreaContents.removeValue(forKey: key)
            }

            workingApps.removeValue(forKey: app.bundleId)
        } else {
            if !app.isVSCodeIDE {
                #if os(macOS)
                self.axManager.updateObservedApplication(to: app)
                #endif
            }
            workingApps[app.bundleId] = app

        }
        richTextFieldState = richTextFieldState.copy(workingApps: workingApps)
        #endif
    }

    private func setupTextAreaContentSubscription() {
        #if os(macOS)
        axManager.$textAreaContentList
            .sink { [weak self] newValue in
                guard let self = self else { return }
                for content in newValue {
                    if let fileName = content.fileName {
                        self.textAreaContents[fileName] = content
                    }
                }
            }
            .store(in: &cancellables)
        #endif
    }
}
