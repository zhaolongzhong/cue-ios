import Foundation
import CueCommon
import CueAnthropic
import os.log

/// A class that processes Anthropic stream chunks and builds up the message state
@MainActor
class AnthropicStreamProcessor {
    let toolManager: ToolManager
    let logger = Logger(subsystem: "Anthropic", category: "StreamProcessor")

    // Message state
    var messageId: String?
    private var messageModel: String?
    private var contentBlocks: [Anthropic.ContentBlock] = []
    private var pendingToolCalls: [Int: PendingToolCall] = [:]  // Track by index
    private var toolResults: [String: Anthropic.ToolResultContent] = [:]
    private var isComplete: Bool = false
    private var finishReason: String?

    // Content tracking
    private var pendingBlocks: [Int: Anthropic.ContentBlock] = [:]
    private var currentText: String = ""
    private var thinkingBlocks: [Int: ThinkingBlock] = [:]

    // Stream event handler
    private let onEvent: (StreamEvent) async -> Void

    init(toolManager: ToolManager, onEvent: @escaping (StreamEvent) async -> Void) {
        self.toolManager = toolManager
        self.onEvent = onEvent
        reset()
    }

    /// Reset the processor state
    func reset() {
        messageId = nil
        messageModel = nil
        contentBlocks = []
        pendingToolCalls = [:]
        toolResults = [:]
        pendingBlocks = [:]
        currentText = ""
        thinkingBlocks = [:]
        isComplete = false
        finishReason = nil
    }

    /// Process a stream event from Anthropic
    /// - Parameter event: The event to process
    /// - Returns: True if the message is complete
    func processEvent(_ event: ServerStreamingEvent) async -> Bool {
        switch event {
        case .messageStart(let event):
            await handleMessageStart(event)
            return false

        case .contentBlockStart(let event):
            await handleContentBlockStart(event)
            return false

        case .contentBlockDelta(let event):
            await handleContentBlockDelta(event)
            return false

        case .contentBlockStop(let event):
            await handleContentBlockStop(event)
            return false

        case .messageDelta(let event):
            handleMessageDelta(event)
            return false

        case .messageStop(let event):
            await handleMessageStop(event)
            return true

        case .error(let event):
            logger.error("Error in stream: \(event.error.message)")
            return true

        case .ping:
            return false
        }
    }

    // MARK: - Event Handlers

    /// Handle message start event
    private func handleMessageStart(_ event: ServerStreamingEvent.MessageStartEvent) async {
        messageId = event.message.id
        messageModel = event.message.model

        // Emit stream started event
        if let id = messageId {
            await onEvent(.streamTaskStarted(id))
        }
    }

    /// Handle content block start event
    private func handleContentBlockStart(_ event: ServerStreamingEvent.ContentBlockStartEvent) async {
        switch event.contentBlock {
        case .text(let textBlock):
            // Store the initial text block
            pendingBlocks[event.index] = .text(textBlock)

            // Emit text event if there's initial text
            if !textBlock.text.isEmpty, let id = messageId {
                currentText += textBlock.text
                await onEvent(.text(id, textBlock.text))
            }

        case .thinking(let thinkingBlock):
            // Store the initial thinking block
            thinkingBlocks[event.index] = ThinkingBlock(
                index: event.index,
                content: thinkingBlock.thinking,
                signature: thinkingBlock.signature
            )

            // Emit thinking event if there's initial thinking
            if !thinkingBlock.thinking.isEmpty, let id = messageId {
                await onEvent(.thinking(id, thinkingBlock.thinking))
            }

        case .toolUse(let toolUseBlock):
            // Create pending tool call
            let pendingCall = PendingToolCall(
                index: event.index,
                jsonInput: "",
                name: toolUseBlock.name,
                id: toolUseBlock.id
            )

            // Store the pending tool call
            pendingToolCalls[event.index] = pendingCall

            // Store the block
            pendingBlocks[event.index] = .toolUse(toolUseBlock)

        default:
            // Store the block as-is
            pendingBlocks[event.index] = event.contentBlock
        }
    }

