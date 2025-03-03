//
//  AnthropicChatViewModel+RunLoop.swift
//  CueApp
//
import Foundation
import CueAnthropic
import CueCommon

// MARK: - Run Loop
extension AnthropicChatViewModel {
    func runLoop(
        request: CompletionRequest,
        onStreamEvent: @escaping (StreamEvent) async -> Void
    ) async throws -> [CueChatMessage] {
        var currentMessages = Array(request.messages)
        var iteration = 0
        var shouldContinue = true

        while shouldContinue && iteration < request.maxTurns {
            shouldContinue = false

            let messageParams = prepareMessageParams(currentMessages)

            // Create and process stream
            let streamResult = try await executeIteration(
                messageParams: messageParams,
                request: request,
                onStreamEvent: onStreamEvent
            )
            // Process results
            if let assistantMessage = streamResult.finalMessage {
                // Add the assistant message to the conversation
                currentMessages.append(createAssistantChatMessage(assistantMessage, id: streamResult.messageId))

                shouldContinue = await processIterationResults(
                    streamResult: streamResult,
                    currentMessages: &currentMessages,
                    onStreamEvent: onStreamEvent
                )
            }

            if !shouldContinue {
                break
            }

            iteration += 1
        }
        return currentMessages
    }

    /// Execute a single iteration of the conversation loop
    /// - Returns: Whether another iteration should be performed
    private func executeIteration(
        messageParams: [Anthropic.ChatMessageParam],
        request: CompletionRequest,
        onStreamEvent: @escaping (StreamEvent) async -> Void
    ) async throws -> StreamResult {

        let streamProcessor = AnthropicStreamProcessor(
            toolManager: self.toolManager,
            onEvent: onStreamEvent
        )

        let (events, connectionState, cancel) = anthropic.messages.createStream(
            model: request.model,
            maxTokens: request.maxTokens,
            messages: messageParams,
            tools: tools,
            toolChoice: request.toolChoice != nil ? ["type": request.toolChoice!] : nil,
            thinking: request.thinking
        )

        let connectionTask = Task { await monitorConnectionState(connectionState) }

        defer {
            connectionTask.cancel()
        }

        do {
            for try await event in events {
                _ = await streamProcessor.processEvent(event)
            }
        } catch {
            cancel()
            throw error
        }

        var result = StreamResult()
        result.finalMessage = streamProcessor.getFinalMessage()
        result.toolResults = streamProcessor.getToolResults()
        result.messageId = streamProcessor.messageId ?? ""
        result.hasAllToolResults = streamProcessor.hasAllToolResults()
        return result
    }

    /// Creates a chat message from an assistant message
    private func createAssistantChatMessage(
        _ assistantMessage: Anthropic.ChatMessageParam,
        id: String
    ) -> CueChatMessage {
        return .anthropic(
            assistantMessage,
            stableId: id,
            streamingState: nil,
            createdAt: Date()
        )
    }

    /// Process tool uses if there are any
    private func processIterationResults(
        streamResult: StreamResult,
        currentMessages: inout [CueChatMessage],
        onStreamEvent: @escaping (StreamEvent) async -> Void
    ) async -> Bool {
        guard let hasToolCall = streamResult.finalMessage?.hasToolUse else {
            // No tool call, we can stop the conversation
            return false
        }

        // Tool uses with results
        if hasToolCall && streamResult.hasAllToolResults {
            // Add the tool result message to the conversation
            let toolResultMessage = streamResult.createChatResultMessage()
            currentMessages.append(toolResultMessage)

            // Notify about the tool result
            await onStreamEvent(.toolResult(streamResult.messageId, toolResultMessage))

            // Signal that we should continue the conversation
            return true
        } else if !hasToolCall {
            logger.debug("No tool calls in final message, won't continue. messageId: \(streamResult.messageId)")
        } else {
            logger.error("Tool call without corresponding tool result. Cannot continue.")
        }
        return false
    }

