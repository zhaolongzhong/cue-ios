import Foundation

extension OpenAI {
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
    
    public enum ChatMessage: Codable, Sendable, Identifiable {
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
                return "user_\(message.content)"
            case .assistantMessage(let message):
                return "assistant_\(message)"
            case .toolMessage(let message):
                return "tool_\(message.content)"
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
        public let messages: [ChatMessage]
        public let maxTokens: Int
        public let temperature: Double
        public let tools: [Tool]?
        public let toolChoice: String?
        
        private enum CodingKeys: String, CodingKey {
            case model, messages, temperature, tools
            case maxTokens = "max_completion_tokens"
            case toolChoice = "tool_choice"
        }
        
        public init(
            model: String,
            messages: [OpenAI.ChatMessage],
            maxTokens: Int = 1000,
            temperature: Double = 1.0,
            tools: [Tool]? = nil,
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
