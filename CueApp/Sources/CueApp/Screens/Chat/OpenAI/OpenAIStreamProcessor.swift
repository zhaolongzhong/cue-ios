//
//  OpenAIStreamProcessor.swift
//  CueApp
//

import Foundation
import CueCommon
import CueOpenAI
import os.log

// Stream event types
public enum OpenAIStreamEvent {
    case streamTaskStarted(String)
    case streamTaskCompleted(String)
    case text(String, String)  // id, text content
    case toolCall(String, [ToolCall])  // id, tool calls
    case toolResult(String, CueChatMessage)  // id, tool result message
    case completed(String)
}

/// A class that processes OpenAI stream chunks and builds up the message state
@MainActor
class OpenAIStreamProcessor {
    private let toolManager: ToolManager
    private let logger = Logger(subsystem: "OpenAI", category: "StreamProcessor")

    // Message state
    var messageId: String?
    private var messageModel: String?
    private var currentContent: String = ""
    private var toolCalls: [ToolCall] = []
    private var pendingToolCalls: [Int: ToolCall] = [:] // Track tool calls by index
    private var toolResults: [String: OpenAI.ToolMessage] = [:]
    private var isComplete: Bool = false
    private var finishReason: String?

    // Stream event handler
    private let onEvent: (OpenAIStreamEvent) async -> Void

    init(toolManager: ToolManager, onEvent: @escaping (OpenAIStreamEvent) async -> Void) {
        self.toolManager = toolManager
        self.onEvent = onEvent
        reset()
    }

    /// Reset the processor state
    func reset() {
        messageId = nil
        messageModel = nil
        currentContent = ""
        toolCalls = []
        pendingToolCalls = [:]
        toolResults = [:]
        isComplete = false
        finishReason = nil
    }

    /// Process a stream event from OpenAI
    /// - Parameter event: The event to process
    /// - Returns: True if the message is complete
    func processEvent(_ event: ServerStreamingEvent) async -> Bool {
        switch event {
        case .chunk(let chunk):
            await processChunk(chunk)
            return isComplete

        case .error(let errorEvent):
            logger.error("Error in stream: \(errorEvent.error.localizedDescription)")
            return true // Consider complete on error

        case .completed:
            isComplete = true
            if let messageId = messageId {
                await onEvent(.completed(messageId))
            }
            return true
        }
    }

    /// Process a chat completion chunk
    /// - Parameter chunk: The chunk to process
    private func processChunk(_ chunk: OpenAI.ChatCompletionChunk) async {
        // Initialize message ID and model if needed
        await initializeMessageIfNeeded(chunk)

        for choice in chunk.choices {
            await processChoiceContent(choice)
            if let reason = choice.finishReason {
                await handleFinishReason(reason)
            }
        }
    }

    /// Initialize message ID and model if not already set
    /// - Parameter chunk: The chunk containing message info
    private func initializeMessageIfNeeded(_ chunk: OpenAI.ChatCompletionChunk) async {
        if messageId == nil {
            messageId = chunk.id
            messageModel = chunk.model

            // Emit stream started event
            if let id = messageId {
                logger.debug("Stream task started: \(id)")
                await onEvent(.streamTaskStarted(id))
            }
        }
    }

    /// Process the content of a choice from a chunk
    /// - Parameter choice: The choice to process
    private func processChoiceContent(_ choice: OpenAI.ChunkChoice) async {
        // Handle role (typically only in the first chunk)
        if let role = choice.delta.role, !role.isEmpty {
            // Role is typically just "assistant" - no need to do anything special
        }

        // Handle content delta
        if let content = choice.delta.content, !content.isEmpty {
            currentContent += content
            if let id = messageId {
                await onEvent(.text(id, content))
            }
        }

        // Handle tool calls
        if let deltaToolCalls = choice.delta.toolCalls, !deltaToolCalls.isEmpty {
            processToolCallDeltas(deltaToolCalls)

            // Only emit tool call events for complete tools
            if !toolCalls.isEmpty, let id = messageId {
                await onEvent(.toolCall(id, toolCalls))
            }
        }
    }

    /// Handle the finish reason from a choice
    /// - Parameter reason: The finish reason
    private func handleFinishReason(_ reason: String) async {
        finishReason = reason
        isComplete = true

        // Convert any pending tool calls to final tool calls
        finalizePendingToolCalls()

        if let id = messageId {
            await onEvent(.streamTaskCompleted(id))

            // If we finished because of tool calls, process them
            if reason == "tool_calls" {
                await processToolCalls()
            }
        }
    }

