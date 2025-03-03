import Foundation
import CueCommon

extension OpenAI {
    public struct Usage: Codable, Equatable, Sendable {
        public let totalTokens: Int
        public let completionTokens: Int
        public let completionTokensDetails: CompletionTokenDetails
        public let promptTokensDetails: PromptTokenDetails
        public let promptTokens: Int
    
        public init(totalTokens: Int, completionTokens: Int, completionTokensDetails: CompletionTokenDetails, promptTokensDetails: PromptTokenDetails, promptTokens: Int) {
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

        public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
            self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
            self.completionTokens = try container.decode(Int.self, forKey: .completionTokens)
            self.promptTokens = try container.decode(Int.self, forKey: .promptTokens)

            // These are nested structures that need special handling
            self.completionTokensDetails = try container.decodeIfPresent(CompletionTokenDetails.self, forKey: .completionTokensDetails) ?? CompletionTokenDetails(
                rejectedPredictionTokens: 0,
                audioTokens: 0,
                acceptedPredictionTokens: 0,
                reasoningTokens: 0
            )

            // Handle prompt_tokens_details which might have different structure
            self.promptTokensDetails = try container.decodeIfPresent(PromptTokenDetails.self, forKey: .promptTokensDetails) ?? PromptTokenDetails(cachedTokens: 0)
        }
    }

    public struct CompletionTokenDetails: Codable, Equatable, Sendable {
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


    public struct PromptTokenDetails: Codable, Equatable, Sendable {
        public let cachedTokens: Int
        enum CodingKeys: String, CodingKey {
            case cachedTokens = "cached_tokens"
        }
        
        public init(cachedTokens: Int) {
            self.cachedTokens = cachedTokens
        }
    }
    
    // MARK: - Choice and Message
    public struct Choice: Codable, Equatable, Sendable {
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
    public struct ChatCompletion: Codable, Equatable, Sendable {
        public let systemFingerprint: String
        public let serviceTier: String
        public let usage: Usage
        public let choices: [Choice]
        public let id: String
        public let object: String
        public let model: String
        public let created: Int
    
        public init(systemFingerprint: String, serviceTier: String, usage: Usage, choices: [Choice], id: String, object: String, model: String, created: Int) {
            self.systemFingerprint = systemFingerprint
            self.serviceTier = serviceTier
            self.usage = usage
            self.choices = choices
            self.id = id
            self.object = object
            self.model = model
            self.created = created
        }
    
        enum CodingKeys: String, CodingKey {
            case systemFingerprint = "system_fingerprint"
            case serviceTier = "service_tier"
            case usage
            case choices
            case id
            case object
            case model
            case created
        }
    }

    // MARK: - Tool message
    public struct ToolMessage: Codable, Equatable, Sendable {
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

    public struct ChatCompletionRequest: Codable, Sendable {
        public let model: String
        public let reasoningEffort: String?
        public let messages: [ChatMessageParam]
        public let maxTokens: Int
        public let temperature: Double?
        public let tools: [JSONValue]?
        public let toolChoice: String?
        public let stream: Bool

        private enum CodingKeys: String, CodingKey {
            case model, messages, temperature, tools
            case reasoningEffort = "reasoning_effort"
            case maxTokens = "max_completion_tokens"
            case toolChoice = "tool_choice"
            case stream = "stream"
        }
        
        public init(
            model: String,
            reasoningEffort: String = "medium",
            messages: [OpenAI.ChatMessageParam],
            maxTokens: Int = 1000,
            temperature: Double = 1.0,
            tools: [JSONValue]? = nil,
            toolChoice: String? = nil,
            stream: Bool = false
        ) {
            self.model = model
            self.messages = messages
            self.maxTokens = maxTokens
            self.temperature = model.contains("o3-mini") ? nil : temperature
            self.tools = tools
            self.toolChoice = toolChoice
            self.stream = stream
            self.reasoningEffort = model.contains("o3-mini") ? reasoningEffort : nil
        }
    }
}
