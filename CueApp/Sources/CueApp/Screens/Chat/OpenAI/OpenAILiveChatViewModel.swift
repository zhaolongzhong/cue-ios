import Foundation
import Combine
import CueCommon
import CueOpenAI
import Dependencies
import os.log

@MainActor
public final class OpenAILiveChatViewModel: BaseChatViewModel {
    @Dependency(\.realtimeClient) public var realtimeClient

    private let openAI: OpenAI
    private let realtimeModel: String = ChatRealtimeModel.gpt4oMiniRealtimePreview.id
    private let logger = Logger(subsystem: "openai", category: "OpenAILiveChatViewModel")

    @Published private(set) var deltaMessage: String = ""
    private var deltaMessageItemId: String = ""
    @Published private(set) var state: VoiceState = .idle {
        didSet {
            logger.debug("Voice state change to \(self.state.description)")
            switch state {
            case .error(let message):
                error = .sessionError(message)
            default:
                break
            }
        }
    }
    private var handledEventIds: Set<String> = []

    init(conversationId: String?, apiKey: String) {
        self.openAI = OpenAI(apiKey: apiKey)
        super.init(
            apiKey: apiKey,
            provider: .openai,
            model: .gpt4oMini,
            conversationId: conversationId,
            richTextFieldState: RichTextFieldState(conversationId: conversationId)
        )

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
            try await realtimeClient.startSession(apiKey: self.apiKey, model: self.realtimeModel)
            try await updateSession()
        } catch {
            self.error = .sessionError(String(describing: error))
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

    override func sendMessage() async {
        await createConversationItem(text: richTextFieldState.inputMessage)
        richTextFieldState = richTextFieldState.copy(inputMessage: "")
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
        let toolMessages = await toolManager.callTools([toolCall])
        await createConversationItemWithOutput(toolMessages: toolMessages)
    }
}