    /// Process tool call deltas and update the tool calls state
    /// - Parameter deltas: The tool call deltas to process
    private func processToolCallDeltas(_ deltas: [OpenAI.ToolCallDelta]) {
        for delta in deltas {
            let index = delta.index

            // Get or create a pending tool call for this index
            if pendingToolCalls[index] == nil {
                // If this is the first chunk with the ID, create a new tool call
                if let id = delta.id {
                    let function = Function(
                        name: delta.function?.name ?? "",
                        arguments: delta.function?.arguments ?? ""
                    )
                    let newCall = ToolCall(
                        id: id,
                        type: delta.type ?? "function",
                        function: function
                    )
                    pendingToolCalls[index] = newCall

                    // If this is a complete tool call, add it to the final list
                    if !newCall.function.name.isEmpty {
                        toolCalls.append(newCall)
                    }
                }
            } else {
                // Get the existing pending tool call
                let pendingCall = pendingToolCalls[index]!

                // Since Function has immutable properties, create a new Function with updated values
                let updatedFunctionName = delta.function?.name != nil ?
                    pendingCall.function.name + (delta.function?.name ?? "") :
                    pendingCall.function.name

                let updatedArguments = delta.function?.arguments != nil ?
                    pendingCall.function.arguments + (delta.function?.arguments ?? "") :
                    pendingCall.function.arguments

                // Create a new Function with the updated values
                let updatedFunction = Function(
                    name: updatedFunctionName,
                    arguments: updatedArguments
                )

                // Create a new ToolCall with the updated function
                let updatedCall = ToolCall(
                    id: pendingCall.id,
                    type: pendingCall.type,
                    function: updatedFunction
                )

                // Update the pending call
                pendingToolCalls[index] = updatedCall

                // Find and update in the toolCalls array if it exists
                if let finalIndex = toolCalls.firstIndex(where: { $0.id == updatedCall.id }) {
                    toolCalls[finalIndex] = updatedCall
                } else if !updatedCall.function.name.isEmpty {
                    // Add to toolCalls if name is now complete
                    toolCalls.append(updatedCall)
                }
            }
        }
    }

    /// Finalize any pending tool calls
    private func finalizePendingToolCalls() {
        // Make sure all pending tool calls are in the final list
        for (_, pendingCall) in pendingToolCalls {
            if !toolCalls.contains(where: { $0.id == pendingCall.id }) && !pendingCall.function.name.isEmpty {
                toolCalls.append(pendingCall)
            }
        }
    }

    /// Process tool calls with the tool manager
    private func processToolCalls() async {
        guard !toolCalls.isEmpty else { return }

        logger.debug("Processing \(self.toolCalls.count) tool calls")

        let results = await toolManager.handleToolCall(toolCalls)

        for result in results {
            toolResults[result.toolCallId] = result

            // Create a chat message from the tool result
            let cueChatMessage = CueChatMessage.openAI(
                .toolMessage(result),
                stableId: "tool_result_\(result.toolCallId)",
                createdAt: Date().addingTimeInterval(TimeInterval(0.001))
            )

            // Emit tool result event
            if let id = messageId {
                await onEvent(.toolResult(id, cueChatMessage))
            }
        }
    }

    /// Get the final message
    /// - Returns: The final message or nil if not complete
    func getFinalMessage() -> OpenAI.ChatMessageParam? {
        guard isComplete else { return nil }

        // Create an assistant message with the current content and tool calls
        return OpenAI.ChatMessageParam.assistantMessage(
            .init(
                role: "assistant",
                content: currentContent,
                toolCalls: !toolCalls.isEmpty ? toolCalls : nil
            )
        )
    }

    /// Get all accumulated tool results
    /// - Returns: An array of tool messages
    func getToolResults() -> [OpenAI.ToolMessage] {
        return Array(toolResults.values)
    }

    /// Check if all tool calls have been processed
    /// - Returns: True if all tool calls have results
    func hasAllToolResults() -> Bool {
        guard !toolCalls.isEmpty else { return true }
        return toolCalls.allSatisfy { call in toolResults[call.id] != nil }
    }

    /// Check if the message has tool calls
    /// - Returns: True if the message has tool calls
    func hasToolCalls() -> Bool {
        return !toolCalls.isEmpty
    }
}
