import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic

extension MessageModel {
    init(
        id: String,
        conversationId: String,
        author: Author,
        content: MessageContent,
        metadata: MessageMetadata?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.conversationId = conversationId
        self.author = author
        self.content = content
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from payload: MessagePayload, conversationId: String?) {
        let currentDate = Date()

        let author = Author(
            role: payload.metadata?.author?.role ?? "assistant",
            name: payload.metadata?.author?.name ?? "",
            metadata: nil
        )

        let messageContent = MessageContent(
            type: nil,
            content: ContentDetail.fromString(payload.message ?? ""),
            toolCalls: nil
        )

        let metadata = MessageMetadata(
            model: payload.metadata?.model,
            usage: nil,
            payload: payload.payload
        )

        self.id = payload.msgId ?? "dirty_\(UUID().uuidString)"
        self.conversationId = conversationId ?? ""
        self.author = author
        self.content = messageContent
        self.metadata = metadata
        self.createdAt = currentDate
        self.updatedAt = currentDate
    }

    enum Role: String {
        case user
        case assistant
        case tool
    }

    var role: Role {
        Role(rawValue: author.role) ?? .assistant
    }
}

extension MessageModel: Equatable {
    public static func == (lhs: MessageModel, rhs: MessageModel) -> Bool {
        // Compare all properties
        return lhs.id == rhs.id &&
            lhs.conversationId == rhs.conversationId &&
            lhs.author.role == rhs.author.role &&
            lhs.author.name == rhs.author.name &&
            lhs.author.metadata == rhs.author.metadata &&
            lhs.content.type == rhs.content.type &&
            lhs.content.content == rhs.content.content &&
            lhs.content.toolCalls == rhs.content.toolCalls &&
            lhs.metadata?.model == rhs.metadata?.model &&
            lhs.metadata?.usage == rhs.metadata?.usage &&
            lhs.metadata?.payload == rhs.metadata?.payload &&
            lhs.createdAt == rhs.createdAt &&
            lhs.updatedAt == rhs.updatedAt
    }

    var isUser: Bool {
        return self.role == Role.user && !(self.isTool || self.isToolMessage)
    }

    var isTool: Bool {
        if let toolCalls = self.content.toolCalls, toolCalls.count > 0 {
            return true
        }
        switch self.content.content {
        case .array(let array):
            for item in array {
                switch item {
                case .object(let dict):
                    if dict["type"]?.asString == "tool_use" {
                        return true
                    }
                default:
                    continue
                }

            }
            return false
        default:
            return false
        }
    }

    var isToolMessage: Bool {
        if self.metadata?.payload?.toToolResponse() != nil {
            return true
        }
        switch self.content.content {
        case .array(let array):
            for item in array {
                switch item {
                case .object(let dict):
                    if dict["type"]?.asString == "tool_result" {
                        return true
                    }
                default:
                    continue
                }

            }
            return false
        case .object(let dict):
            if dict["role"]?.asString == "tool" {
                return true
            }
            return false
        default:
            return false
        }
    }
}

extension MessageContent {
    public var text: String {
        return content.getText()
    }

    public var toolName: String? {
        if let toolCalls = toolCalls {
            return toolCalls.map { $0.function.name }.joined(separator: ", ")
        } else if let toolUses = toolUses {
            return toolUses.map { String(describing: $0.name) }.joined(separator: ", ")
        }
        return nil
    }

    public var toolArgs: String? {
        if let toolCalls = toolCalls {
            return toolCalls.map { $0.function.prettyArguments }.joined(separator: ", ")
        } else if let toolUses = toolUses {
            return toolUses.map { $0.prettyInput }.joined(separator: ", ")
        }
        return nil
    }
}

extension ContentDetail: Equatable {
    init(string: String) {
        // Try to decode as JSON first
        if let data = string.data(using: .utf8),
           let jsonValue = try? JSONDecoder().decode(JSONValue.self, from: data) {
            switch jsonValue {
            case .array(let array):
                self = .array(array)
            case .object(let dict):
                self = .object(dict)
            default:
                // If it's not a valid JSON array or dictionary, treat as plain string
                self = .string(string)
            }
        } else {
            // If JSON parsing fails, treat as plain string
            self = .string(string)
        }
    }

    static func fromString(_ string: String) -> ContentDetail {
        return ContentDetail(string: string)
    }
    func getText() -> String {
        switch self {
        case .string(let text):
            return text
        case .array(let array):
            let texts = array
                .compactMap { value -> String? in
                    switch value {
                    case .string(let str):
                        return str
                    case .object(let dict):
                        if let text = dict["text"]?.asString ?? dict["content"]?.asString {
                            return text
                        }
                        return nil
                    default:
                        return nil
                    }
                }
            return texts.reduce("") { result, text in
                result.isEmpty ? text : result + "\n" + text
            }
        case .object(let dict):
            if let text = dict["text"]?.asString ?? dict["content"]?.asString {
                return text
            }
            return ""
        }
    }

    public static func == (lhs: ContentDetail, rhs: ContentDetail) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lhsValue), .string(let rhsValue)):
            return lhsValue == rhsValue
        case (.array(let lhsValue), .array(let rhsValue)):
            return lhsValue == rhsValue
        case (.object(let lhsValue), .object(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}
