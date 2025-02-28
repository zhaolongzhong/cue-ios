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
    
    public struct AssistantMessage: Decodable, Encodable, Equatable, Sendable {
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

        public var hasToolCall: Bool {
            toolCalls?.count ?? 0 > 0
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
        case assistantMessage(AssistantMessage, ChatCompletion? = nil)
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
            case .assistantMessage(let message, _):
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
                self = .assistantMessage(try AssistantMessage(from: decoder), nil)
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
            case .assistantMessage(let message, _):
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
        
        public var content: ContentValue {
            switch self {
            case .userMessage(let message):
                return message.content
            case .assistantMessage(let message, _):
                return .string(message.content ?? "")
            case .toolMessage(let message):
                return .string(message.content)
            }
        }

        public var contentBlocks: [ContentBlock] {
            switch self {
            case .userMessage(let message):
                if case .string(let text) = content {
                    return [.text(text)]
                } else if case .array(let array) = content {
                    return array
                }
                return []
            case .assistantMessage(let message, _):
                return [.text(message.content ?? "")]
            case .toolMessage(let message):
                return [.text(message.content)]
            }
        }

        public var toolCalls: [ToolCall] {
            switch self {
            case .assistantMessage(let message, _):
                return message.toolCalls ?? []
            default:
                return []
            }
        }

        public var toolName: String? {
            toolCalls.map{ $0.function.name }.joined(separator: ", ")
        }

        public var toolArgs: String? {
            toolCalls.map { $0.function.prettyArguments }.joined(separator: ", ")
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
