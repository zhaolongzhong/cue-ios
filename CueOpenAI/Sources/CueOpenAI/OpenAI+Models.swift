import Foundation
import CueCommon

extension OpenAI {
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

        enum CodingKeys: String, CodingKey {
            case rejectedPredictionTokens = "rejected_prediction_tokens"
            case audioTokens = "audio_tokens"
            case acceptedPredictionTokens = "accepted_prediction_tokens"
            case reasoningTokens = "reasoning_tokens"
        }

        public init(
            rejectedPredictionTokens: Int,
            audioTokens: Int,
            acceptedPredictionTokens: Int,
            reasoningTokens: Int
        ) {
            self.rejectedPredictionTokens = rejectedPredictionTokens
            self.audioTokens = audioTokens
            self.acceptedPredictionTokens = acceptedPredictionTokens
            self.reasoningTokens = reasoningTokens
        }

        // Custom decoding initializer that handles missing keys
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let presentKeys = container.allKeys.map { $0.stringValue }
            self.rejectedPredictionTokens = try container.decodeIfPresent(Int.self, forKey: .rejectedPredictionTokens) ?? 0
            self.audioTokens = try container.decodeIfPresent(Int.self, forKey: .audioTokens) ?? 0
            self.acceptedPredictionTokens = try container.decodeIfPresent(Int.self, forKey: .acceptedPredictionTokens) ?? 0
            self.reasoningTokens = try container.decodeIfPresent(Int.self, forKey: .reasoningTokens) ?? 0
        }
    }


    public struct PromptTokenDetails: Codable, Sendable {
        public let cachedTokens: Int
        enum CodingKeys: String, CodingKey {
            case cachedTokens = "cached_tokens"
        }
        
        public init(cachedTokens: Int) {
            self.cachedTokens = cachedTokens
        }
    }

    public struct CompletionTokenDetails: Codable, Sendable {
        public let reasoningTokens: Int
        enum CodingKeys: String, CodingKey {
            case reasoningTokens = "reasoning_tokens"
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
    
        public init(role: String, content: String?, toolCalls: [ToolCall]? = nil) {
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

    // MARK: - Tool message
    public struct ToolMessage: Codable, Sendable {
        public let role: String
        public let content: String
        public let toolCallId: String
        

        public init(role: String, content: String, toolCallId: String) {
            self.role = role
            self.content = content
            self.toolCallId = toolCallId
        }

        enum CodingKeys: String, CodingKey {
            case toolCallId = "tool_call_id"
            case content
            case role
        }
    }
    
    public enum ChatMessageParam: Codable, Sendable, Identifiable {
        case userMessage(MessageParam)
        case assistantMessage(AssistantMessage)
        case toolMessage(ToolMessage)
        
        // Add coding keys if needed
        private enum CodingKeys: String, CodingKey {
            case role, content, toolCalls, toolCallId
        }
        
        // Implement encoding/decoding logic as needed
        public func encode(to encoder: Encoder) throws {
            _ = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .userMessage(let message):
                try message.encode(to: encoder)
            case .assistantMessage(let message):
                try message.encode(to: encoder)
            case .toolMessage(let message):
                try message.encode(to: encoder)
            }
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let role = try container.decode(String.self, forKey: .role)
            
            switch role {
            case "user":
                self = .userMessage(try MessageParam(from: decoder))
            case "assistant":
                self = .assistantMessage(try AssistantMessage(from: decoder))
            case "tool":
                self = .toolMessage(try ToolMessage(from: decoder))
            default:
                throw DecodingError.dataCorruptedError(forKey: .role, in: container, debugDescription: "Unknown role type")
            }
        }
        
        public var id: String {
            switch self {
            case .userMessage(let message):
                return "user_\(message)"
            case .assistantMessage(let message):
                return "assistant_\(message)"
            case .toolMessage(let message):
                return "tool_\(message)"
            }
        }
        
        public var role: String {
            switch self {
            case .userMessage:
                return "user"
            case .assistantMessage:
                return "assistant"
            case .toolMessage:
                return "tool"
            }
        }
        
        public var content: String {
            switch self {
            case .userMessage(let message):
                return message.content
            case .assistantMessage(let message):
                return message.content ?? String(describing: message.toolCalls)
            case .toolMessage(let message):
                return message.content
            }
        }
    }
    
    public struct MessageParam: Codable, Sendable {
        public let role: String
        public let content: String
        
        public init(role: String, content: String) {
            self.role = role
            self.content = content
        }
    }
    
    public struct ChatCompletionRequest: Codable, Sendable {
        public let model: String
        public let messages: [ChatMessageParam]
        public let maxTokens: Int
        public let temperature: Double
        public let tools: [JSONValue]?
        public let toolChoice: String?
        
        private enum CodingKeys: String, CodingKey {
            case model, messages, temperature, tools
            case maxTokens = "max_completion_tokens"
            case toolChoice = "tool_choice"
        }
        
        public init(
            model: String,
            messages: [OpenAI.ChatMessageParam],
            maxTokens: Int = 1000,
            temperature: Double = 1.0,
            tools: [JSONValue]? = nil,
            toolChoice: String? = nil
        ) {
            self.model = model
            self.messages = messages
            self.maxTokens = maxTokens
            self.temperature = temperature
            self.tools = tools
            self.toolChoice = toolChoice
        }
    }
    
    public struct ChatCompletionResponse: Decodable, Sendable {
        public struct Choice: Decodable, Sendable {
            public let message: MessageParam
            public let finishReason: String?
            
            private enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }
        
        public let id: String
        public let choices: [Choice]
    }
    
}
