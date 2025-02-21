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
}

extension Function {
    public var prettyArguments: String {
        JSONFormatter.prettyString(from: arguments) ?? arguments
    }
}
