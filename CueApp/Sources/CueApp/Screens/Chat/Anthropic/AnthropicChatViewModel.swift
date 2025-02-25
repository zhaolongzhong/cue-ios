import os
import Foundation
import Combine
import CueCommon
import CueOpenAI
import CueAnthropic

@MainActor
public final class AnthropicChatViewModel: ObservableObject {
    private let anthropic: Anthropic
    private let toolManager: ToolManager
    private var tools: [JSONValue] = []
    private var cancellables = Set<AnyCancellable>()
    private var streamingTask: Task<Void, Error>?
    private var maxTurns: Int = 10
    private let logger = Logger(subsystem: "Anthropic", category: "AnthropicChatViewModel")

    // Track streaming states by message ID
    private var streamingStates: [String: StreamingState] = [:]

    // Track current conversation ID
    @Published var conversationId: String = UUID().uuidString

    @Published var model: ChatModel = .claude35Sonnet {
        didSet {
            updateTools()
        }
    }
    @Published var cueMessages: [CueChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [Tool] = [] {
        didSet {
            updateTools()
        }
    }
    @Published var error: ChatError?
    @Published var isStreaming = false

    @Published var streamedMessages: [String: String] = [:]
    @Published var streamedMessage: String = ""

    // Track thinking content for each streaming task
    @Published var streamedThinkings: [String: String] = [:]
    @Published var streamedThinking: String = ""
    @Published var currentStreamState: StreamingState? {
        didSet {
            if let newState = currentStreamState, let id = newState.id {
                if let index = cueMessages.firstIndex(where: { $0.id == newState.id }) {
                    let newMessage = CueChatMessage.streamingAnthropicMessage(
                        id: id,
                        streamingState: newState
                    )
                    cueMessages[index] = newMessage

                } else {
                    let newMessage = CueChatMessage.streamingAnthropicMessage(
                        id: id,
                        streamingState: newState
                    )
                    cueMessages.append(newMessage)
                }
            }
        }
    }

    public init(apiKey: String) {
        self.anthropic = Anthropic(apiKey: apiKey)
        self.toolManager = ToolManager(enabledTools: [GmailTool()])
        self.availableTools = toolManager.getTools()
        #if os(macOS)
        setupToolsSubscription()
        #endif
    }

    private func updateTools() {
        tools = self.toolManager.getToolsJSONValue(model: self.model.id)
    }

    private func setupToolsSubscription() {
        toolManager.mcpToolsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.availableTools = self.toolManager.getTools()
            }
            .store(in: &cancellables)
    }

    func startServer() async {
        #if os(macOS)
        await self.toolManager.startMcpServer()
        #endif
    }

    func sendMessage() async {
        let userMessage = Anthropic.ChatMessageParam.userMessage(
            Anthropic.MessageParam(role: "user", content: [Anthropic.ContentBlock(content: newMessage)])
        )
        cueMessages.append(.anthropic(userMessage, stableId: "user_\(UUID().uuidString)"))

        isLoading = true
        isStreaming = true
        conversationId = UUID().uuidString
        resetStreamingState()
        newMessage = ""

        await streamWithAgentLoop()
        isLoading = false
    }

    private func resetStreamingState() {
        streamedMessages.removeAll()
        streamedThinkings.removeAll()
        streamedThinking = ""
    }

    func clearError() {
        error = nil
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isLoading = false
        isStreaming = false
    }
}

// MARK: Stream With Agent Loop
extension AnthropicChatViewModel {
    func streamWithAgentLoop() async {
        AppLog.log.debug("Starting agent loop for streaming conversation: \(self.conversationId)")

        do {
            let agent = AgentLoop(chatClient: anthropic, toolManager: toolManager, model: model.id)
            let completionRequest = CompletionRequest(
                model: model.id,
                maxTokens: 5000,
                tools: tools,
                toolChoice: "auto",
                maxTurns: maxTurns,
                stream: true
            )

            // Store the streaming task so it can be cancelled if needed
            streamingTask = Task {
                let updatedMessages = try await agent.runWithStreaming(
                    with: cueMessages,
                    request: completionRequest,
                    onStreamEvent: { [weak self] event in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }

                            // Process the event based on its type
                            self.handleStreamEvent(event)
                        }
                    }
                )

                let filteredMessages = validateMessageSequence(updatedMessages)
                self.cueMessages = filteredMessages.map { .anthropic($0.anthropic, stableId: $0.id, streamingState: streamingStates[$0.id])}
                self.isStreaming = false
            }

