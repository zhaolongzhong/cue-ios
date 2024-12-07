import Foundation

extension OpenAI {
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
        public let messages: [MessageParam]
        public let maxTokens: Int
        public let temperature: Double
        
        private enum CodingKeys: String, CodingKey {
            case model, messages
            case maxTokens = "max_tokens"
            case temperature
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
