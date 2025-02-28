import Foundation
import CueAnthropic

// MARK: Stream With Agent Loop
extension AnthropicChatViewModel {
    func streamWithAgentLoop(_ messageParams: [CueChatMessage]) async {
        AppLog.log.debug("Starting agent loop for streaming conversation: \(String(describing: self.selectedConversationId))")

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

                let filteredMessages = validateMessageSequence(updatedMessages)
                updateChatMessages(with: filteredMessages)
            }

            // Wait for completion or cancellation
            try await streamingTask?.value

        } catch {
            handleError(error)
        }

        isLoading = false
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
            updateStreamingStateWithText(id, text)
        case .thinking(let id, let thinking):
            updateStreamingStateWithThinking(id, thinking)
        case .thinkingSignature(let id, let isComplete):
            if isComplete == true, var state = streamingStates[id] {
                state.thinkingEndTime = Date()
                streamingStates[id] = state
            }
        case .toolCall(let id, let toolUseblocks):
            updateStreamingStateWithToolUseBlocks(id, toolUseblocks)
        case .toolResult(_, let msg):
            addOrUpdateMessage(msg, persistInCache: false)
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

    private func updateStreamingStateWithToolUseBlocks(_ id: String, _ toolUseBlocks: [Anthropic.ToolUseBlock]) {
        if var state = streamingStates[id] {
            let existingToolUseIds = state.contentBlocks.compactMap { block -> String? in
                if case .toolUse(let toolUseBlock) = block {
                    return toolUseBlock.id
                }
                return nil
            }
            let newToolUseBlocks = toolUseBlocks.filter { !existingToolUseIds.contains($0.id) }
            for toolUseBlock in newToolUseBlocks {
                state.contentBlocks.append(.toolUse(toolUseBlock))
            }
            streamingStates[id] = state
            currentStreamState = state
        }
    }

    // Helper method to validate that tool uses are always followed by tool results
    private func validateMessageSequence(_ messages: [CueChatMessage]) -> [CueChatMessage] {
        var validatedMessages: [CueChatMessage] = []
        var pendingToolUse = false

        for message in messages.filter({ $0.isAnthropic }) {
            switch message.anthropic {
            case .assistantMessage(let param, _):
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

// MARK: Run With Streaming
extension AgentLoop where Client == Anthropic {
    func runWithStreaming(
        with messages: [CueChatMessage],
        request: CompletionRequest,
        onStreamEvent: @escaping (StreamEvent) async -> Void
    ) async throws -> [CueChatMessage] {
        var initialMessages = Array(messages)

        var iteration = 0
        var shouldContinue = true
        let maxIterations = request.maxTurns
        let thinking = Anthropic.Thinking(type: "enabled", budgetTokens: 1024)

        while shouldContinue && iteration < maxIterations {
            let currentMessages: [Anthropic.ChatMessageParam]  = initialMessages.map { $0.anthropic }.filter { message in
                switch message {
                case .assistantMessage(let param, _):
                    return !param.content.isEmpty
                default:
                    return true
                }
            }

            shouldContinue = false

            let delegate = createStreamingDelegate(
                onStreamEvent: onStreamEvent
            )

            // Start streaming
            let streamTask = try await chatClient.messages.streamCreate(
                model: request.model,
                maxTokens: request.maxTokens ?? 4096,
                messages: currentMessages,
                tools: request.tools,
                toolChoice: request.toolChoice != nil ? ["type": request.toolChoice!] : nil,
                thinking: thinking,
                delegate: delegate
            )

            // Wait for completion
            try await streamTask.value

            // Wait for any tool calls to complete and ensure tool results are available before continuing
            await delegate.waitForToolResults()

            let toolResultMessage = processIterationResults(
                delegate: delegate,
                messages: &initialMessages,
                shouldContinue: &shouldContinue
            )

            if !shouldContinue {
                break
            }

            if let toolResultMessage = toolResultMessage {
                await onStreamEvent(.toolResult(delegate.messageId, toolResultMessage))
            }

            iteration += 1
        }

        await onStreamEvent(.completed)
        return initialMessages
    }

    private func createStreamingDelegate(
        onStreamEvent: @escaping (StreamEvent) async -> Void
    ) -> AnthropicStreamingDelegate {
        return AnthropicStreamingDelegate(
            toolManager: self.toolManager,
            onEvent: { event in
                switch event {
                case .text(let id, let text):
                    await onStreamEvent(.text(id, text))
                case .thinking(let id, let thinking):
                    await onStreamEvent(.thinking(id, thinking))
                case .thinkingSignature(let id, let isComplete):
                    await onStreamEvent(.thinkingSignature(id, isComplete))
                case .toolCall(let id, let toolUseBlocks):
                    await onStreamEvent(.toolCall(id, toolUseBlocks))
                case .toolResult(let id, let result):
                    await onStreamEvent(.toolResult(id, result))
                case .completed:
                    await onStreamEvent(.completed)
                case .streamTaskStarted(let id):
                    await onStreamEvent(.streamTaskStarted(id))
                case .streamTaskCompleted(let id):
                    await onStreamEvent(.streamTaskCompleted(id))
                }
            },
            onToolCall: { _, toolUseBlock in
                if let toolManager = self.toolManager {
                    let result = await toolManager.handleToolUse(toolUseBlock)
                    return result
                } else {
                    let errorMsg = "No tool manager available to handle tool: \(toolUseBlock.name)"
                    return errorMsg
                }
            }
        )
    }

    private func processIterationResults(
        delegate: AnthropicStreamingDelegate,
        messages: inout [CueChatMessage],
        shouldContinue: inout Bool
    ) -> CueChatMessage? {
        guard let finalMessage = delegate.finalMessage else { return nil }

        logger.debug("Adding final message")

        let hasToolUses = finalMessage.hasToolUse()

        // If message has tool uses, verify we have corresponding tool results
        if hasToolUses && delegate.hasCompleteToolResults() {
            messages.append(.anthropic(finalMessage, stableId: delegate.messageId, streamingState: nil))

            // Add tool results immediately after the message with tool uses
            let toolResult = Anthropic.ToolResultMessage(
                role: "user",
                content: delegate.toolResultContents
            )
            let cueChatMessage = CueChatMessage.anthropic(.toolMessage(toolResult), stableId: "tool_result_\(delegate.messageId.prefix(6))_\(UUID().uuidString.prefix(8))", streamingState: nil)
            messages.append(cueChatMessage)
            shouldContinue = true
            return cueChatMessage
        } else if !hasToolUses {
            // No tool uses, safe to add the message
            messages.append(.anthropic(finalMessage, stableId: delegate.messageId, streamingState: nil))
            shouldContinue = false
        } else {
            // Tool use without results - error case
            logger.error("Tool use without corresponding tool result. Cannot continue.")
            shouldContinue = false
        }
        return nil
    }
}
