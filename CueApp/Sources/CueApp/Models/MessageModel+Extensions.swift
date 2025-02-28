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
        self.init(id: messageId, conversationId: conversationId, author: message.author, content: message.messageContent, metadata: metadata)
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

    public var toolCalls: [ToolCall]? {
        if self.type == .toolCall {
            if case .array(let array) = content {
                return try? JSONDecoder().decode([ToolCall].self, from: JSONEncoder().encode(array))
            }
        }
        return nil
    }

    public var toolUses: [Anthropic.ToolUseBlock]? {
        if self.type == .toolUse {
            if case .array(let array) = content {
                return try? JSONDecoder().decode([Anthropic.ToolUseBlock].self, from: JSONEncoder().encode(array))
            }
        }
        return nil
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
        // For toolCalls
        if let toolCalls = self.toolCalls {
            return toolCalls.map { toolCall -> String in
                // Using prettyArguments for better formatting
                return "\(toolCall.function.name): \(toolCall.function.prettyArguments)"
            }.joined(separator: "; ")
        }

        // For toolUses
        if let toolUses = self.toolUses {
            return toolUses.map { toolUse -> String in
                let inputStr = toolUse.input.map { key, value in
                    "\(key): \(value.asString ?? String(describing: value))"
                }.joined(separator: ", ")
                return "\(toolUse.name): \(inputStr)"
            }.joined(separator: "; ")
        }

        // Manual parsing of content array if needed
        if case .array(let array) = self.content {
            var results: [String] = []

            // Check for tool_use blocks
            let toolUseItems = array.filter { item in
                if case .object(let dict) = item, dict["type"]?.asString == "tool_use" {
                    return true
                }
                return false
            }

            if !toolUseItems.isEmpty {
                for item in toolUseItems {
                    if case .object(let dict) = item,
                       let name = dict["name"]?.asString,
                       case .object(let inputDict) = dict["input"] {
                        let inputStr = inputDict.map { key, value in
                            "\(key): \(value.asString ?? String(describing: value))"
                        }.joined(separator: ", ")
                        results.append("\(name): \(inputStr)")
                    }
                }
            }

            // Check for function_call blocks
            let toolCallItems = array.filter { item in
                if case .object(let dict) = item,
                   (dict["type"]?.asString == "function" || dict["type"]?.asString == "tool_call") {
                    return true
                }
                return false
            }

            if !toolCallItems.isEmpty {
                for item in toolCallItems {
                    if case .object(let dict) = item,
                       let function = dict["function"],
                       case .object(let functionDict) = function,
                       let name = functionDict["name"]?.asString,
                       let args = functionDict["arguments"]?.asString {
                        // Try to format arguments as pretty JSON
                        let prettyArgs = JSONFormatter.prettyString(from: args) ?? args
                        results.append("\(name): \(prettyArgs)")
                    }
                }
            }

            // Check for tool_result blocks
            let toolResultItems = array.filter { item in
                if case .object(let dict) = item, dict["type"]?.asString == "tool_result" {
                    return true
                }
                return false
            }

            if !toolResultItems.isEmpty {
                for item in toolResultItems {
                    if case .object(let dict) = item,
                       let name = dict["name"]?.asString,
                       let content = dict["content"]?.asString {
                        results.append("\(name): \(content)")
                    }
                }
            }

            if !results.isEmpty {
                return results.joined(separator: "; ")
            }
        }

        return nil
    }
}

extension ContentDetail {
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
    static func fromContentValue(_ contentValue: OpenAI.ContentValue) -> ContentDetail {
        switch contentValue {
        case .string(let text):
            return .string(text)
        case .array(let items):
            return .array(items.toJSONValues())
        }
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
}

extension Array where Element == OpenAI.ContentBlock {
    func toJSONValues() -> [JSONValue] {
        return self.map { contentBlock in
            var jsonObject: [String: JSONValue] = [:]
            jsonObject["type"] = .string(contentBlock.type.rawValue)
            switch contentBlock {
            case .text(let text):
                jsonObject["text"] = .string(text)
            case .imageUrl(let image):
                jsonObject["image_url"] = .object(["url": .string(image.url)])
            }
            return .object(jsonObject)
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
        // Create a dictionary to store the properties
        var jsonObject: [String: JSONValue] = [:]

        // Add a "type" field to distinguish between different cases
        switch self {
        case .local(let msg, _, _):
            jsonObject["type"] = .string("local")
            jsonObject["message"] = encodeToJSONValue(msg)

        case .openAI(let msg, _, _):
            jsonObject["type"] = .string("openai")
            jsonObject["message"] = encodeToJSONValue(msg)

        case .anthropic(let msg, _, _):
            jsonObject["type"] = .string("anthropic")
            jsonObject["message"] = encodeToJSONValue(msg)

        case .gemini(let msg, _, _):
            jsonObject["type"] = .string("gemini")
            jsonObject["message"] = encodeToJSONValue(msg)

        case .cue(let msg, _, _):
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
        return .local(message, stableId: stableId, streamingState: streamingState)
    }

    // Helper function to create OpenAI message
    private func createOpenAIMessage(from jsonObject: [String: JSONValue]) -> CueChatMessage? {
        guard let messageValue = jsonObject["message"],
              let message = decodeFromJSONValue(messageValue, type: OpenAI.ChatMessageParam.self) else {
            return nil
        }

        return .openAI(message, stableId: self.id)
    }

    // Helper function to create Anthropic message
    private func createAnthropicMessage(from jsonObject: [String: JSONValue]) -> CueChatMessage? {
        guard let messageValue = jsonObject["message"],
              let message = decodeFromJSONValue(messageValue, type: Anthropic.ChatMessageParam.self) else {
            return nil
        }

        let stableId = extractStableId(from: jsonObject)
        let streamingState = extractStreamingState(from: jsonObject)
        return .anthropic(message, stableId: stableId, streamingState: streamingState)
    }

    // Helper function to create Gemini message
    private func createGeminiMessage(from jsonObject: [String: JSONValue]) -> CueChatMessage? {
        guard let messageValue = jsonObject["message"],
              let message = decodeFromJSONValue(messageValue, type: Gemini.ChatMessageParam.self) else {
            return nil
        }

        return .gemini(message, stableId: self.id)
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

extension MessageModelRecord {
    func toCueChatMessage() throws -> CueChatMessage? {
        let messageModel = try self.toMessageModel()
        return messageModel.toCueChatMessage()
    }
}