    func prepareMessageParams(_ messages: [CueChatMessage]) -> [Anthropic.ChatMessageParam] {
        // First convert all messages to AnthropicChatParam
        let originalParams = messages.compactMap { $0.anthropicChatParam }

        // Create a new array for ordered messages
        var orderedParams: [Anthropic.ChatMessageParam] = []

        // Track tool uses and tool messages
        var pendingToolUseIds = Set<String>()
        var pendingToolMessages: [String: Anthropic.ChatMessageParam] = [:]

        // First pass: Sort user and assistant messages, collect tool-related messages
        for param in originalParams {
            // Special case: For Anthropic, a "user" role might actually be a tool message result
            if param.role == "user" {
                // Check if this is actually a tool message (Anthropic specific)
                if param.isToolMessage {
                    if let toolContent = param.toolMessage?.content.first {
                        let toolUseId = toolContent.toolUseId
                        if pendingToolUseIds.contains(toolUseId) {
                            // If we've already seen the tool use, add tool message now
                            if let index = orderedParams.lastIndex(where: { msg in
                                let toolUses = msg.toolUses
                                if !toolUses.isEmpty {
                                    return toolUses.contains { $0.id == toolUseId }
                                }
                                return false
                            }) {
                                // Insert right after the tool use
                                orderedParams.insert(param, at: index + 1)
                                pendingToolUseIds.remove(toolUseId)
                            }
                        } else {
                            // Save this tool message for when we encounter its tool use
                            pendingToolMessages[toolUseId] = param
                        }
                    }
                } else {
                    // Regular user message
                    orderedParams.append(param)
                }
            } else if param.role == "assistant" {
                let toolUses = param.toolUses
                if !toolUses.isEmpty {
                    // Remember tool use IDs
                    for toolUse in toolUses {
                        pendingToolUseIds.insert(toolUse.id)
                    }

                    // Add assistant message with tool uses
                    orderedParams.append(param)

                    // Immediately add any matching tool messages we've seen
                    for toolUseId in pendingToolUseIds {
                        if let toolMessage = pendingToolMessages[toolUseId] {
                            orderedParams.append(toolMessage)
                            pendingToolMessages.removeValue(forKey: toolUseId)
                        }
                    }
                } else {
                    // Regular assistant message - only add if it's not between a tool use and tool message
                    if !toolUses.isEmpty && !pendingToolUseIds.isEmpty {
                        // Don't add it yet - would interrupt tool flow
                    } else {
                        orderedParams.append(param)
                    }
                }
            } else if param.isToolMessage {

                if let toolContent = param.toolMessage?.content.first {
                    let toolUseId = toolContent.toolUseId
                    if pendingToolUseIds.contains(toolUseId) {
                        // If we've already seen the tool use, add tool message now
                        if let index = orderedParams.lastIndex(where: { msg in
                            let toolUses = msg.toolUses
                            if !toolUses.isEmpty {
                                return toolUses.contains { $0.id == toolUseId }
                            }
                            return false
                        }) {
                            // Insert right after the tool use
                            orderedParams.insert(param, at: index + 1)
                            pendingToolUseIds.remove(toolUseId)
                        }
                    } else {
                        // Save this tool message for when we encounter its tool use
                        pendingToolMessages[toolUseId] = param
                    }
                }
            }
        }

        return orderedParams
    }
}

extension AnthropicChatViewModel {
    /// Monitor the connection state changes
    private func monitorConnectionState(_ connectionState: AsyncStream<ServerStreamingEvent.ConnectionState>) async {
        for await state in connectionState {
            switch state {
            case .connecting:
                logger.debug("Connecting to message stream")
            case .connected:
                logger.debug("Connected to message stream")
            case .disconnected(let error):
                if let error = error {
                    logger.error("Disconnected from message stream with error: \(error.localizedDescription)")
                } else {
                    logger.debug("Disconnected from message stream")
                }
            }
        }
    }
}

extension StreamResult {
    func createChatResultMessage() -> CueChatMessage {
        let toolResult = Anthropic.ToolResultMessage(
            role: "user",
            content: toolResults
        )
        let stableId = self.toolResults.first?.toolUseId ?? "EMPTY_TOOL_USE_ID"
        return CueChatMessage.anthropic(
            .toolMessage(toolResult),
            stableId: "tool_result_\(stableId)",
            streamingState: nil,
            createdAt: Date().addingTimeInterval(0.001)
        )
    }
}
