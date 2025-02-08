import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic

public enum CueAssistantMessage {
    case openAI(OpenAI.AssistantMessage)
    case anthropic(Anthropic.AnthropicMessage)
}

@MainActor
protocol ChatClientProtocol {
    associatedtype MessageParamType: Encodable
    associatedtype ChatCompletionType

    func createChatCompletion(
        model: String,
        messages: [MessageParamType],
        tools: [JSONValue]?,
        toolChoice: String?
    ) async throws -> ChatCompletionType

    func extractAssistantMessage(from completion: ChatCompletionType) -> CueAssistantMessage?
}

extension OpenAI: ChatClientProtocol {
    public typealias MessageParamType = OpenAI.ChatMessageParam
    public typealias ChatCompletionType = OpenAI.ChatCompletion

    public func createChatCompletion(
        model: String,
        messages: [OpenAI.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil
    ) async throws -> OpenAI.ChatCompletion {
        return try await self.chat.completions.create(
            model: model,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice
        )
    }

    public func extractAssistantMessage(from completion: OpenAI.ChatCompletion) -> CueAssistantMessage? {
        guard let message = completion.choices.first?.message else {
            return nil
        }
        return .openAI(message)
    }
}

extension Anthropic: ChatClientProtocol {
    public typealias MessageParamType = Anthropic.ChatMessageParam
    public typealias ChatCompletionType = Anthropic.AnthropicMessage

    public func createChatCompletion(
        model: String,
        messages: [Anthropic.ChatMessageParam],
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil
    ) async throws -> Anthropic.AnthropicMessage {
        var _toolChoice: [String: String]?
        if toolChoice != nil {
            _toolChoice = ["type": toolChoice!]
        }
        return try await self.messages.create(
            model: model,
            maxTokens: 1024, // adjust as needed
            messages: messages,
            tools: tools,
            toolChoice: _toolChoice
        )
    }

    public func extractAssistantMessage(from completion: Anthropic.AnthropicMessage) -> CueAssistantMessage? {
        return .anthropic(completion)
    }
}

extension CueClient: ChatClientProtocol {
    public typealias MessageParamType = CueChatMessage
    public typealias ChatCompletionType = CueCompletionResponse

    public func createChatCompletion(
        model: String,
        messages: [CueChatMessage],
        tools: [JSONValue]? = nil,
        toolChoice: String? = nil
    ) async throws -> CueCompletionResponse {
        return try await self.send(
            model: model,
            messages: messages,
            conversationId: nil,
            parentMessageId: nil,
            websocketRequestId: UUID().uuidString,
            tools: tools,
            toolChoice: toolChoice
        )
    }

    public func extractAssistantMessage(from completion: CueCompletionResponse) -> CueAssistantMessage? {
        if let chatCompletion = completion.content?.chatCompletion,
           let msg = chatCompletion.choices.first?.message {
            return .openAI(msg)
        } else if let anthropicMsg = completion.content?.anthropicMessage {
            return .anthropic(anthropicMsg)
        }
        return nil
    }
}
