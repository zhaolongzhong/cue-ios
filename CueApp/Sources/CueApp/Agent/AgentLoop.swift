import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic

@MainActor
final class AgentLoop<Client: ChatClientProtocol> {
    private let chatClient: Client
    private let toolManager: ToolManager?
    private let model: String

    init(chatClient: Client, toolManager: ToolManager? = nil, model: String) {
        self.chatClient = chatClient
        self.toolManager = toolManager
        self.model = model
    }

    func run(with initialMessages: [Client.MessageParamType], request: CompletionRequest) async throws -> [Client.MessageParamType] {
        var conversation = initialMessages
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
            }

            if !shouldContinue { break }
            iteration += 1
        }
        return conversation
    }

    /// Handles an OpenAI message by appending the assistant’s response and processing any tool calls.
    private func handleOpenAIMessage(_ msg: OpenAI.AssistantMessage, conversation: inout [Client.MessageParamType]) async -> Bool {
        let nativeAssistantMsg = OpenAI.ChatMessageParam.assistantMessage(msg)
        appendWrappedMessage(nativeMsg: nativeAssistantMsg, wrap: CueChatMessage.openAI, conversation: &conversation)

        if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
            let toolMessages = await handleToolCall(toolCalls)
            for tm in toolMessages {
                let nativeToolMsg = OpenAI.ChatMessageParam.toolMessage(tm)
                appendWrappedMessage(nativeMsg: nativeToolMsg, wrap: CueChatMessage.openAI, conversation: &conversation)
            }
            return true
        } else {
            // No tool calls means this is the final response.
            return false
        }
    }

    /// Handles an Anthropic message by processing its content blocks.
    private func handleAnthropicMessage(_ msg: Anthropic.Message, conversation: inout [Client.MessageParamType]) async -> Bool {
        var processedToolUse = false
        for contentBlock in msg.content {
            switch contentBlock {
            case .text(let textBlock):
                let nativeAssistantMsg = Anthropic.ChatMessageParam.assistantMessage(
                    Anthropic.MessageParam(
                        role: "assistant",
                        content: [Anthropic.ContentBlock(content: textBlock.text)]
                    )
                )
                appendWrappedMessage(nativeMsg: nativeAssistantMsg, wrap: CueChatMessage.anthropic, conversation: &conversation)
            case .toolUse(let toolBlock):
                processedToolUse = true
                let nativeAssistantMsg = Anthropic.ChatMessageParam.assistantMessage(
                    Anthropic.MessageParam(
                        role: "assistant",
                        content: [Anthropic.ContentBlock(toolUseBlock: toolBlock)]
                    )
                )
                appendWrappedMessage(nativeMsg: nativeAssistantMsg, wrap: CueChatMessage.anthropic, conversation: &conversation)

                let toolResult = await handleToolUse(toolBlock)
                let result = Anthropic.ToolResultContent(
                    isError: false,
                    toolUseId: toolBlock.id,
                    type: "tool_result",
                    content: [Anthropic.ContentBlock(content: toolResult)]
                )
                let toolResultMessage = Anthropic.ChatMessageParam.toolMessage(
                    Anthropic.ToolResultMessage(role: "user", content: [result])
                )
                appendWrappedMessage(nativeMsg: toolResultMessage, wrap: CueChatMessage.anthropic, conversation: &conversation)
            }
        }
        return processedToolUse
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

    /// Processes a list of ToolCall objects (used for OpenAI messages).
    private func handleToolCall(_ toolCalls: [ToolCall]) async -> [OpenAI.ToolMessage] {
        guard let toolManager = self.toolManager else {
            return []
        }
        var results: [OpenAI.ToolMessage] = []
        for toolCall in toolCalls {
            if let data = toolCall.function.arguments.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                do {
                    let result = try await toolManager.callTool(name: toolCall.function.name, arguments: args)
                    results.append(OpenAI.ToolMessage(role: "tool", content: result, toolCallId: toolCall.id))
                } catch {
                    results.append(OpenAI.ToolMessage(role: "tool", content: "Error: \(error.localizedDescription)", toolCallId: toolCall.id))
                }
            }
        }
        return results
    }

    /// Processes a tool use block from an Anthropic message.
    private func handleToolUse(_ toolBlock: Anthropic.ToolUseBlock) async -> String {
        guard let toolManager = self.toolManager else {
            return ""
        }
        do {
            var arguments: [String: Any] = [:]
            for (key, value) in toolBlock.input {
                switch value {
                case .string(let str): arguments[key] = str
                case .int(let int): arguments[key] = int
                case .number(let double): arguments[key] = double
                case .bool(let bool): arguments[key] = bool
                case .array(let arr): arguments[key] = arr
                case .object(let dict): arguments[key] = dict
                case .null: arguments[key] = NSNull()
                }
            }
            let result = try await toolManager.callTool(name: toolBlock.name, arguments: arguments)
            return result
        } catch {
            AppLog.log.error("Tool error: \(error)")
            return "Error: \(error.localizedDescription)"
        }
    }
}