    /// Handle content block delta event
    private func handleContentBlockDelta(_ event: ServerStreamingEvent.ContentBlockDeltaEvent) async {
        guard let id = messageId else {
            return
        }
        switch event.delta {
        case .text(let delta):
            await updateTextDelta(id, index: event.index, delta: delta)
        case .thinking(let delta):
            await updateThinkingDelta(id, index: event.index, delta: delta)
        case .inputJson(let delta):
            if var pendingCall = pendingToolCalls[event.index] {
                pendingCall.jsonInput += delta.partialJson
                pendingToolCalls[event.index] = pendingCall
            }
        case .signature(let delta):
            if var thinkingBlock = thinkingBlocks[event.index] {
                thinkingBlock.signature = delta.signature
                thinkingBlocks[event.index] = thinkingBlock
                await onEvent(.thinkingSignature(id, false))
            }
        case .toolUse:
            let toolUseBlocks = contentBlocks.compactMap { block -> Anthropic.ToolUseBlock? in
                if case .toolUse(let toolUseBlock) = block {
                    return toolUseBlock
                }
                return nil
            }
            await onEvent(.toolCall(id, toolUseBlocks))
        case .unknown(let delta):
            logger.debug("Received unknown delta type: \(delta.type) for index \(event.index)")
        }
    }

    private func updateTextDelta(_ id: String, index: Int, delta: ServerStreamingEvent.TextDelta) async {
        currentText += delta.text
        await onEvent(.text(id, delta.text))
        if let existingBlock = pendingBlocks[index],
            case .text(let textBlock) = existingBlock {
            let updatedBlock = Anthropic.TextBlock(
                text: textBlock.text + delta.text,
                type: textBlock.type
            )
            pendingBlocks[index] = .text(updatedBlock)
        }
    }

    private func updateThinkingDelta(_ id: String, index: Int, delta: ServerStreamingEvent.ThinkingDelta) async {
        if var thinkingBlock = thinkingBlocks[index] {
            thinkingBlock.content += delta.thinking
            thinkingBlocks[index] = thinkingBlock
            await onEvent(.thinking(id, delta.thinking))
        }
    }

    /// Handle content block stop event
    private func handleContentBlockStop(_ event: ServerStreamingEvent.ContentBlockStopEvent) async {
        // Process thinking blocks
        if let thinkingBlock = thinkingBlocks[event.index],
           !thinkingBlock.content.isEmpty {
            await processThinkingBlockStop(event.index, thinkingBlock)
            thinkingBlocks.removeValue(forKey: event.index)
        }

        // Process tool calls
        if let pendingCall = pendingToolCalls[event.index],
           !pendingCall.jsonInput.isEmpty {
            await processToolCallStop(event.index, pendingCall)
            pendingBlocks.removeValue(forKey: event.index)
        }

        // Add final block to content blocks if not already processed
        if let finalBlock = pendingBlocks[event.index] {
            contentBlocks.append(finalBlock)
        }
        // Remove from pending blocks
        pendingBlocks.removeValue(forKey: event.index)
    }

    /// Process a thinking block stop
    private func processThinkingBlockStop(_ index: Int, _ thinkingBlock: ThinkingBlock) async {
        // Create a thinking block
        let block = Anthropic.ThinkingBlock(
            type: "thinking",
            thinking: thinkingBlock.content,
            signature: thinkingBlock.signature
        )

        // Add to content blocks if it has a signature
        if !thinkingBlock.signature.isEmpty {
            contentBlocks.append(.thinking(block))

            // Emit thinking signature event
            if let id = messageId {
                await onEvent(.thinkingSignature(id, true))
            }
        }
    }