            // Wait for completion or cancellation
            try await streamingTask?.value

        } catch {
            handleError(error)
            isStreaming = false
        }

        isLoading = false
        isStreaming = false
    }

    private func handleStreamEvent(_ event: StreamEvent) {
        switch event {
        case .streamTaskStarted(let id):
            logger.debug("Stream task started: \(id)")
            initializeStreamingStates(id)

        case .streamTaskCompleted(let id):
            logger.debug("Stream task completed: \(id)")
            if var state = streamingStates[id] {
                state.isComplete = true
                state.endTime = Date()
                streamingStates[id] = state
            }

        case .text(let id, let text):
            // Update streaming state
            updateStreamingStateWithText(id, text)

        case .thinking(let id, let thinking):
            updateStreamingStateWithThinking(id, thinking)
        case .thinkingSignature(let id, let isComplete):
            if isComplete == true, var state = streamingStates[id] {
                state.thinkingEndTime = Date()
                streamingStates[id] = state
            }
        default:
            break
        }
    }

    private func initializeStreamingStates(_ id: String) {
        // Initialize streaming state for this ID
        currentStreamState = StreamingState(
            id: id,
            content: "",
            isComplete: false,
            startTime: Date(),
            isStreamingMode: true
        )
        streamingStates[id] = currentStreamState

        // Initialize streaming message content
        streamedMessages[id] = ""
        streamedThinkings[id] = ""
    }

    private func updateStreamingStateWithText(_ id: String, _ text: String) {
        if var state = streamingStates[id] {
            state.content += text
            streamingStates[id] = state
        }

        // Update the streamed content
        streamedMessages[id] = (streamedMessages[id] ?? "") + text
        streamedMessage += text
        if var state = streamingStates[id] {
            state.accumulatedText += text
            if let textBlock = state.contentBlocks.filter({ $0.isText }).first {
                state.contentBlocks[state.contentBlocks.firstIndex(of: textBlock)!] = Anthropic.ContentBlock(content: textBlock.text + text)
            } else {
                state.contentBlocks.append(Anthropic.ContentBlock(content: text))
            }
            streamingStates[id] = state
            currentStreamState = state
        }
    }

    private func updateStreamingStateWithThinking(_ id: String, _ thinking: String) {
        if var state = streamingStates[id] {
            if let contentBlock = state.contentBlocks.filter({ $0.isThinking }).first, case .thinking(let thinkingBlock) = contentBlock {
                state.contentBlocks[state.contentBlocks.firstIndex(of: contentBlock)!] = Anthropic.ContentBlock(thinkingBlock: Anthropic.ThinkingBlock(type: thinkingBlock.type, thinking: thinkingBlock.thinking + thinking, signature: thinkingBlock.signature))
            } else {
                state.contentBlocks.append(Anthropic.ContentBlock(thinkingBlock: Anthropic.ThinkingBlock(type: "thinking", thinking: thinking, signature: "")))
            }
            streamingStates[id] = state
            currentStreamState = state
        }
        streamedThinkings[id] = (streamedThinkings[id] ?? "") + thinking
        streamedThinking += thinking
    }

    // Helper method to validate that tool uses are always followed by tool results
    private func validateMessageSequence(_ messages: [CueChatMessage]) -> [CueChatMessage] {
        var validatedMessages: [CueChatMessage] = []
        var pendingToolUse = false

        for message in messages.filter({ $0.isAnthropic }) {
            switch message.anthropic {
            case .assistantMessage(let param):
                // Check if this message contains tool uses
                for block in param.content {
                    if case .toolUse = block {
                        pendingToolUse = true
                        break
                    }
                }
                validatedMessages.append(message)

            case .toolMessage:
                // This is a tool result message
                if pendingToolUse {
                    pendingToolUse = false
                }
                validatedMessages.append(message)

            default:
                validatedMessages.append(message)
            }
        }

        // If we end with a pending tool use without result, log error
        if pendingToolUse {
            logger.error("Message sequence ends with tool use without corresponding tool result")
        }

        return validatedMessages
    }

    private func handleError(_ error: Error) {
        let chatError: ChatError
        if let anthropicError = error as? Anthropic.Error {
            switch anthropicError {
            case .apiError(let apiError):
                chatError = .apiError(apiError.error.message)
            default:
                chatError = .unknownError(anthropicError.localizedDescription)
            }
        } else {
            chatError = .unknownError(error.localizedDescription)
        }
        self.error = chatError
        ErrorLogger.log(chatError)
    }
}
