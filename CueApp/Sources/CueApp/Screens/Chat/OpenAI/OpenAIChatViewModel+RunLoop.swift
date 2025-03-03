//
//  OpenAIChatViewModel+RunLoop.swift
//  CueApp
//

import Foundation
import CueCommon
import CueOpenAI

// MARK: - Run Loop

extension OpenAIChatViewModel {
    func runLoop(
        request: CompletionRequest,
        onStreamEvent: @escaping (OpenAIStreamEvent) async -> Void
    ) async throws -> [CueChatMessage] {
        var currentMessages = Array(request.messages)
        var iteration = 0
        var shouldContinue = true

        while iteration < request.maxTurns {
            shouldContinue = false

            let messageParams = prepareMessageParams(currentMessages)

            let streamResult = try await executeIteration(
                messageParams: messageParams,
                request: request,
                onStreamEvent: onStreamEvent
            )
            if let assistantMessage = streamResult.finalMessage {
                // Add the assistant message to the conversation
                currentMessages.append(.openAI(assistantMessage, stableId: streamResult.messageId, createdAt: Date()))
            }

            // Process results and determine if we should continue
            shouldContinue = await processIterationResults(
                streamResult: streamResult,
                currentMessages: &currentMessages,
                onStreamEvent: onStreamEvent
            )

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
        messageParams: [OpenAI.ChatMessageParam],
        request: CompletionRequest,
        onStreamEvent: @escaping (OpenAIStreamEvent) async -> Void
    ) async throws -> OpenAIStreamResult {

        // Create stream processor
        let streamProcessor = OpenAIStreamProcessor(
            toolManager: self.toolManager,
            onEvent: onStreamEvent
        )

        let (events, connectionState, cancel) = openai.chat.completions.createStream(
            model: request.model,
            maxTokens: request.maxTokens,
            messages: messageParams,
            tools: request.tools,
            toolChoice: request.toolChoice
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

        var result = OpenAIStreamResult()
        result.messageId = streamProcessor.messageId ?? ""
        result.finalMessage = streamProcessor.getFinalMessage()
        result.toolResults = streamProcessor.getToolResults()
        result.hasAllToolResults = streamProcessor.hasAllToolResults()
        return result
    }

    /// Process all events in the stream
    private func processStreamEvents(
        _ events: AsyncThrowingStream<ServerStreamingEvent, Error>,
        _ streamProcessor: OpenAIStreamProcessor
    ) async throws {
        do {
            for try await event in events {
                _ = await streamProcessor.processEvent(event)
            }
        } catch {
            logger.error("Error processing stream: \(error.localizedDescription)")
            throw error
        }
    }

    /// Process the results of an iteration and update messages
    /// - Returns: Tool result messages that were added
    private func processIterationResults(
        streamResult: OpenAIStreamResult,
        currentMessages: inout [CueChatMessage],
        onStreamEvent: @escaping (OpenAIStreamEvent) async -> Void
    ) async -> Bool {
        guard let hasToolCall = streamResult.finalMessage?.hasToolCall else {
            // No tool call, we can stop the conversation
            return false
        }

        // If there are tool results, add them and indicate we should continue
        if hasToolCall && streamResult.hasAllToolResults {
            // Add the tool result message to the conversation
            let toolResult = streamResult.createChatResultMessage()
            currentMessages.append(contentsOf: toolResult)

            // Notify about the tool result
            for msg in toolResult {
                await onStreamEvent(.toolResult(streamResult.messageId, msg))
            }
            return true
        } else if !hasToolCall {
            logger.debug("No tool calls in final message, won't continue. messageId: \(streamResult.messageId)")
        } else {
            logger.error("Tool call without corresponding tool result. Cannot continue.")
        }

        return false
    }

    func prepareMessageParams(_ messages: [CueChatMessage]) -> [OpenAI.ChatMessageParam] {
        // First convert all messages to OpenAIChatParam
        let originalParams = messages.compactMap { $0.openAIChatParam }

        // Create a new array for ordered messages
        var orderedParams: [OpenAI.ChatMessageParam] = []

        // Track tool calls and tool messages
        var pendingToolCallIds = Set<String>()
        var pendingToolMessages: [String: OpenAI.ChatMessageParam] = [:]

        // First pass: Sort user and assistant messages, collect tool-related messages
        for param in originalParams {
            if param.role == "user" {
                // Always include user messages
                orderedParams.append(param)
            } else if param.role == "assistant" {
                if param.hasToolCall {
                    // Remember tool call IDs
                    for toolCall in param.toolCalls {
                        pendingToolCallIds.insert(toolCall.id)
                    }

                    // Add assistant message with tool calls
                    orderedParams.append(param)

                    // Immediately add any matching tool messages we've seen
                    for toolCallId in pendingToolCallIds {
                        if let toolMessage = pendingToolMessages[toolCallId] {
                            orderedParams.append(toolMessage)
                            pendingToolMessages.removeValue(forKey: toolCallId)
                        }
                    }
                } else {
                    // Regular assistant message - only add if it's not between a tool call and tool message
                    if let lastMessage = orderedParams.last,
                       lastMessage.hasToolCall && !pendingToolCallIds.isEmpty {
                        // Don't add it yet - will be added at end or in a different position
                    } else {
                        orderedParams.append(param)
                    }
                }
            } else if param.role == "tool" {
                if let toolCallId = param.toolMessage?.toolCallId {
                    if pendingToolCallIds.contains(toolCallId) {
                        // If we've already seen the tool call, add tool message now
                        if let index = orderedParams.lastIndex(where: { msg in
                            if msg.hasToolCall {
                                return msg.toolCalls.contains { $0.id == toolCallId }
                            }
                            return false
                        }) {
                            // Insert right after the tool call
                            orderedParams.insert(param, at: index + 1)
                            pendingToolCallIds.remove(toolCallId)
                        }
                    } else {
                        // Save this tool message for when we encounter its tool call
                        pendingToolMessages[toolCallId] = param
                    }
                }
            }
        }

        return orderedParams
    }
}

extension OpenAIChatViewModel {
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

struct OpenAIStreamResult {
    var messageId: String = ""
    var finalMessage: OpenAI.ChatMessageParam?
    var toolResults: [OpenAI.ToolMessage] = []
    var hasAllToolResults: Bool = true
}

extension OpenAIStreamResult {
    func createChatResultMessage() -> [CueChatMessage] {
        var toolResults: [CueChatMessage] = []
        for toolMessage in self.toolResults {
            let cueChatMessage = CueChatMessage.openAI(
                .toolMessage(toolMessage),
                stableId: "tool_result_\(toolMessage.toolCallId)",
                createdAt: Date().addingTimeInterval(TimeInterval(0.001))
            )
            toolResults.append(cueChatMessage)
        }

        return toolResults
    }
}
