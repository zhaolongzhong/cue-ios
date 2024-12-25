import SwiftUI
import Combine
import Dependencies

@MainActor
final class ChatViewModel: ObservableObject {
    @Dependency(\.webSocketService) public var webSocketService
    @Dependency(\.clientStatusService) public var clientStatusService
    @Dependency(\.assistantRepository) private var assistantRepository
    @Dependency(\.messageRepository) private var messageRepository

    @Published private(set) var messageModels: [MessageModel] = []
    @Published private(set) var assistant: Assistant
    @Published private(set) var isLoading = false
    @Published private(set) var currentConnectionState: ConnectionState = .disconnected
    @Published var errorAlert: ErrorAlert?
    @Published var inputMessage: String = ""
    @Published var showAssistantDetails = false

    private var primaryConversation: ConversationModel?
    private var cancellables = Set<AnyCancellable>()
    private var messageSubscription: Task<Void, Never>?

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
        setupConnectionStateSubscription()
        setupMessageHandler()
    }

    deinit {
        messageSubscription?.cancel()
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

    private func subscribeToMessages(conversationId: String) {
        messageSubscription?.cancel()
        messageSubscription = Task {
            for await message in await messageRepository.messageStream(forConversation: conversationId) {
                guard !Task.isCancelled else { break }
                withAnimation {
                    self.messageModels.append(message)
                }
            }
        }
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

        Task {
            do {
                _ = try await messageRepository.saveMessage(messageModel: messageModel)
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
            subscribeToMessages(conversationId: conversationId)
            var messages  = await fetchMessages(conversationId: conversationId)
            messages.sort { $0.createdAt < $1.createdAt }
            self.messageModels = messages
        }
    }

    private func fetchAssistantConversation(id: String) async -> ConversationModel? {
        isLoading = true
        do {
            let conversations = try await assistantRepository.listAssistantConversations(id: id, isPrimary: true, skip: 0, limit: 20)
            isLoading = false
            if conversations.isEmpty {
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
            let conversation = try await assistantRepository.createPrimaryConversation(assistantId: assistant.id, name: nil)
            return conversation
        } catch {
            AppLog.log.error("Error creating assistant: \(error.localizedDescription)")
        }
        return nil
    }

    func fetchMessages(conversationId: String) async -> [MessageModel] {
        do {
            let messages = try await messageRepository.listMessages(conversationId: conversationId, skip: 0, limit: 50)
            return messages
        } catch {
            AppLog.log.error("Error fetching messages: \(error.localizedDescription)")
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
        messageSubscription?.cancel()
    }
}
