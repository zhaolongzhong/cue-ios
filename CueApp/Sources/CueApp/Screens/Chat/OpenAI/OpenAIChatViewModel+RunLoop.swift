//
//  OpenAIChatViewModel+RunLoop.swift
//  CueApp
//

import os.log
import Foundation
import Dependencies
import CueCommon
import CueOpenAI

extension AgentLoop where Client == OpenAI {
    func runWithStreamingOpenAI(
        with messages: [CueChatMessage],
        request: CompletionRequest,
        onStreamEvent: @escaping (OpenAIStreamEvent) async -> Void
    ) async throws -> [CueChatMessage] {
        var initialMessages = Array(messages)

        var iteration = 0
        var shouldContinue = true
        let maxIterations = request.maxTurns

        while shouldContinue && iteration < maxIterations {
            let currentMessages: [OpenAI.ChatMessageParam] = initialMessages.compactMap { $0.openAIChatParam }

            shouldContinue = false

            let delegate = createStreamingDelegate(
                onStreamEvent: onStreamEvent
            )

            // Start streaming
            let streamTask = try await chatClient.chat.completions.streamCreate(
                model: request.model,
                maxTokens: request.maxTokens ?? 4096,
                temperature: 0.7,
                messages: currentMessages,
                tools: request.tools,
                toolChoice: request.toolChoice,
                delegate: delegate
            )

            // Wait for completion
            try await streamTask.value

            // Wait for any tool calls to complete
            await delegate.waitForToolResults()

            // Process the iteration results and determine if we should continue
            let toolResultMessages = processIterationResults(
                delegate: delegate,
                messages: &initialMessages,
                shouldContinue: &shouldContinue
            )

            if !shouldContinue {
                break
            }

            // Update ui with tool result message
            if toolResultMessages.count > 0 {
                for msg in toolResultMessages {
                    await onStreamEvent(.toolResult(msg.id, msg))
                }
            }

            iteration += 1
        }

        await onStreamEvent(.completed)
        return initialMessages
    }

    private func createStreamingDelegate(
        onStreamEvent: @escaping (OpenAIStreamEvent) async -> Void
    ) -> OpenAIStreamingDelegate {
        return OpenAIStreamingDelegate(
            toolManager: self.toolManager,
            onEvent: { event in
                switch event {
                case .text(let id, let text):
                    await onStreamEvent(.text(id, text))
                case .toolCall(let id, let toolCalls):
                    await onStreamEvent(.toolCall(id, toolCalls))
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
            onToolCall: { _, toolCalls in
                if let toolManager = self.toolManager {
                    let result = await toolManager.handleToolCall(toolCalls)
                    return result
                } else {
                    AppLog.log.error("No tool manager available to handle tool")
                    return []
                }
            }
        )
    }

    private func processIterationResults(
        delegate: OpenAIStreamingDelegate,
        messages: inout [CueChatMessage],
        shouldContinue: inout Bool
    ) -> [CueChatMessage] {
        guard let finalMessage = delegate.finalMessage else { return [] }
        logger.debug("Adding final message")

        let hasToolUses = finalMessage.hasToolCall()

        // If there are tool results, add them and continue the conversation
        if hasToolUses && delegate.hasCompleteToolResults() {
            messages.append(.openAI(finalMessage, stableId: delegate.messageId, streamingState: nil))
            var toolResults: [CueChatMessage] = []
            let toolMessages = delegate.toolResultContents
            for toolMessage in toolMessages {
                let cueChatMessage = CueChatMessage.openAI(
                    .toolMessage(toolMessage),
                    stableId: "tool_result_\(toolMessage.toolCallId)"
                )
                messages.append(cueChatMessage)
                toolResults.append(cueChatMessage)
                shouldContinue = true
            }
            return toolResults
        } else if !hasToolUses {
            logger.error("No tool calls in final message, cannot continue.")
            messages.append(.openAI(finalMessage, stableId: delegate.messageId, streamingState: nil))
            shouldContinue = false
        } else {
            // Tool use without results - error case
            logger.error("Tool call without corresponding tool result. Cannot continue.")
            shouldContinue = false
        }

        return []
    }
}
