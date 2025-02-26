import os
import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic

@MainActor
public final class AgentLoop<Client: ChatClientProtocol> {
    let chatClient: Client
    let toolManager: ToolManager?
    private let model: String
    public let logger = Logger(subsystem: "AgentLoop", category: "AgentLoop")

    public init(chatClient: Client, toolManager: ToolManager? = nil, model: String) {
        self.chatClient = chatClient
        self.toolManager = toolManager
        self.model = model
    }

    func run(with initialMessages: [Client.MessageParamType], request: CompletionRequest) async throws -> [Client.MessageParamType] {
        var conversation = initialMessages
        let initialMessageCount = initialMessages.count
        var iteration = 0

        while iteration < request.maxTurns {
            let completion = try await chatClient.createChatCompletion(
                model: model,
                messages: conversation,
                tools: request.tools,
                toolChoice: request.toolChoice
            )
            guard let assistantMessage = chatClient.extractAssistantMessage(from: completion) else {
                break
            }

            let shouldContinue: Bool
            switch assistantMessage {
            case .openAI(let msg):
                shouldContinue = await handleOpenAIMessage(msg, conversation: &conversation)
            case .anthropic(let msg):
                shouldContinue = await handleAnthropicMessage(msg, conversation: &conversation)
            case .local(let msg):
                shouldContinue = await handleLocalMessage(msg, conversation: &conversation)
            }

            if !shouldContinue { break }
            iteration += 1
        }

        // Return only the new messages (excluding initialMessages)
        return Array(conversation.dropFirst(initialMessageCount))
    }

    /// Handles an OpenAI message by appending the assistant's response and processing any tool calls.
    private func handleOpenAIMessage(_ msg: OpenAI.AssistantMessage, conversation: inout [Client.MessageParamType]) async -> Bool {
        guard let toolManager = self.toolManager else {
            return false
        }
        let nativeAssistantMsg = OpenAI.ChatMessageParam.assistantMessage(msg)
        let wrapLocal: (OpenAI.ChatMessageParam) -> CueChatMessage = { message in
                .openAI(message, stableId: UUID().uuidString)
        }
        appendWrappedMessage(nativeMsg: nativeAssistantMsg, wrap: wrapLocal, conversation: &conversation)

        if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
            let toolMessages = await toolManager.handleToolCall(toolCalls)
            for tm in toolMessages {
                let nativeToolMsg = OpenAI.ChatMessageParam.toolMessage(tm)
                appendWrappedMessage(nativeMsg: nativeToolMsg, wrap: wrapLocal, conversation: &conversation)
            }
            return true
        } else {
            // No tool calls means this is the final response.
            return false
        }
    }

    /// Handles an Anthropic message by processing its content blocks.
    private func handleAnthropicMessage(_ msg: Anthropic.Message, conversation: inout [Client.MessageParamType]) async -> Bool {
        guard let toolManager else {
            AppLog.log.warning("Tool manager not set, ignoring tool use.")
            return false
        }
        var processedToolUse = false
        AppLog.log.debug("Usage: \(String(describing: msg))")
        let wrapLocal: (Anthropic.ChatMessageParam) -> CueChatMessage = { message in
                .anthropic(message, stableId: UUID().uuidString)
        }
        for contentBlock in msg.content {
            switch contentBlock {
            case .text(let textBlock):
                let nativeAssistantMsg = Anthropic.ChatMessageParam.assistantMessage(
                    Anthropic.MessageParam(
                        role: "assistant",
                        content: [Anthropic.ContentBlock(content: textBlock.text)]
                    )
                )
                appendWrappedMessage(nativeMsg: nativeAssistantMsg, wrap: wrapLocal, conversation: &conversation)
            case .toolUse(let toolBlock):
                processedToolUse = true
                let nativeAssistantMsg = Anthropic.ChatMessageParam.assistantMessage(
                    Anthropic.MessageParam(
                        role: "assistant",
                        content: [Anthropic.ContentBlock(toolUseBlock: toolBlock)]
                    )
                )
                appendWrappedMessage(nativeMsg: nativeAssistantMsg, wrap: wrapLocal, conversation: &conversation)

                let toolResultMessage = await toolManager.callToolUse(toolBlock)
                let toolResultMessageParam = Anthropic.ChatMessageParam.toolMessage(
                    toolResultMessage
                )
                appendWrappedMessage(nativeMsg: toolResultMessageParam, wrap: wrapLocal, conversation: &conversation)
            default:
                break
            }
        }
        return processedToolUse
    }

    /// Handles an OpenAI message by appending the assistant's response and processing any tool calls.
    private func handleLocalMessage(_ msg: OpenAI.AssistantMessage, conversation: inout [Client.MessageParamType]) async -> Bool {
        guard let toolManager else {
            AppLog.log.warning("Tool manager not set, ignoring tool use.")
            return false
        }
        let nativeAssistantMsg = OpenAI.ChatMessageParam.assistantMessage(msg)

        // Use a wrapper function to handle the local message case
        let wrapLocal: (OpenAI.ChatMessageParam) -> CueChatMessage = { message in
                .local(message, stableId: UUID().uuidString)
        }

        appendWrappedMessage(nativeMsg: nativeAssistantMsg, wrap: wrapLocal, conversation: &conversation)

        if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
            let toolMessages = await toolManager.handleToolCall(toolCalls)
            for tm in toolMessages {
                let nativeToolMsg = OpenAI.ChatMessageParam.toolMessage(tm)
                appendWrappedMessage(nativeMsg: nativeToolMsg, wrap: wrapLocal, conversation: &conversation)
            }
            return true
        } else {
            return false
        }
    }

    /// Wraps and appends a native message to the conversation.
    private func appendWrappedMessage<T>(nativeMsg: T, wrap: (T) -> Any, conversation: inout [Client.MessageParamType]) {
        if Client.MessageParamType.self == CueChatMessage.self {
            if let wrapped = wrap(nativeMsg) as? Client.MessageParamType {
                conversation.append(wrapped)
            }
        } else if let native = nativeMsg as? Client.MessageParamType {
            conversation.append(native)
        }
    }
}
