import Foundation
import CueAnthropic

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
                case .assistantMessage(let param):
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

            processIterationResults(
                delegate: delegate,
                messages: &initialMessages,
                shouldContinue: &shouldContinue
            )

            if !shouldContinue {
                break
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
                case .toolCall(let id, let toolUse):
                    await onStreamEvent(.toolCall(id, toolUse))
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
            onToolCall: { id, toolUseBlock in
                if let toolManager = self.toolManager {
                    let result = await toolManager.handleToolUse(toolUseBlock)
                    await onStreamEvent(.toolResult(id, result))
                    return result
                } else {
                    let errorMsg = "No tool manager available to handle tool: \(toolUseBlock.name)"
                    await onStreamEvent(.toolResult(id, errorMsg))
                    return errorMsg
                }
            }
        )
    }

    private func processIterationResults(
        delegate: AnthropicStreamingDelegate,
        messages: inout [CueChatMessage],
        shouldContinue: inout Bool
    ) {
        guard let finalMessage = delegate.finalMessage else { return }

        logger.debug("Adding final message")

        let hasToolUses = finalMessage.hasToolUse()

        // If message has tool uses, verify we have corresponding tool results
        if hasToolUses && delegate.hasCompleteToolResults() {
            // Add assistant message and tool results
            messages.append(.anthropic(finalMessage, stableId: delegate.messageId, streamingState: nil))

            // Add tool results immediately after the message with tool uses
            for toolResult in delegate.toolResults {
                messages.append(.anthropic(.toolMessage(toolResult), stableId: "tool_result_\(UUID().uuidString)", streamingState: nil))
            }
            shouldContinue = true
        } else if !hasToolUses {
            // No tool uses, safe to add the message
            messages.append(.anthropic(finalMessage, stableId: delegate.messageId, streamingState: nil))
            shouldContinue = false
        } else {
            // Tool use without results - error case
            logger.error("Tool use without corresponding tool result. Cannot continue.")
            shouldContinue = false
        }
    }
}
