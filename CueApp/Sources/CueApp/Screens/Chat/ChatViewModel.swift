import SwiftUI
import Combine
import Dependencies

@MainActor
final class ChatViewModel: ObservableObject {
    @Dependency(\.webSocketService) public var webSocketService
    @Dependency(\.clientStatusService) public var clientStatusService
    @Dependency(\.assistantService) public var assistantService

    @Published private(set) var messageModels: [MessageModel] = []
    @Published private(set) var assistant: Assistant
    @Published private(set) var isLoading = false
    @Published private(set) var currentConnectionState: ConnectionState = .disconnected
    @Published var errorAlert: ErrorAlert?
    @Published var inputMessage: String = ""
    @Published var showAssistantDetails = false

    private let messageModelStore: MessageModelStore
    private var primaryConversation: ConversationModel?
    private var cancellables = Set<AnyCancellable>()

    var isInputEnabled: Bool {
         switch currentConnectionState {
         case .connected:
             return true
         case .disconnected, .connecting, .error:
             return false
         }
     }

    init(assistant: Assistant) {
        self.assistant = assistant

        do {
            self.messageModelStore = try MessageModelStore()
        } catch {
            AppLog.websocket.error("Database initialization failed: \(error)")
            self.messageModelStore = try! MessageModelStore()
        }

        setupConnectionStateSubscription()
        setupMessageHandler()
    }

    private func setupConnectionStateSubscription() {
        webSocketService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.currentConnectionState = state
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

    private func processMessagePayload(_ messagePayload: MessagePayload) {
        guard let conversationId = self.primaryConversation?.id else {
            AppLog.log.error("Error in processMessagePayload conversationId is nil")
            return
        }

        let messageModel = MessageModel(
            from: messagePayload,
            conversationId: conversationId
        )

        withAnimation {
            messageModels.append(messageModel)
        }

        Task {
            do {
                try await messageModelStore.save(messageModel)
            } catch {
                handleError(error, context: "Saving received message")
            }
        }
    }

    // MARK: - Setup
    func setupChat() async {
        isLoading = true
        defer { isLoading = false }

        self.primaryConversation = await fetchAssistantConversation(id: assistant.id)

        if let conversationId = primaryConversation?.id {
            _ = await loadMessagesFromDb(conversationId: conversationId)
            let messages = await fetchMessages(conversationId: conversationId)

            if messages.count > 0 {
                for message in messages {
                    do {
                        try await messageModelStore.save(message)
                    } catch {
                        AppLog.log.error("Database error: \(error)")
                    }
                }
                _ = await loadMessagesFromDb(conversationId: conversationId)
            }
        }
    }

    private func loadMessagesFromDb(conversationId: String) async -> [MessageModel] {
        do {
            let messages = try await messageModelStore.fetchAllMessages(forConversation: conversationId)
            AppLog.log.debug("Fetch messsages from database, conversation id:\(conversationId), messages count: \(messages.count)")
            self.messageModels = messages
            return messages
        } catch {
            handleError(error, context: "Loading messages")
        }

        return []
    }

    private func fetchAssistantConversation(id: String) async -> ConversationModel? {
        isLoading = true
        do {
            let conversations = try await assistantService.listAssistantConversations(id: id, isPrimary: true, skip: 0, limit: 20)
            isLoading = false
            if conversations.count == 0 {
                let conversation = await createPrimaryAssistant()
                return conversation
            } else {
                return conversations[0]
            }

        } catch {
            AppLog.log.error("Error fetching assistants: \(error.localizedDescription)")
        }
        return nil
    }

    func createPrimaryAssistant() async -> ConversationModel? {
        do {
            let conversation = try await assistantService.createPrimaryConversation(assistantId: assistant.id)
            return conversation
        } catch {
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
        return nil
    }

    func fetchMessages(conversationId: String) async -> [MessageModel] {
        do {
            let messages = try await assistantService.listMessages(conversationId: conversationId)
            return messages
        } catch {
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
        return []
    }

    // MARK: - Message Handling
    func handleSendMessage() {
        Task {
            do {
                try await sendMessage()
                inputMessage = ""
            } catch {
                handleError(error, context: "Sending message")
            }
        }
    }

    private func sendMessage() async throws {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let messageToSend = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = Message(
            assistantId: assistant.id,
            content: messageToSend,
            isFromUser: true
        )

        let clientStatus = clientStatusService.getClientStatus(for: assistant.id)

        guard let runnerId = clientStatus?.runnerId else {
            AppLog.log.error("Client status is nil")
            return
        }

        let uuid = UUID().uuidString

        let messagePayload = MessagePayload(
            message: messageToSend,
            sender: nil,
            recipient: runnerId,
            websocketRequestId: uuid,
            metadata: nil,
            userId: nil,
            payload: nil
        )

        let clientEvent = ClientEvent(
            type: .user,
            payload: .message(messagePayload),
            clientId: EnvironmentConfig.shared.clientId,
            metadata: nil,
            websocketRequestId: uuid
        )
        webSocketService.send(event: clientEvent)
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

    }
}
