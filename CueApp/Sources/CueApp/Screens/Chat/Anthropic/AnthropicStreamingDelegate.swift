import os
import Foundation
import CueAnthropic
import CueCommon

public enum StreamEvent {

    case text(String, String)
    case thinking(String, String)
    case thinkingSignature(String, Bool)
    case toolCall(String, Anthropic.ToolUseBlock)
    case toolResult(String, String)

    // Streaming task lifecycle events
    case streamTaskStarted(String)  // messageId
    case streamTaskCompleted(String)  // messageId

    // Overall completion event
    case completed

    // Helper to extract the streaming ID if present
    var streamingId: String? {
        switch self {
        case .text(let id, _),
             .thinking(let id, _),
             .thinkingSignature(let id, _),
             .toolCall(let id, _),
             .toolResult(let id, _):
            return id
        case .streamTaskStarted(let id),
             .streamTaskCompleted(let id):
            return id
        case .completed:
            return nil
        }
    }
}

class AnthropicStreamingDelegate: Anthropic.StreamingDelegate {
    typealias ToolCallHandler = (String, Anthropic.ToolUseBlock) async -> String

    private let toolManager: ToolManager?
    private let onEvent: (StreamEvent) async -> Void
    private let onToolCall: ToolCallHandler

    // State tracking
    var messageId = "" {
        didSet {
            logger.debug("Message ID updated to \(self.messageId)")
        }
    }
    private var currentText = ""
    private var toolUseBuildUp: [Int: String] = [:]
    private var thinkingContent: [Int: String] = [:]
    private var thinkingSignatures: [Int: String] = [:]
    private var currentToolUseName: String?
    private var currentToolUseId: String?

    // Track all observed tool uses to ensure they're included in final message
    private var observedToolUses: [Anthropic.ToolUseBlock] = []

    // Track completed thinking blocks
    private var completedThinkingBlocks: [(content: String, signature: String)] = []

    // Final message construction
    var contentBlocks: [Anthropic.ContentBlock] = []
    public private(set) var toolResults: [Anthropic.ToolResultMessage] = []
    public private(set) var finalMessage: Anthropic.ChatMessageParam?
    private let logger = Logger(subsystem: "Anthropic", category: "AnthropicAgentStreamingDelegate")

    init(
        toolManager: ToolManager?,
        onEvent: @escaping (StreamEvent) async -> Void,
        onToolCall: @escaping ToolCallHandler
    ) {
        self.toolManager = toolManager
        self.onEvent = onEvent
        self.onToolCall = onToolCall
    }

    func didReceiveMessageStart(_ message: Anthropic.Message) async {
        logger.debug("[\(self.messageId)] Received message_start: \(message.id)")
        // Reset current state but keep previous thinking
        currentText = ""
        toolUseBuildUp = [:]
        thinkingContent = [:]
        thinkingSignatures = [:]
        observedToolUses = []
        contentBlocks = []
        // Notify about the new streaming task
        self.messageId = message.id
        await onEvent(.streamTaskStarted(message.id))
    }

    func didReceiveContentBlockStart(index: Int, contentBlock: Anthropic.ContentBlockStartEvent.ContentBlockStart) async {
        switch contentBlock {
        case .text:
            logger.debug("[\(self.messageId)] Content block start at index \(index): TEXT")
        case .toolUse(let toolUseBlock):
            logger.debug("[\(self.messageId)] Content block start at index \(index): TOOL_USE - \(toolUseBlock.name)")
            currentToolUseName = toolUseBlock.name
            currentToolUseId = toolUseBlock.id
            toolUseBuildUp[index] = ""
        case .thinking:
            logger.debug("[\(self.messageId)] Content block start at index \(index): THINKING")
            thinkingContent[index] = ""
            thinkingSignatures[index] = ""
        }
    }

    func didReceiveContentBlockDelta(index: Int, delta: Anthropic.ContentBlockDeltaEvent.DeltaContent) async {
        switch delta {
        case .textDelta(let textDelta):
            currentText += textDelta.text
            await onEvent(.text(messageId, textDelta.text))

        case .inputJsonDelta(let jsonDelta):
            if toolUseBuildUp[index] == nil {
                toolUseBuildUp[index] = ""
            }
            toolUseBuildUp[index]! += jsonDelta.partialJson
            logger.debug("[\(self.messageId)] Tool JSON delta at index \(index): \(jsonDelta.partialJson)")

        case .thinkingDelta(let thinkingDelta):
            if thinkingContent[index] == nil {
                thinkingContent[index] = ""
            }
            thinkingContent[index]! += thinkingDelta.thinking
            await onEvent(.thinking(messageId, thinkingDelta.thinking))

        case .signatureDelta(let sigDelta):
            logger.debug("[\(self.messageId)] Signature delta at index \(index): \(sigDelta.signature.prefix(20))...")
            thinkingSignatures[index] = sigDelta.signature
        }
    }

