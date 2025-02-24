import Foundation
import CueCommon

public struct ToolDefinition: Codable {
    let type: ToolType
    let name: String
    let description: String
    let parameters: ToolParameters?
    
    enum CodingKeys: String, CodingKey {
        case type, name, description, parameters
    }
}

public enum ToolType: String, Codable {
    case function
}

public struct ToolParameters: Codable {
    let type: String
    let properties: [String: Parameter]
    let required: [String]
}

public struct Parameter: Codable {
    let type: String
}

public enum ToolChoice: String, Codable, Sendable {
    case auto, none, required, specify = "specify a function"
}

public struct Function: Codable, Sendable, Equatable {
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


public struct ToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let function: Function

    public init(id: String, type: String, function: Function) {
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

        function = try container.decode(Function.self, forKey: .function)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, function
    }
}

extension Function {
    public var prettyArguments: String {
        JSONFormatter.prettyString(from: arguments) ?? arguments
    }
}
