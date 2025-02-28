//
//  LocalChat+Models.swift
//  CueApp
//
import Foundation
import CueCommon
import CueOpenAI

public enum LocalChatMessageParam: Codable, Sendable, Identifiable {
    case userMessage(OpenAI.MessageParam)
    case assistantMessage(LocalAssistantMessage, LocalResponse? = nil)
    case toolMessage(OpenAI.ToolMessage)

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
        case .assistantMessage(let message, _):
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
            self = .userMessage(try OpenAI.MessageParam(from: decoder))
        case "assistant":
            self = .assistantMessage(try LocalAssistantMessage(from: decoder), nil)
        case "tool":
            self = .toolMessage(try OpenAI.ToolMessage(from: decoder))
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
            return "tool"
        }
    }

    public var content: OpenAI.ContentValue {
        switch self {
        case .userMessage(let message):
            return message.content
        case .assistantMessage(let message, _):
            return .string(message.content ?? "")
        case .toolMessage(let message):
            return .string(message.content)
        }
    }

    public var toolCalls: [LocalToolCall] {
        switch self {
        case .assistantMessage(let message, _):
            return message.toolCalls ?? []
        default:
            return []
        }
    }

    public var toolName: String? {
        toolCalls.map{ $0.function.name }.joined(separator: ", ")
    }

    public var toolArgs: String? {
        toolCalls.map { $0.function.prettyArguments }.joined(separator: ", ")
    }
}

public struct LocalAssistantMessage: Decodable, Encodable, Equatable, Sendable {
    public let role: String
    public let content: String?
    public let toolCalls: [LocalToolCall]?

    public init(role: String, content: String?, toolCalls: [LocalToolCall]? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }

    private enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }

    public var hasToolCall: Bool {
        toolCalls?.count ?? 0 > 0
    }
}
public struct LocalToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let function: LocalFunction

    public init(id: String, type: String, function: LocalFunction) {
        self.id = id
        self.type = type
        self.function = function
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.id) {
            id = try container.decode(String.self, forKey: .id)
        } else {
            let randomString = String((0..<4).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
            id = "tool_call_id_\(randomString)"
        }

        if container.contains(.type) {
            type = try container.decode(String.self, forKey: .type)
        } else {
            type = "function"
        }

        function = try container.decode(LocalFunction.self, forKey: .function)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, function
    }
}

public struct LocalFunction: Codable, Sendable, Equatable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }

    enum CodingKeys: String, CodingKey {
        case name, arguments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        if let stringValue = try? container.decode(String.self, forKey: .arguments) {
            arguments = stringValue
        } else if let dictionaryValue = try? container.decode([String: JSONValue].self, forKey: .arguments) {
            let data = try JSONEncoder().encode(dictionaryValue)
            arguments = String(data: data, encoding: .utf8) ?? "{}"
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .arguments,
                in: container,
                debugDescription: "Expected String or Dictionary for arguments"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if let data = arguments.data(using: .utf8),
           let decodedDict = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
            try container.encode(decodedDict, forKey: .arguments)
        } else {
            try container.encode(arguments, forKey: .arguments)
        }
    }
}

extension LocalFunction {
    public var prettyArguments: String {
        JSONFormatter.prettyString(from: arguments) ?? arguments
    }
}
