import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published private(set) var messageModels: [MessageModel] = []
    @Published private(set) var isLoading = false
    @Published var errorAlert: ErrorAlert?
    @Published var inputMessage: String = ""

    let assistant: AssistantStatus
    private let status: ClientStatus?
    private let webSocketStore: WebSocketManagerStore
    private let messageModelStore: MessageModelStore
    private let assistantService: AssistantService
    private var defaultConversation: ConversationModel?

    init(assistant: AssistantStatus,
         status: ClientStatus?,
         webSocketStore: WebSocketManagerStore) {
        self.assistantService = AssistantService()
        self.assistant = assistant
        self.status = status
        self.webSocketStore = webSocketStore

        do {
            self.messageModelStore = try MessageModelStore()
        } catch {
            AppLog.websocket.error("Database initialization failed: \(error)")
            self.messageModelStore = try! MessageModelStore()
        }

    }

    var isInputEnabled: Bool {
        webSocketStore.connectionState == .connected && !isLoading
    }

    // MARK: - Setup
    func setupChat() async {
        isLoading = true
        defer { isLoading = false }

        self.defaultConversation = await fetchAssistantConversation(id: assistant.id)

        if let conversationId = defaultConversation?.id {
            self.messageModels = await loadMessagesFromDb(conversationId: conversationId)
//            let messages = await fetchMessages(conversationId: conversationId)
//
//            if messages.count > 0 {
//                do {
//                    for message in messages {
//                        AppLog.log.debug("\(String(describing: message.id)): \(message.author.role) - \(message.content.getText())")
//                        try messageModelStore.save(message)
//                    }
//                } catch {
//                    print("Database error: \(error)")
//                }
//            }
            do {
                // Fetch all messages in a conversation
                self.messageModels = await loadMessagesFromDb(conversationId: conversationId)
            } catch {
                print("Database error: \(error)")
            }
            AppLog.log.debug("messages(\(self.defaultConversation!.id)) \(self.messageModels.count)")
        }
        setupMessageHandler()
    }

    private func loadMessagesFromDb(conversationId: String) async -> [MessageModel] {
        do {
            let messages = try messageModelStore.fetchAllMessages(forConversation: conversationId)
            AppLog.log.debug("Fetch messsages from database, conversation id:\(conversationId), messages count: \(messages.count)")
//            for message in messages {
//                AppLog.log.debug("Message: \(String(describing: message.id)): \(message.author.role) - \(message.content.content.getText())")
//            }
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
            AppLog.log.debug("fetch conversation for assistant(\(id)): \(conversations.count)")
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

    private func setupMessageHandler() {
        webSocketStore.addMessageHandler { [weak self] messagePayload in
            guard let self = self else { return }

            guard let conversationId = self.defaultConversation?.id else {
                AppLog.log.error("Error in setupMessageHandler conversationId is nil")
                return
            }

            let messageModel = MessageModel(
                from: messagePayload,
                conversationId: conversationId
            )
            withAnimation {
                self.messageModels.append(messageModel)
            }

            Task {
                do {
                    try self.messageModelStore.save(messageModel)

                } catch {
                    self.handleError(error, context: "Saving received message")
                }
            }
        }
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
        guard let assistantId = status?.assistantId else {
            AppLog.log.error("Assistant id is nil")
            return
        }

        let messageToSend = inputMessage
        _ = Message(
            assistantId: assistantId,
            content: messageToSend,
            isFromUser: true
        )

        webSocketStore.send(
            message: messageToSend,
            recipient: status?.runnerId ?? "default_assistant_id"
        )
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
        webSocketStore.removeMessageHandler()
    }
}