    func didReceiveContentBlockStop(index: Int) async {
        logger.debug("[\(self.messageId)] Content block stop at index \(index)")

        // If this was a thinking block, store it with its signature
        if let thinking = thinkingContent[index], !thinking.isEmpty,
           let signature = thinkingSignatures[index], !signature.isEmpty {
            logger.debug("[\(self.messageId)] Storing completed thinking block")
            completedThinkingBlocks.append((content: thinking, signature: signature))
            await onEvent(.thinkingSignature(messageId, true))
        }

        // When a tool use block is complete, execute the tool
        if let toolInput = toolUseBuildUp[index], !toolInput.isEmpty,
           let toolName = currentToolUseName,
           let toolId = currentToolUseId {
            logger.debug("[\(self.messageId)] Processing completed tool use at index \(index)")

            do {
                // Try to parse the JSON into a proper object
                if let data = toolInput.data(using: .utf8) {
                    var inputParams: [String: Any] = [:]

                    // Handle different JSON formats
                    if toolInput.hasPrefix("{") && toolInput.hasSuffix("}") {
                        // It's a complete JSON object
                        inputParams = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                    } else {
                        // It might be partial - try to complete it
                        let completeJson = "{\(toolInput)}"
                        if let completeData = completeJson.data(using: .utf8) {
                            inputParams = try JSONSerialization.jsonObject(with: completeData) as? [String: Any] ?? [:]
                        }
                    }

                    let jsonInputs = inputParams.mapValues { JSONValue(any: $0) }

                    // Create the tool use block
                    let toolUseBlock = Anthropic.ToolUseBlock(
                        type: "tool_use",
                        id: toolId,
                        input: jsonInputs,
                        name: toolName
                    )

                    // Add it to content blocks
                    contentBlocks.append(.toolUse(toolUseBlock))

                    // Also store it for reference
                    observedToolUses.append(toolUseBlock)

                    // Tell the event handler
                    await onEvent(.toolCall(messageId, toolUseBlock))

                    // Execute the tool and get the result
                    let result = await onToolCall(messageId, toolUseBlock)

                    // Create a tool result
                    let resultBlock = Anthropic.ContentBlock.text(
                        Anthropic.TextBlock(text: result, type: "text")
                    )

                    let toolResult = Anthropic.ToolResultMessage(
                        role: "user",
                        content: [
                            Anthropic.ToolResultContent(
                                isError: false,
                                toolUseId: toolUseBlock.id,
                                type: "tool_result",
                                content: [resultBlock]
                            )
                        ]
                    )
                    toolResults.append(toolResult)
                }
            } catch {
                logger.error("[\(self.messageId)] Error processing tool input: \(error)")
            }

            toolUseBuildUp.removeValue(forKey: index)
        }
    }

    // Helper to find a tool use block for a specific index
    private func getToolUseBlock(for index: Int) -> Anthropic.ToolUseBlock? {
        // This is a simplified implementation - you might need to refine this based on your actual data structure
        // If you can get the tool use block information during content block start, you can store it by index
        return observedToolUses.last
    }

    func didReceiveMessageDelta(stopReason: String?, stopSequence: String?, usage: Anthropic.Usage) async {
        logger.debug("[\(self.messageId)] Message delta - stop reason: \(stopReason ?? "none")")
    }

    func didReceiveMessageStop() async {
        logger.debug("[\(self.messageId)] Message stop received")

        // Create the final assistant message
        var messageBlocks: [Anthropic.ContentBlock] = []

        // Add any thinking blocks from this response
        for block in completedThinkingBlocks {
            messageBlocks.append(
                .thinking(
                    .init(
                        type: "thinking",
                        thinking: block.content,
                        signature: block.signature
                    )
                )
            )
        }

        // Add tool use blocks
        for toolUse in observedToolUses {
            messageBlocks.append(.toolUse(toolUse))
        }

        // Add text content if not empty
        if !currentText.isEmpty {
            messageBlocks.append(
                Anthropic.ContentBlock.text(
                    Anthropic.TextBlock(text: currentText, type: "text")
                )
            )
        }

        // Only create a message if we have actual content
        if !messageBlocks.isEmpty {
            finalMessage = Anthropic.ChatMessageParam.assistantMessage(
                Anthropic.MessageParam(role: "assistant", content: messageBlocks)
            )
            logger.debug("[\(self.messageId)] Created final message with \(messageBlocks.count) blocks")
        } else {
            logger.debug("[\(self.messageId)] No content blocks to create final message")
        }
        await onEvent(.streamTaskCompleted(messageId))
    }

    func didReceivePing() async {
        // No action needed
    }

    func didReceiveError(_ error: Anthropic.Error) async {
        logger.error("[\(self.messageId)] Stream error: \(error)")
    }

    func didCompleteWithError(_ error: Anthropic.Error) async {
        logger.error("[\(self.messageId)] Stream completed with error: \(error)")
    }

    // Helper method to extract thinking blocks for future use
    public func getCompletedThinkingBlocks() -> [Anthropic.ThinkingBlock] {
        return completedThinkingBlocks.map { Anthropic.ThinkingBlock(type: "thinking", thinking: $0.content, signature: $0.signature) }
    }

    public func getOriginalMessage() -> Anthropic.ChatMessageParam? {
        return finalMessage
    }
}

extension AnthropicStreamingDelegate {
    // Wait for all tool calls to complete
    @MainActor
    func waitForToolResults() async {
        // If we have observed tool uses but no tool results yet, add a small delay
        // This is a safety mechanism to ensure tool results are processed
        let toolUseCount = observedToolUses.count
        let toolResultCount = toolResults.count

        if toolUseCount > 0 && toolResultCount < toolUseCount {
            logger.debug("[\(self.messageId)] Waiting for tool results to be processed: \(toolResultCount)/\(toolUseCount)")

            // Add a small delay to allow tool results to be processed
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

            // Check again and log warning if still not complete
            if toolResults.count < observedToolUses.count {
                logger.warning("[\(self.messageId)] Tool results may not be fully processed: \(self.toolResults.count)/\(self.observedToolUses.count)")
            }
        }
    }

    // Add a helper method to check if all tool uses have corresponding results
    func hasCompleteToolResults() -> Bool {
        let res = toolResults.count >= observedToolUses.count
        if !res {
            logger.warning("[\(self.messageId)] Incomplete tool results: \(self.toolResults.count)/\(self.observedToolUses.count)")
        }
        return res
    }
}
