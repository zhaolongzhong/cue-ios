import Foundation

// MARK: - Tool Models

public struct MCPTool: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: InputSchema

    public init(name: String, description: String, inputSchema: InputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

public struct InputSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: PropertyDetails]?
    public let required: [String]?
    public let additionalProperties: Bool?
    public let schema: String?

    enum CodingKeys: String, CodingKey {
        case type
        case properties
        case required
        case additionalProperties
        case schema = "$schema"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        type = try container.decode(String.self, forKey: .type)
        properties = try container.decodeIfPresent([String: PropertyDetails].self, forKey: .properties)
        required = try container.decodeIfPresent([String].self, forKey: .required)
        schema = try container.decodeIfPresent(String.self, forKey: .schema)

        // Handle additionalProperties as either boolean or number
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .additionalProperties) {
            additionalProperties = boolValue
        } else if let numberValue = try? container.decodeIfPresent(Double.self, forKey: .additionalProperties) {
            additionalProperties = numberValue != 0
        } else {
            additionalProperties = nil
        }
    }

    public init(type: String,
                properties: [String: PropertyDetails]?,
                required: [String]?,
                additionalProperties: Bool? = nil,
                schema: String? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
        self.schema = schema
    }
}

// Custom type to handle different default value types
public enum DefaultValue: Codable, Equatable, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .integer(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .boolean(bool)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public struct PropertyDetails: Codable, Sendable {
    public let type: String?  // Made optional because it might be missing when anyOf is present
    public let title: String?
    public let items: Items?
    public let anyOf: [TypeDefinition]?
    public let defaultValue: DefaultValue?

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case items
        case anyOf
        case defaultValue = "default"
    }

    public init(type: String?,
                title: String?,
                items: Items?,
                anyOf: [TypeDefinition]?,
                defaultValue: DefaultValue?) {
        self.type = type
        self.title = title
        self.items = items
        self.anyOf = anyOf
        self.defaultValue = defaultValue
    }
}

public struct TypeDefinition: Codable, Sendable {
    public let type: String
}

public struct Items: Codable, Sendable {
    public let type: String

    public init(type: String) {
        self.type = type
    }
}

// MARK: - Response Models

public struct ToolsResponse: Codable {
    public let tools: [MCPTool]
}
