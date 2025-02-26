import CueCommon

extension Anthropic {

    public typealias AnthropicMessage = Message

    // MARK: - Anthropic Message Models
    public struct Message: Codable, Sendable {
        public let id: String
        public let content: [ContentBlock]
        public let model: String
        public let role: String
        public let stopReason: String?
        public let stopSequence: String?
        public let type: String
        public let usage: Usage

        public enum CodingKeys: String, CodingKey {
            case id
            case content
            case model
            case role
            case stopReason = "stop_reason"
            case stopSequence = "stop_sequence"
            case type
            case usage
        }

        public init(
            id: String,
            content: [ContentBlock],
            model: String,
            role: String,
            stopReason: String?,
            stopSequence: String?,
            type: String,
            usage: Usage
        ) {
            self.id = id
            self.content = content
            self.model = model
            self.role = role
            self.stopReason = stopReason
            self.stopSequence = stopSequence
            self.type = type
            self.usage = usage
        }
    }

    public enum StopReason: String, Codable {
        case endTurn = "end_turn"
        case maxTokens = "max_tokens"
        case stopSequence = "stop_sequence"
        case toolUse = "tool_use"
    }

    // MARK: - Usage
    public struct Usage: Codable, Sendable {
        public let cacheCreationInputTokens: Int?
        public let cacheReadInputTokens: Int?
        public let inputTokens: Int?
        public let outputTokens: Int?

        public enum CodingKeys: String, CodingKey {
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }

        public init(
            cacheCreationInputTokens: Int?,
            cacheReadInputTokens: Int?,
            inputTokens: Int?,
            outputTokens: Int?
        ) {
            self.cacheCreationInputTokens = cacheCreationInputTokens
            self.cacheReadInputTokens = cacheReadInputTokens
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
        }
    }
}
