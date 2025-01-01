import Foundation
import CueOpenAI
import Combine
import Dependencies
import os.log

@MainActor
public final class RealtimeChatViewModel: ObservableObject {
    @Dependency(\.realtimeClient) public var realtimeClient

    private let openAI: OpenAI
    private let toolManager: ToolManager
    private let apiKey: String
    private let model: String = "gpt-4o-mini-realtime-preview-2024-12-17"
    private let logger = Logger(subsystem: "RealtimeVoiceChatViewModel", category: "RealtimeVoiceChatViewModel")

    @Published private(set) var messages: [OpenAI.ChatMessage] = []
    @Published var newMessage: String = ""

    @Published private(set) var deltaMessage: String = ""
    private var deltaMessageItemId: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var chatError: ChatError?
    @Published private(set) var state: VoiceChatState = .idle {
        didSet {
            logger.debug("OpenAIVoiceChatViewModel Voice state change to \(self.state.description)")
            switch state {
            case .error(let message):
                chatError = .sessionError(message)
            default:
                break
            }
        }
    }
    private var handledEventIds: Set<String> = []
    private var cancellables = Set<AnyCancellable>()

    init(apiKey: String) {
        self.apiKey = apiKey
        self.openAI = OpenAI(apiKey: apiKey)
        self.toolManager = ToolManager()

        self.state = realtimeClient.voiceChatState
        setupRealtimeSubscription()
    }

    private func setupRealtimeSubscription() {
        realtimeClient.voiceChatStatePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.state = state
                }
                .store(in: &cancellables)

        realtimeClient.eventsPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] serverEvent in
                    guard let self = self else { return }
                    switch serverEvent {
                    case .error(let errorEvent):
                        self.logger.debug("Received server error: \(errorEvent.error.message)")
                    case .responseAudioTranscriptDelta(let event):
                        if !self.deltaMessageItemId.isEmpty && self.deltaMessageItemId != event.itemId {
                            self.deltaMessage = ""
                        }
                        self.deltaMessageItemId = event.itemId
                        self.deltaMessage += event.delta
                    case .responseOutputItemDone(let itemDoneEvent):
                        if self.handledEventIds.contains(itemDoneEvent.eventId) {
                            return
                        }
                        self.handledEventIds.insert(itemDoneEvent.eventId)
                        Task {
                            await self.handleItemDoneEvent(itemDoneEvent)
                        }
                    default:
                        break
                    }
                }
                .store(in: &cancellables)
    }

    private func handleItemDoneEvent(_ itemDoneEvent: ResponseOutputItemDoneEvent) async {
        switch itemDoneEvent.item.type {
        case .functionCall:
            self.logger.debug("Received itemDoneEvent functionCall: \(String(describing: itemDoneEvent))")
            guard let toolCall = itemDoneEvent.item.asFunctionCall()?.toToolCall() else { return }
            await handleFunctionCall(toolCall: toolCall)
        case .message:
            self.logger.debug("Received itemDoneEvent message: \(String(describing: itemDoneEvent))")
        default:
            break
        }
    }

    public func startSession() async {
        do {
            try await realtimeClient.startSession(apiKey: self.apiKey, model: self.model)
            try await updateSession()
        } catch {
            chatError = .sessionError(String(describing: error))
        }
    }

    private func updateSession() async throws {
        var builder = SessionUpdateBuilder()
        builder.tools = self.toolManager.getTools().map { $0.asDefinition() }
        builder.toolChoice = .auto
        let event = ClientEvent.sessionUpdate(
            ClientEvent.SessionUpdateEvent(type: "session.update", session: builder.build())
        )
        do {
            try await realtimeClient.send(event: event)
        } catch {
            self.logger.error("Update session error: \(error)")
            throw error
        }
    }

    public func endSession() async {
        await realtimeClient.endChat()
    }

    public func pauseChat() {
        realtimeClient.pauseChat()
    }

    public func resumeChat() {
        realtimeClient.resumeChat()
    }

    public func endChat() async {
        await realtimeClient.endChat()
    }

    public func sendMessage() {
        Task {
            await createConversationItem(text: newMessage)
            newMessage = ""
        }
    }

    private func createConversationItem(text: String) async {
        let item = ConversationItem(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            type: .message,
            role: .user,
            content: [
                ContentPart(type: .inputText, text: text)
            ]
        )

        let event = ClientEvent.conversationItemCreate(
            ClientEvent.ConversationItemCreateEvent(
                previousItemId: nil,
                item: item
            )
        )

        do {
            try await realtimeClient.send(event: event)
            try await realtimeClient.createResponse()
        } catch {
            self.logger.error("Send message error: \(error)")
        }
    }

    private func createConversationItemWithOutput(previousItemId: String? = nil, toolMessages: [OpenAI.ToolMessage]) async {
        let toolCallResult = toolMessages[0].getText()
        let toolCallId = toolMessages[0].toolCallId

        let item = ConversationItem(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            type: ItemType.functionCallOutput,
            callId: toolCallId,
            output: toolCallResult
        )

        let event = ClientEvent.conversationItemCreate(
            ClientEvent.ConversationItemCreateEvent(
                previousItemId: previousItemId,
                item: item
            )
        )

        do {
            try await realtimeClient.send(event: event)
            try await realtimeClient.createResponse()
        } catch {
            self.logger.error("Send tool result error: \(error)")
        }
    }

    private func handleFunctionCall(toolCall: ToolCall) async {
        let toolMessages = await callTools([toolCall])
        await createConversationItemWithOutput(toolMessages: toolMessages)
    }

    private func callTools(_ toolCalls: [ToolCall]) async -> [OpenAI.ToolMessage] {
        var results: [OpenAI.ToolMessage] = []

        for toolCall in toolCalls {
            if let data = toolCall.function.arguments.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                do {
                    let result = try await toolManager.callTool(
                        name: toolCall.function.name,
                        arguments: args
                    )
                    results.append(OpenAI.ToolMessage(
                        role: "tool",
                        content: result,
                        toolCallId: toolCall.id
                    ))
                } catch {
                    let toolError = ChatError.toolError(error.localizedDescription)
                    ErrorLogger.log(toolError)
                    results.append(OpenAI.ToolMessage(
                        role: "tool",
                        content: "Error: \(error.localizedDescription)",
                        toolCallId: toolCall.id
                    ))
                }
            }
        }

        return results
    }

    func clearError() {
        chatError = nil
    }
}
