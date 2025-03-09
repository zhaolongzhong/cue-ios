//
//  OpenAIChatViewModel.swift
//  CueApp
//

import os.log
import Foundation
import CueCommon
import CueOpenAI

@MainActor
public final class OpenAIChatViewModel: BaseChatViewModel {
    let openai: OpenAI

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

    public init(conversationId: String?, apiKey: String) {
        self.openai = OpenAI(apiKey: apiKey)
        super.init(
            apiKey: apiKey,
            provider: .openai,
            model: .gpt4oMini,
            conversationId: conversationId,
            richTextFieldState: RichTextFieldState(conversationId: conversationId, showVoiceChat: true, showAXApp: true)
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
        print("inx openaichatview model sendNewMessage")
        let (userMessage, _) = await prepareOpenAIMessage()

        // Add user message to chat
        let cueChatMessage = CueChatMessage.openAI(userMessage, stableId: UUID().uuidString)
        addOrUpdateMessage(cueChatMessage, persistInCache: true)

        // Get updated message list including the newly added message
        let messageParams = Array(self.cueChatMessages.suffix(maxMessages))

        isLoading = true
        isRunning = true
        richTextFieldState = richTextFieldState.copy(inputMessage: "")

        if isStreamingEnabled {
            await startStreamingTask(messageParams)
        } else {
            await sendMessageWithoutStreaming(messageParams)
        }
    }

    override func stopAction() async {
        streamingTask?.cancel()
        streamingTask = nil
        isRunning = false
        isLoading = false
    }

    private func sendMessageWithoutStreaming(_ messageParams: [CueChatMessage]) async {
        do {
            let agent = AgentLoop(chatClient: openai, toolManager: toolManager, model: model.id)
            let completionRequest = CompletionRequest(model: model.id, tools: tools, toolChoice: "auto")
            let openAIParams = messageParams.compactMap { $0.openAIChatParam }
            let updatedMessages = try await agent.run(with: openAIParams, request: completionRequest)
            for message in updatedMessages {
                let cueChatMessage = CueChatMessage.openAI(message, stableId: UUID().uuidString)
                addOrUpdateMessage(cueChatMessage, persistInCache: true)
            }
            isRunning = false
        } catch {
            let chatError = ChatError.unknownError(error.localizedDescription)
            self.error = chatError
            ErrorLogger.log(chatError)
        }
    }
}

// MARK: Start Streaming Task

extension OpenAIChatViewModel {

    func startStreamingTask(_ messageParams: [CueChatMessage]) async {
        AppLog.log.debug("Starting agent loop for streaming conversation: \(String(describing: self.selectedConversationId))")

        do {
            let completionRequest = CompletionRequest(
                model: model.id,
                messages: messageParams,
                maxTokens: 5000,
                tools: tools,
                toolChoice: "auto",
                maxTurns: maxTurns,
                stream: true
            )

            streamingTask = Task {
                let updatedMessages = try await runLoop(
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
                isRunning = false
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
            initializeStreamingStates(id)

        case .streamTaskCompleted(let id):
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

        case .completed(let id):
            if var state = streamingStates[id] {
                state.isComplete = true
                state.endTime = Date()
                streamingStates[id] = state
            }
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
        self.isRunning = false
    }
}