    /// Process a tool call stop
    private func processToolCallStop(_ index: Int, _ pendingCall: PendingToolCall) async {
        do {
            let toolUseBlock = try await parseToolCall(pendingCall)
            addOrReplaceToolUseBlock(toolUseBlock)

            // Get all tool use blocks
            let allToolUseBlocks = contentBlocks.compactMap { block -> Anthropic.ToolUseBlock? in
                if case .toolUse(let toolUseBlock) = block {
                    return toolUseBlock
                }
                return nil
            }

            if let id = messageId {
                // Emit tool call event
                await onEvent(.toolCall(id, allToolUseBlocks))

                // Execute the tool
                let toolResult = try await executeToolCall(id, toolUseBlock)
                toolResults[toolUseBlock.id] = toolResult

                // Create a tool result message and emit event
                let toolResultMessage = createToolResultMessage(id, toolUseBlock.id, toolResult)
                await onEvent(.toolResult(id, toolResultMessage))
            }
        } catch {
            logger.error("Error processing tool call: \(error.localizedDescription)")
        }
    }

    /// Handle message delta event
    private func handleMessageDelta(_ event: ServerStreamingEvent.MessageDeltaEvent) {
        // Handle message delta (stop reasons, etc.)
        if let stopReason = event.delta.stopReason {
            finishReason = stopReason
            logger.debug("Message delta with stop reason: \(stopReason)")
        }
    }

    /// Handle message stop event
    private func handleMessageStop(_ event: ServerStreamingEvent.MessageStopEvent) async {
        isComplete = true

        // Add text content if not in blocks already
        if !currentText.isEmpty {
            let hasTextBlock = contentBlocks.contains { block in
                if case .text = block { return true }
                return false
            }

            if !hasTextBlock {
                contentBlocks.append(
                    Anthropic.ContentBlock.text(
                        Anthropic.TextBlock(text: currentText, type: "text")
                    )
                )
            }
        }

        // Emit completion event
        if let id = messageId {
            await onEvent(.streamTaskCompleted(id))
        }
    }

    // MARK: - Helper Methods

    func addOrReplaceToolUseBlock(_ toolUseBlock: Anthropic.ToolUseBlock) {
        if let index = contentBlocks.firstIndex(where: { block in
            if case let .toolUse(existingBlock) = block {
                return existingBlock.id == toolUseBlock.id
            }
            return false
        }) {
            contentBlocks[index] = .toolUse(toolUseBlock)
        } else {
            contentBlocks.append(.toolUse(toolUseBlock))
        }
    }

    /// Create a chat message from a tool result
    private func createToolResultMessage(
        _ messageId: String,
        _ toolUseId: String,
        _ toolResult: Anthropic.ToolResultContent
    ) -> CueChatMessage {
        let toolResultMessage = Anthropic.ToolResultMessage(
            role: "user",
            content: [toolResult]
        )

        return CueChatMessage.anthropic(
            .toolMessage(toolResultMessage),
            stableId: "tool_result_\(toolUseId)",
            streamingState: nil,
            createdAt: Date().addingTimeInterval(TimeInterval(0.001))
        )
    }

    // MARK: - Public Methods

    /// Get the final message
    /// - Returns: The final message or nil if not complete
    func getFinalMessage() -> Anthropic.ChatMessageParam? {
        guard isComplete else { return nil }

        // Create an assistant message with all content blocks
        return .assistantMessage(.init(
            role: "assistant",
            content: contentBlocks
        ))
    }

    /// Get all accumulated tool results
    /// - Returns: An array of tool result contents
    func getToolResults() -> [Anthropic.ToolResultContent] {
        return Array(toolResults.values)
    }

    /// Check if all tool calls have been processed
    /// - Returns: True if all tool calls have results
    func hasAllToolResults() -> Bool {
        // Get all tool use blocks from content blocks
        let toolUseBlocks = contentBlocks.compactMap { block -> String? in
            if case .toolUse(let toolUseBlock) = block {
                return toolUseBlock.id
            }
            return nil
        }

        guard !toolUseBlocks.isEmpty else { return true }

        // Check if we have results for all tool use blocks
        return toolUseBlocks.allSatisfy { toolUseId in
            toolResults[toolUseId] != nil
        }
    }

    /// Check if the message has tool calls
    /// - Returns: True if the message has tool calls
    func hasToolUses() -> Bool {
        return contentBlocks.contains { block in
            if case .toolUse = block { return true }
            return false
        }
    }
}
