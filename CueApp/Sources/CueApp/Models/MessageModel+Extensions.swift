import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

extension MessageModel {
    init(from payload: MessagePayload, conversationId: String) {
        let id = payload.msgId ?? "dirty_\(UUID().uuidString)"
        let conversationId = conversationId
        let author = Author(
            role: payload.metadata?.author?.role ?? "assistant",
            name: payload.metadata?.author?.name ?? "",
            metadata: nil
        )

        let messageContent = MessageContent(
            type: nil,
            content: ContentDetail.fromString(payload.message ?? "")
        )

        let metadata = MessageMetadata(
            model: payload.metadata?.model,
            usage: nil,
            payload: payload.payload
        )
        let currentDate = Date()
        self.init(id: id, conversationId: conversationId, author: author, content: messageContent, metadata: metadata, createdAt: currentDate, updatedAt: currentDate)
    }

    init(from message: CueChatMessage, conversationId: String) {
        if message.stableId == nil {
            AppLog.log.error("No stableId for message \(String(describing: message))")
        }
        let messageId = message.stableId ?? UUID().uuidString
        let metadata = MessageMetadata(model: nil, usage: nil, payload: message.toJSONValue())
        let createdAt = message.createdAt ?? Date()
        self.init(id: messageId, conversationId: conversationId, author: message.author, content: message.messageContent, metadata: metadata, createdAt: createdAt, updatedAt: createdAt)
    }
}

extension MessageModel {
    enum Role: String {
        case user
        case assistant
        case tool
    }

    var role: Role {
        Role(rawValue: author.role) ?? .assistant
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
        default:
            break
        }
        return false
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
        case .object(let dict):
            if dict["role"]?.asString == "tool" {
                return true
            }
        default:
            break
        }
        return false
    }
}

extension MessageModel {
    func toCueChatMessage() -> CueChatMessage? {
        guard let payload = self.metadata?.payload else {
            // If no payload is available, we can't determine the original type
            return .cue(self)
        }

        guard case .object(let jsonObject) = payload,
              let type = jsonObject["type"]?.asString else {
            // Default to cue type if we couldn't extract type from payload
            return .cue(self)
        }

        switch type {
        case "local":
            return createLocalMessage(from: jsonObject)
        case "openai":
            return createOpenAIMessage(from: jsonObject)
        case "anthropic":
            return createAnthropicMessage(from: jsonObject)
        case "gemini":
            return createGeminiMessage(from: jsonObject)
        case "cue", _:
            // For cue type or unknown type, we can just return this message model
            return .cue(self, stableId: self.id)
        }
    }

    // Helper function to create local message
    private func createLocalMessage(from jsonObject: [String: JSONValue]) -> CueChatMessage? {
        guard let messageValue = jsonObject["message"],
              let message = decodeFromJSONValue(messageValue, type: OpenAI.ChatMessageParam.self) else {
            return nil
        }

        let stableId = extractStableId(from: jsonObject)
        let streamingState = extractStreamingState(from: jsonObject)
        return .local(message, stableId: stableId, streamingState: streamingState, createdAt: self.createdAt)
    }

    // Helper function to create OpenAI message
    private func createOpenAIMessage(from jsonObject: [String: JSONValue]) -> CueChatMessage? {
        guard let messageValue = jsonObject["message"],
              let message = decodeFromJSONValue(messageValue, type: OpenAI.ChatMessageParam.self) else {
            return nil
        }

        let stableId = extractStableId(from: jsonObject)
        let streamingState = extractStreamingState(from: jsonObject)
        return .openAI(message, stableId: stableId, streamingState: streamingState, createdAt: self.createdAt)
    }

    // Helper function to create Anthropic message
    private func createAnthropicMessage(from jsonObject: [String: JSONValue]) -> CueChatMessage? {
        guard let messageValue = jsonObject["message"],
              let message = decodeFromJSONValue(messageValue, type: Anthropic.ChatMessageParam.self) else {
            return nil
        }

        let streamingState = extractStreamingState(from: jsonObject)
        return .anthropic(message, stableId: self.id, streamingState: streamingState, createdAt: self.createdAt)
    }

    // Helper function to create Gemini message
    private func createGeminiMessage(from jsonObject: [String: JSONValue]) -> CueChatMessage? {
        guard let messageValue = jsonObject["message"],
              let message = decodeFromJSONValue(messageValue, type: Gemini.ChatMessageParam.self) else {
            return nil
        }
        let streamingState = extractStreamingState(from: jsonObject)
        return .gemini(message, stableId: self.id, streamingState: streamingState, createdAt: self.createdAt)
    }

    // Helper function to extract stableId
    private func extractStableId(from jsonObject: [String: JSONValue]) -> String? {
        if case .string(let id) = jsonObject["stableId"] {
            return id
        } else {
            return self.id
        }
    }

    // Helper function to extract streamingState
    private func extractStreamingState(from jsonObject: [String: JSONValue]) -> StreamingState? {
        if let stateValue = jsonObject["streamingState"] {
            return decodeFromJSONValue(stateValue, type: StreamingState.self)
        }
        return nil
    }

    // Helper function to decode JSONValue back to the original type
    private func decodeFromJSONValue<T: Decodable>(_ value: JSONValue, type: T.Type) -> T? {
        do {
            // Convert JSONValue to Data
            let data = try JSONEncoder().encode(value)
            // Decode using JSONDecoder
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Error decoding from JSONValue: \(error)")
            return nil
        }
    }
}

extension CueChatMessage {
    var author: Author {
        Author(role: self.role)
    }

    var messageContent: MessageContent {
        MessageContent(
            type: self.contentType,
            content: ContentDetail.fromContentValue(self.content)
        )
    }

    func toJSONValue() -> JSONValue {
        var jsonObject: [String: JSONValue] = [:]

        // Add a "type" field to distinguish between different cases
        switch self {
        case .local(let msg, _, _, _):
            jsonObject["type"] = .string("local")
            jsonObject["message"] = encodeToJSONValue(msg)

        case .openAI(let msg, _, _, _):
            jsonObject["type"] = .string("openai")
            jsonObject["message"] = encodeToJSONValue(msg)

        case .anthropic(let msg, _, _, _):
            jsonObject["type"] = .string("anthropic")
            jsonObject["message"] = encodeToJSONValue(msg)

        case .gemini(let msg, _, _, _):
            jsonObject["type"] = .string("gemini")
            jsonObject["message"] = encodeToJSONValue(msg)

        case .cue(let msg, _, _, _):
            jsonObject["type"] = .string("cue")
            jsonObject["message"] = encodeToJSONValue(msg)
        }

        return .object(jsonObject)
    }

    // Helper function to encode any Encodable object to JSONValue
    private func encodeToJSONValue<T: Encodable>(_ value: T) -> JSONValue {
        do {
            let data = try JSONEncoder().encode(value)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            return JSONValue(any: jsonObject)
        } catch {
            print("Error encoding to JSONValue: \(error)")
            return .null
        }
    }
}

extension MessageModelRecord {
    func toCueChatMessage() throws -> CueChatMessage? {
        let messageModel = try self.toMessageModel()
        return messageModel.toCueChatMessage()
    }
}
