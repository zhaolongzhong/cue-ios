import CueOpenAI

struct ToolMessages: Codable {
    let messages: [OpenAI.ToolMessage]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        messages = try container.decode([OpenAI.ToolMessage].self)
    }

    init(messages: [OpenAI.ToolMessage]) {
        self.messages = messages
    }

    func getText() -> String {
        var text = ""
        for message in self.messages {
            text += "\(message.content.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension OpenAI.ToolMessage {
    func getText() -> String {
        // Similar to ToolResultMessage, trim whitespace and newlines
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ToolResultMessage: Codable {
    let msgId: String
    let role: String
    let content: [ToolResultContent]

    enum CodingKeys: String, CodingKey {
        case msgId = "msg_id"
        case role
        case content
    }

    func getText() -> String {
        var text = ""
        for item in self.content {
            if item.type == "tool_result" {
                text += String(describing: content)

            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

// MARK: - Wrapper structure for the complete payload
struct ToolResponse: Codable {
    let payload: ToolResponsePayload
    let model: String
}

// MARK: - JSONValue Extension
extension JSONValue {
    func toToolResponse() -> ToolResponse? {
        guard case .dictionary(let payloadDict) = self,
              let model = payloadDict["model"]?.asString else {
            return nil
        }

        // Parse payload
        guard let msgId = payloadDict["msg_id"]?.asString,
              let payloadModel = payloadDict["model"]?.asString,
              case .dictionary(let authorDict) = payloadDict["author"] else {
            return nil
        }

        // Parse author
        guard let authorRole = authorDict["role"]?.asString else { return nil }
        let authorName = authorDict["name"]?.asString ?? ""
        let author = Author(role: authorRole, name: authorName, metadata: nil)

        // Parse tool result message (optional)
        var toolResultMessage: ToolResultMessage?
        if case .dictionary(let toolResultDict) = payloadDict["tool_result_message"] {
            if let parsedToolResult = parseToolResultMessage(from: toolResultDict) {
                toolResultMessage = parsedToolResult
            }
        }

        // Parse tool messages (optional)
        var toolMessages: ToolMessages?
        if case .array(let messagesArray) = payloadDict["tool_messages"] {
            if let parsedToolMessages = parseToolMessages(from: messagesArray) {
                toolMessages = parsedToolMessages
            }
        }

        // Create payload with optional fields
        let toolResponsePayload = ToolResponsePayload(
            msgId: msgId,
            model: payloadModel,
            author: author,
            toolResultMessage: toolResultMessage,
            toolMessages: toolMessages
        )

        return ToolResponse(
            payload: toolResponsePayload,
            model: model
        )
    }

    // Helper function to parse ToolResultMessage
    private func parseToolResultMessage(from dict: [String: JSONValue]) -> ToolResultMessage? {
        guard let toolMsgId = dict["msg_id"]?.asString,
              let toolRole = dict["role"]?.asString,
              case .array(let contentArray) = dict["content"] else {
            return nil
        }

        // Parse content array
        let content: [ToolResultContent?] = contentArray.map { contentValue -> ToolResultContent? in
            guard case .dictionary(let contentDict) = contentValue,
                  case .bool(let isError) = contentDict["is_error"],
                  let toolUseId = contentDict["tool_use_id"]?.asString,
                  let type = contentDict["type"]?.asString else {
                return nil
            }

            let content: String
            if let contentStr = contentDict["content"]?.asString {
                content = contentStr
            } else if case .array(let contentArray) = contentDict["content"],
                      let firstContent = contentArray.first?.asString {
                content = firstContent
            } else {
                content = ""
            }

            return ToolResultContent(
                isError: isError,
                toolUseId: toolUseId,
                type: type,
                content: ResultContentBlock(content: content)
            )
        }

        guard !content.isEmpty else { return nil }

        return ToolResultMessage(
            msgId: toolMsgId,
            role: toolRole,
            content: content.compactMap { $0 }
        )
    }

    // Helper function to parse ToolMessages
    private func parseToolMessages(from array: [JSONValue]) -> ToolMessages? {
        let messages: [OpenAI.ToolMessage] = array.compactMap { messageValue in
            guard case .dictionary(let messageDict) = messageValue,
                  let toolCallId = messageDict["tool_call_id"]?.asString,
                  let content = messageDict["content"]?.asString,
                  let role = messageDict["role"]?.asString else {
                return nil
            }

            return OpenAI.ToolMessage(
                role: role,
                content: content,
                toolCallId: toolCallId
            )
        }

        guard !messages.isEmpty else { return nil }
        return ToolMessages(messages: messages)
    }
}
