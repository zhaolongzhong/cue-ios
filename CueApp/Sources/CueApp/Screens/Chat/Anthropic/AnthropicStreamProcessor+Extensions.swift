import Foundation
import CueCommon
import CueAnthropic
import os.log

// MARK: - Helper Methods
extension AnthropicStreamProcessor {
    /// Parse tool JSON into a tool use block
    func parseToolCall(_ pendingCall: PendingToolCall) async throws -> Anthropic.ToolUseBlock {
        do {
            // Try to parse the JSON into a proper object
            if let data = pendingCall.jsonInput.data(using: .utf8) {
                var inputParams: [String: Any] = [:]
                // Handle different JSON formats
                if pendingCall.jsonInput.hasPrefix("{") && pendingCall.jsonInput.hasSuffix("}") {
                    // It's a complete JSON object
                    inputParams = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                } else {
                    // It might be partial - try to complete it
                    let completeJson = "{\(pendingCall.jsonInput)}"
                    if let completeData = completeJson.data(using: .utf8) {
                        inputParams = try JSONSerialization.jsonObject(with: completeData) as? [String: Any] ?? [:]
                    }
                }

                // Try to extract tool name from input or use a placeholder
                let toolName = pendingCall.name.isEmpty ?
                (inputParams["name"] as? String ?? "unknown_tool") :
                pendingCall.name

                let toolId = pendingCall.id.isEmpty ?
                "tool_\(UUID().uuidString.prefix(8))" :
                pendingCall.id

                let jsonInputs = inputParams.mapValues { JSONValue(any: $0) }

                return Anthropic.ToolUseBlock(
                    type: "tool_use",
                    id: toolId,
                    input: jsonInputs,
                    name: toolName
                )
            } else {
                throw NSError(domain: "AnthropicStreamProcessor", code: 1001, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to convert tool input to data"
                ])
            }
        } catch {
            throw NSError(domain: "AnthropicStreamProcessor", code: 1002, userInfo: [
                NSLocalizedDescriptionKey: "Error processing tool input: \(error.localizedDescription)"
            ])
        }
    }

    /// Execute a tool call and return a result content block
    func executeToolCall(_ messageId: String, _ toolUseBlock: Anthropic.ToolUseBlock) async throws -> Anthropic.ToolResultContent {
        logger.debug("[\(messageId)] Executing tool: \(toolUseBlock.name)")

        let result = await toolManager.handleToolUse(toolUseBlock)

        // Create a tool result content block
        let resultBlock = Anthropic.ContentBlock.text(
            Anthropic.TextBlock(text: result, type: "text")
        )

        return Anthropic.ToolResultContent(
            isError: false,
            toolUseId: toolUseBlock.id,
            type: "tool_result",
            content: [resultBlock]
        )
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
}
