import Foundation

public struct ToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let function: Function

    public init(id: String, type: String, function: Function) {
        self.id = id
        self.type = type
        self.function = function
    }

    public static func == (lhs: ToolCall, rhs: ToolCall) -> Bool {
        return lhs.id == rhs.id &&
            lhs.type == rhs.type &&
            lhs.function == rhs.function
    }
}

public struct Function: Codable, Sendable, Equatable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }

    public static func == (lhs: Function, rhs: Function) -> Bool {
        return lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments
    }
}

// MARK: - Usage Details
public struct Usage: Codable, Sendable {
    public let totalTokens: Int
    public let completionTokens: Int
    public let completionTokensDetails: TokenDetails
    public let promptTokensDetails: PromptTokenDetails
    public let promptTokens: Int

    public init(totalTokens: Int, completionTokens: Int, completionTokensDetails: TokenDetails, promptTokensDetails: PromptTokenDetails, promptTokens: Int) {
        self.totalTokens = totalTokens
        self.completionTokens = completionTokens
        self.completionTokensDetails = completionTokensDetails
        self.promptTokensDetails = promptTokensDetails
        self.promptTokens = promptTokens
    }

    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case completionTokens = "completion_tokens"
        case completionTokensDetails = "completion_tokens_details"
        case promptTokensDetails = "prompt_tokens_details"
        case promptTokens = "prompt_tokens"
    }
}

public struct TokenDetails: Codable, Sendable {
    public let rejectedPredictionTokens: Int
    public let audioTokens: Int
    public let acceptedPredictionTokens: Int
    public let reasoningTokens: Int

    public init(rejectedPredictionTokens: Int, audioTokens: Int, acceptedPredictionTokens: Int, reasoningTokens: Int) {
        self.rejectedPredictionTokens = rejectedPredictionTokens
        self.audioTokens = audioTokens
        self.acceptedPredictionTokens = acceptedPredictionTokens
        self.reasoningTokens = reasoningTokens
    }

    enum CodingKeys: String, CodingKey {
        case rejectedPredictionTokens = "rejected_prediction_tokens"
        case audioTokens = "audio_tokens"
        case acceptedPredictionTokens = "accepted_prediction_tokens"
        case reasoningTokens = "reasoning_tokens"
    }
}

public struct PromptTokenDetails: Codable, Sendable {
    public let cachedTokens: Int
    public let audioTokens: Int

    public init(cachedTokens: Int, audioTokens: Int) {
        self.cachedTokens = cachedTokens
        self.audioTokens = audioTokens
    }

    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
        case audioTokens = "audio_tokens"
    }
}

// MARK: - Choice and Message
public struct Choice: Codable, Sendable {
    public let finishReason: String
    public let message: AssistantMessage
    public let index: Int

    public init(finishReason: String, message: AssistantMessage, index: Int) {
        self.finishReason = finishReason
        self.message = message
        self.index = index
    }

    enum CodingKeys: String, CodingKey {
        case finishReason = "finish_reason"
        case message
        case index
    }
}

public struct AssistantMessage: Decodable, Encodable, Sendable {
    public let role: String
    public let content: String?
    public let toolCalls: [ToolCall]?
    
    public init(role: String, content: String?, toolCalls: [ToolCall]?) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }
    
    private enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
}

// MARK: - ChatCompletion
public struct ChatCompletion: Codable, Sendable {
    public let systemFingerprint: String
    public let usage: Usage
    public let choices: [Choice]
    public let id: String
    public let object: String
    public let model: String
    public let created: Int

    public init(systemFingerprint: String, usage: Usage, choices: [Choice], id: String, object: String, model: String, created: Int) {
        self.systemFingerprint = systemFingerprint
        self.usage = usage
        self.choices = choices
        self.id = id
        self.object = object
        self.model = model
        self.created = created
    }

    enum CodingKeys: String, CodingKey {
        case systemFingerprint = "system_fingerprint"
        case usage
        case choices
        case id
        case object
        case model
        case created
    }
}
