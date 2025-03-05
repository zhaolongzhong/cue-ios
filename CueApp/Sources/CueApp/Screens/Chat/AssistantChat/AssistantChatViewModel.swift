import SwiftUI
import Combine
import Dependencies
import CueCommon

@MainActor
final class AssistantChatViewModel: ObservableObject {
    @Dependency(\.authRepository) var authRepository
    @Dependency(\.assistantRepository) private var assistantRepository
    @Dependency(\.messageRepository) private var messageRepository
    @Dependency(\.webSocketService) public var webSocketService
    @Dependency(\.clientStatusService) public var clientStatusService

    @Published private(set) var messageModels: [CueChatMessage] = []
    @Published private(set) var assistant: Assistant
    @Published private(set) var isLoading = false
    @Published private(set) var currentConnectionState: ConnectionState = .disconnected
    @Published private(set) var clientStatus: ClientStatus?
    @Published var errorAlert: ErrorAlert?
    @Published var showAssistantDetails = false
    @Published var isInputEnabled = true
    @Published var isLoadingMore = false
    @Published var richTextFieldState: RichTextFieldState

    private var primaryConversation: ConversationModel?
    private var cancellables = Set<AnyCancellable>()
    private var messageSubscription: Task<Void, Never>?
    private var assistantRecipientId: String {
        self.clientStatus?.runnerId ?? self.assistant.id
    }
    private var messageCount: Int = 0
    private var loadMoreTask: Task<Void, Never>?

    init(assistant: Assistant) {
        self.assistant = assistant
        self.richTextFieldState =  RichTextFieldState()
        setupConnectionStateSubscription()
        setupMessageHandler()
    }

    deinit {
        messageSubscription?.cancel()
        messageSubscription = nil
    }

