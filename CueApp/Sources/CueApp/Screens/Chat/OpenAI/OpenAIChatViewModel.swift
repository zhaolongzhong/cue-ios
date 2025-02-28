//
//  OpenAIChatViewModel.swift
//  CueApp
//

import os.log
import Foundation
import CueCommon
import CueOpenAI

@MainActor
public final class OpenAIChatViewModel: BaseChatViewModel, ChatViewModel {
    private let openAI: OpenAI

    private var streamingTask: Task<Void, Error>?
    private var streamingStates: [String: StreamingState] = [:]
    private var currentStreamState: StreamingState? {
        didSet {
            if let newState = currentStreamState, let id = newState.id {
                let newMessage = CueChatMessage.streamingOpenAIMessage(
                    id: id,
                    streamingState: newState
                )
                addOrUpdateMessage(newMessage, persistInCache: false)
            }
        }
    }
    let logger = Logger(subsystem: "OpenAI", category: "OpenAIChatViewModel")
    private var enableStreaming: Bool = true

    public init(apiKey: String, conversationId: String? = nil) {
        self.openAI = OpenAI(apiKey: apiKey)
        super.init(
            apiKey: apiKey,
            provider: .openai,
            model: .gpt4oMini,
            conversationId: conversationId
        )
    }

    func updateChatMessages(with updatedMessages: [CueChatMessage]) {
        for updatedMessage in updatedMessages {
            let newChatMessage = CueChatMessage.openAI(
                updatedMessage.openAIChatParam!,
                stableId: updatedMessage.id,
                streamingState: streamingStates[updatedMessage.id]
            )
            addOrUpdateMessage(newChatMessage, persistInCache: true)
        }
    }

    override func sendMessage() async {
        let (userMessage, _) = await prepareOpenAIMessage()

        // Add user message to chat
        let cueChatMessage = CueChatMessage.openAI(userMessage, stableId: UUID().uuidString)
        addOrUpdateMessage(cueChatMessage, persistInCache: true)

        // Get recent messages
        let messageParams = Array(self.cueChatMessages.suffix(maxMessages))

        isLoading = true
        newMessage = ""

        if isStreamingEnabled {
            await streamWithAgentLoop(messageParams)
        } else {
            await sendMessageWithoutStreaming(messageParams)
        }
    }

    private func sendMessageWithoutStreaming(_ messageParams: [CueChatMessage]) async {
        do {
            let agent = AgentLoop(chatClient: openAI, toolManager: toolManager, model: model.id)
            let completionRequest = CompletionRequest(model: model.id, tools: tools, toolChoice: "auto")
            let openAIParams = messageParams.compactMap { $0.openAIChatParam }
            let updatedMessages = try await agent.run(with: openAIParams, request: completionRequest)
            for message in updatedMessages {
                let cueChatMessage = CueChatMessage.openAI(message, stableId: UUID().uuidString)
                addOrUpdateMessage(cueChatMessage, persistInCache: true)
            }
        } catch {
            let chatError = ChatError.unknownError(error.localizedDescription)
            self.error = chatError
            ErrorLogger.log(chatError)
        }
        isLoading = false
    }
}

// MARK: Stream With Agent Loop

extension OpenAIChatViewModel {

    func streamWithAgentLoop(_ messageParams: [CueChatMessage]) async {
        AppLog.log.debug("Starting agent loop for streaming conversation: \(String(describing: self.selectedConversationId))")

        do {
            let agent = AgentLoop(chatClient: openAI, toolManager: toolManager, model: model.id)
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
                let updatedMessages = try await agent.runWithStreamingOpenAI(
                    with: messageParams,
                    request: completionRequest,
                    onStreamEvent: { [weak self] event in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }

                            // Process the event based on its type
                            self.handleStreamEvent(event)
                        }
                    }
                )

                // Update chat messages with final results
                updateChatMessages(with: updatedMessages)
            }

            // Wait for completion or cancellation
            try await streamingTask?.value

        } catch {
            handleError(error)
        }

        isLoading = false
    }

    private func handleStreamEvent(_ event: OpenAIStreamEvent) {
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
            updateStreamingStateWithText(id, text)

        case .toolCall(let id, let toolCalls):
            updateStreamingStateWithToolCalls(id, toolCalls)

        case .toolResult(_, let msg):
            addOrUpdateMessage(msg, persistInCache: false)

        case .completed:
            logger.debug("Streaming completed")
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
    }

    private func updateStreamingStateWithText(_ id: String, _ text: String) {
        if var state = streamingStates[id] {
            state.content += text
            streamingStates[id] = state
            updateUI(state)
        }
    }

    private func updateStreamingStateWithToolCalls(_ id: String, _ toolCalls: [ToolCall]) {
        if var state = streamingStates[id] {
            state.toolCalls = toolCalls

            // Replace the state in our dictionary
            streamingStates[id] = state
            updateUI(state)
        }
    }

    private func updateUI(_ state: StreamingState) {
        currentStreamState = state
    }

    private func handleError(_ error: Error) {
        let chatError: ChatError
        if let openAIError = error as? OpenAI.Error {
            switch openAIError {
            case .apiError(let apiError):
                chatError = .apiError(apiError.error.message)
            default:
                chatError = .unknownError(openAIError.localizedDescription)
            }
        } else {
            chatError = .unknownError(error.localizedDescription)
        }
        self.error = chatError
        ErrorLogger.log(chatError)
    }
}
