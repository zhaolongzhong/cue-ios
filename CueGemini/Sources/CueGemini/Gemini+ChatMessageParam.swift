import Foundation

extension Gemini {
    public enum ChatMessageParam: Codable, Equatable, Sendable, Identifiable {
        case userMessage(ModelContent)
        case assistantMessage(ModelContent, GenerateContentResponse? = nil)
        case toolMessage(ModelContent)

        private enum CodingKeys: String, CodingKey {
            case role, parts
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .userMessage(let message),
                 .assistantMessage(let message, _),
                 .toolMessage(let message):
                try container.encode(message, forKey: .parts)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let role = try container.decode(String.self, forKey: .role)
            let content = try ModelContent(from: decoder)

            switch role {
            case "user":
                if content.parts.first.map({ if case .functionResponse = $0 { return true }; return false }) ?? false {
                    self = .toolMessage(content)
                } else {
                    self = .userMessage(content)
                }
            case "assistant":
                self = .assistantMessage(content)
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
                return "user"  // Tool messages are sent as user messages in Gemini
            }
        }

        public var content: String {
            switch self {
            case .userMessage(let message),
                 .assistantMessage(let message, _),
                 .toolMessage(let message):
                return message.parts.first?.text ?? ""
            }
        }

        public var functionCalls: [FunctionCall] {
            switch self {
            case .assistantMessage(let message, _):
                return message.parts.compactMap { part in
                    if case .functionCall(let functionCall) = part {
                        return functionCall
                    }
                    return nil
                }
            default:
                return []
            }
        }

        public var hasFunctionCalls: Bool {
            functionCalls.count > 0
        }

        public var toolName: String? {
            functionCalls.map { $0.name }.joined(separator: ", ")
        }

        public var toolArgs: String? {
            functionCalls.map { $0.prettyArgs }.joined(separator: ", ")
        }

        public var modelContent: ModelContent {
            switch self {
            case .assistantMessage(let modelContent, _):
                return modelContent
            case .userMessage(let modelContent):
                return modelContent
            case .toolMessage(let modelContent):
                return modelContent
            }
        }
    }
}