    private func setupConnectionStateSubscription() {
        webSocketService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.currentConnectionState = state
                self?.isInputEnabled = state == .connected
            }
            .store(in: &cancellables)
    }

    private func setupMessageHandler() {
        webSocketService.webSocketMessagePublisher
            .receive(on: DispatchQueue.main)
                .sink { [weak self] message in
                    if case .messagePayload(let messagePayload) = message {
                        self?.processMessagePayload(messagePayload)
                    }
                }
                .store(in: &cancellables)
    }

    private func setupClientStatusSubscription() {
        clientStatusService.$clientStatuses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] statuses in
                guard let self = self else { return }
                let status = statuses.values.first(where: { $0.assistantId == self.assistant.id })
                self.clientStatus = status
            }
            .store(in: &cancellables)
    }

    private func subscribeToMessages(conversationId: String) {
        messageSubscription?.cancel()
        messageSubscription = Task {
            for await message in await messageRepository.makeMessageStream(forConversation: conversationId) {
                guard !Task.isCancelled else { break }
                withAnimation {
                    self.messageModels.append(.cue(message))
                }
            }
        }
    }

    private func processMessagePayload(_ messagePayload: MessagePayload) {
        if messagePayload.recipientAssistantId != assistantRecipientId {
            return
        }
        guard let conversationId = self.primaryConversation?.id else {
            AppLog.log.error("Received message without primary conversation for assistant: \(String(describing: self.assistant))")
            return
        }

        let messageModel = MessageModel(
            from: messagePayload,
            conversationId: conversationId
        )

        Task {
            switch await messageRepository.saveMessage(messageModel: messageModel) {
            case .success:
                richTextFieldState.inputMessage = ""
            case .failure(let error):
                handleError(error, context: "Failed to send message")
            }
        }
    }

    // MARK: - Setup
    func setupChat() async {
         isLoading = true
         defer {
             isLoading = false
         }

         self.primaryConversation = await fetchAssistantConversation(id: assistant.id)

         guard let conversationId = primaryConversation?.id else {
             return
         }

         await loadCachedMessages(conversationId: conversationId)
         subscribeToMessages(conversationId: conversationId)
         await fetchRemoteMessages(conversationId: conversationId)
     }

    private func loadCachedMessages(conversationId: String) async {
        switch await messageRepository.fetchCachedMessages(forConversation: conversationId, skip: 0, limit: 50) {
        case .success(let messages):
            self.messageModels = messages.map { .cue($0) }
            AppLog.log.debug("Initial messages loaded: \(messages.count)")
        case .failure(let error):
            handleError(error, context: "Loading cached messages failed")
        }
    }

    private func fetchRemoteMessages(conversationId: String) async {
        switch await messageRepository.listMessages(conversationId: conversationId, skip: 0, limit: 50) {
        case .success(let messages):
            self.messageModels = messages.map { .cue($0) }
            self.messageCount = messages.count
        case .failure(.fetchFailed(let error)):
            handleError(error, context: "Fetching messages failed")

        case .failure(.invalidConversationId):
            handleError(MessageRepositoryError.invalidConversationId, context: "Invalid conversation")

        case .failure(let error):
            handleError(error, context: "Unknown error occurred")
        }
    }

    func loadMoreMessages() async {
        guard !isLoadingMore,
              !messageModels.isEmpty,
              let conversationId = primaryConversation?.id else {
            return
        }

        loadMoreTask?.cancel()
        loadMoreTask = Task<Void, Never> {
            isLoadingMore = true
            defer {
                isLoadingMore = false
                loadMoreTask = nil
            }

            guard !Task.isCancelled else {
                return
            }

            let result = await messageRepository.listMessages(
                conversationId: conversationId,
                skip: self.messageCount,
                limit: 20
            )

            guard !Task.isCancelled else {
                return
            }

            switch result {
            case .success(let newMessages):
                guard !newMessages.isEmpty else { return }
                let existingMessageIds = Set(messageModels.map { $0.id })
                let uniqueNewMessages: [CueChatMessage] = newMessages.map { .cue($0) }.filter { !existingMessageIds.contains($0.id) }
                if !uniqueNewMessages.isEmpty {
                    self.messageModels.insert(contentsOf: uniqueNewMessages, at: 0)
                    self.messageCount += uniqueNewMessages.count
                }
            case .failure(let error):
                handleError(error, context: "Fetching messages failed")
            }
        }
    }

    // MARK: - Message Handling
    func sendMessage() async {
        guard richTextFieldState.isMessageValid else {
            return
        }
        if self.clientStatus == nil {
            self.clientStatus = clientStatusService.getClientStatus(for: self.assistant.id)
        }

        let messageToSend = richTextFieldState.inputMessage
        guard let userId = authRepository.currentUser?.id else {
            return
        }

        let uuid = UUID().uuidString
        let messagePayload = MessagePayload(
            message: messageToSend,
            sender: userId,
            recipient: assistantRecipientId,
            websocketRequestId: uuid,
            metadata: nil,
            userId: userId,
            payload: nil
        )

        let clientEvent = EventMessage(
            type: .user,
            payload: .message(messagePayload),
            clientId: EnvironmentConfig.shared.clientId,
            metadata: nil,
            websocketRequestId: uuid
        )

        do {
            try webSocketService.send(event: clientEvent)
            richTextFieldState.inputMessage = ""
        } catch {
            errorAlert = ErrorAlert(
                title: "Error",
                message: "Sent message failed: \(error.localizedDescription)"
            )
        }
    }

    func updateAssistant(_ newAssistant: Assistant) {
        assistant = newAssistant
    }

    // MARK: - Error Handling
    private func handleError(_ error: Error, context: String) {
        AppLog.websocket.error("\(context) error: \(error)")
        errorAlert = ErrorAlert(
            title: "Error",
            message: "\(context) failed: \(error.localizedDescription)"
        )
    }

    // MARK: - Cleanup
    func cleanup() {
        messageSubscription?.cancel()
    }
}

extension AssistantChatViewModel {
    private func fetchAssistantConversation(id: String) async -> ConversationModel? {
        switch await assistantRepository.listAssistantConversations(id: id, isPrimary: true, skip: 0, limit: 20) {
        case .success(let conversations):
            if conversations.isEmpty {
                return await createPrimaryAssistant()
            } else {
                return conversations[0]
            }

        case .failure(.fetchFailed(let error)):
            handleError(error, context: "Fetching assistant conversations failed")
            return nil

        case .failure(.invalidAssistantId):
            handleError(AssistantRepositoryError.invalidAssistantId, context: "Invalid assistant ID")
            return nil

        case .failure(let error):
            handleError(error, context: "Unknown error occurred")
            return nil
        }
    }

    private func createPrimaryAssistant() async -> ConversationModel? {
        switch await assistantRepository.createPrimaryConversation(assistantId: assistant.id, name: nil) {
        case .success(let conversation):
            return conversation

        case .failure(let error):
            handleError(error, context: "Creating primary assistant failed")
            return nil
        }
    }
}
