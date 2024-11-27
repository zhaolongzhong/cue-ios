import Foundation

extension MessageModel {
    init(
        id: String?,
        conversationId: String?,
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
            content: Content.fromString(payload.message ?? ""),
            toolCalls: nil
        )

        let metadata = MessageMetadata(
            model: payload.metadata?.model,
            usage: nil,
            payload: payload.payload
        )

        self.id = payload.msgId ?? "dirty_\(UUID().uuidString)"
        self.conversationId = conversationId
        self.author = author
        self.content = messageContent
        self.metadata = metadata
        self.createdAt = currentDate
        self.updatedAt = currentDate
    }
}

extension MessageContent {

    func getText() -> String {
        var text = content.getText()
        if !text.isEmpty {
            return text
        }
        if let toolCalls = toolCalls {
            var resultText = "Use tool: "

            for toolCall in toolCalls {
                resultText += toolCall.function.name
            }
            text = resultText
        }
        return text
    }
}

extension Content {
    init(string: String) {
        // Try to decode as JSON first
        if let data = string.data(using: .utf8),
           let jsonValue = try? JSONDecoder().decode(JSONValue.self, from: data) {
            switch jsonValue {
            case .array(let array):
                self = .array(array)
            case .dictionary(let dict):
                self = .dictionary(dict)
            default:
                // If it's not a valid JSON array or dictionary, treat as plain string
                self = .string(string)
            }
        } else {
            // If JSON parsing fails, treat as plain string
            self = .string(string)
        }
    }

    // Convenience static method to create from string
    static func fromString(_ string: String) -> Content {
        return Content(string: string)
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
                    case .dictionary(let dict):
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
        case .dictionary(let dict):
            if let text = dict["text"]?.asString ?? dict["content"]?.asString {
                return text
            }
            return ""
        }
    }
}

extension MessageModel {
    static func == (lhs: MessageModel, rhs: MessageModel) -> Bool {
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

    func getText() -> String {
        var text = self.content.getText()
        if let model = self.metadata?.model, model.lowercased().contains("claude") {
            var anthropicMessage: AnthropicMessage? {
                guard let payload = self.metadata?.payload else {
                    return nil
                }
                return payload.toAnthropicMessage()
            }
        }
        if text.isEmpty {
            if let model = self.metadata?.model, model.lowercased().contains("claude") {
                var anthropicMessage: AnthropicMessage? {
                    guard let payload = self.metadata?.payload else {
                        return nil
                    }
                    return payload.toAnthropicMessage()
                }
            } else {
                var chatCompletion: ChatCompletion? {
                    guard let payload = self.metadata?.payload else {
                        return nil
                    }
                    return payload.toChatCompletion()
                }
                if let toolCalls = chatCompletion?.choices[0].message.toolCalls, toolCalls.count > 0 {
                    text = "Use tool:"
                    for toolCall in toolCalls {
                        text += " " + toolCall.function.name
                    }
                }
            }
        }

        if text.isEmpty {
            var toolResponse: ToolResponse? {
                guard let payload = self.metadata?.payload else {
                    return nil
                }
                return payload.toToolResponse()
            }
            if let toolMessages = toolResponse?.payload.toolMessages {
                text = toolMessages.getText()
            } else if let toolResultMessage = toolResponse?.payload.toolResultMessage {
                text = toolResultMessage.getText()
            }

        }
        return text
    }

    func isToolCall() -> Bool {
        if let toolCalls = self.content.toolCalls, toolCalls.count > 0 {
            return true
        }
        switch self.content.content {
        case .array(let array):
            for item in array {
                switch item {
                case .dictionary(let dict):
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

    func isToolMessage() -> Bool {
        if let toolResponse = self.metadata?.payload?.toToolResponse() {
            return true
        }
        switch self.content.content {
        case .array(let array):
            for item in array {
                switch item {
                case .dictionary(let dict):
                    if dict["type"]?.asString == "tool_result" {
                        return true
                    }
                default:
                    continue
                }

            }
            return false
        case .dictionary(let dict):
            if dict["role"]?.asString == "tool" {
                return true
            }
            return false
        default:
            return false
        }
    }
}

extension Content: Equatable {
    static func == (lhs: Content, rhs: Content) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lhsValue), .string(let rhsValue)):
            return lhsValue == rhsValue
        case (.array(let lhsValue), .array(let rhsValue)):
            return lhsValue == rhsValue
        case (.dictionary(let lhsValue), .dictionary(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}
