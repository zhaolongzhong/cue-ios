import Foundation


// https://platform.openai.com/docs/api-reference/realtime-client-events/conversation/item
// https://github.com/openai/openai-python/blob/main/src/openai/types/beta/realtime/conversation_item.py
// https://github.com/openai/openai-python/blob/main/src/openai/types/beta/realtime/conversation_item_param.py

public enum Role: String, Codable, Sendable {
    case user
    case assistant
    case system
    case tool
}

public struct ConversationItem: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let type: ItemType?
    public let object: String? // always `realtime.item`
    public let status: String?
    public let role: Role?
    public let content: [ContentPart]?
    public let callId: String?
    public let name: String?
    public let arguments: String?
    public let output: String? // The output of the function call (for `function_call_output` items)
    
    public init(
        id: String,
        type: ItemType? = nil,
        object: String? = nil,
        status: String? = nil,
        role: Role? = nil,
        content: [ContentPart]? = nil,
        callId: String? = nil,
        name: String? = nil,
        arguments: String? = nil,
        output: String? = nil
    ) {
        self.id = id
        self.type = type
        self.object = object
        self.status = status
        self.role = role
        self.content = content
        self.callId = callId
        self.name = name
        self.arguments = arguments
        self.output = output
    }
}

public enum ItemType: String, Codable, Sendable {
    case functionCall = "function_call"
    case functionCallOutput = "function_call_output"
    case message
}

public struct FunctionCall: Codable, Equatable, Sendable {
    public let id: String
    public let type: String // This will always be "function_call"
    public let status: ConversationItem.ItemStatus
    public let callId: String
    public let name: String
    public let arguments: String

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case status
        case callId = "call_id"
        case name
        case arguments
    }
}

extension FunctionCall {
    public func toToolCall() -> ToolCall {
        let function = Function(
            name: self.name,
            arguments: self.arguments
        )
        
        return ToolCall(
            id: self.callId,
            type: self.type,
            function: function
        )
    }
}

public struct Message: Codable, Equatable, Sendable {
    public let id: String
    public let type: String // Example: "message"
    public let status: ConversationItem.ItemStatus
    public let role: Role
    public let content: [ContentPart]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case status
        case role
        case content
    }
}

extension ConversationItem {
    public enum ItemStatus: String, Codable, Sendable {
        case completed
        case inProgress = "in_progress"
        case incomplete
    }

    public func asMessage() -> Message? {
        guard type == .message else { return nil }
        guard let role = role,
              let statusStr = status,
              let content = content,
              let status = ConversationItem.ItemStatus(rawValue: statusStr) else { return nil }
        return Message(
            id: id,
            type: type?.rawValue ?? "",
            status: status,
            role: role,
            content: content
        )
    }
    
    public func asFunctionCall() -> FunctionCall? {
        guard type == .functionCall else { return nil }
        guard let callId = callId,
              let name = name,
              let arguments = arguments,
              let statusStr = status,
              let status = ConversationItem.ItemStatus(rawValue: statusStr) else { return nil }
        return FunctionCall(
            id: id,
            type: type?.rawValue ?? "",
            status: status,
            callId: callId,
            name: name,
            arguments: arguments
        )
    }
}
