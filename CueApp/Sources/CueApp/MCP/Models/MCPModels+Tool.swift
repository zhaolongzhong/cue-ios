import Foundation
import CueOpenAI

// MARK: - Tool Models

public  struct MCPTool: Codable {
    let name: String
    let description: String
    let inputSchema: InputSchema
}

public struct InputSchema: Codable {
    let type: String
    let properties: [String: PropertyDetails]?
    let required: [String]?
    let additionalProperties: Bool?
    let schema: String?

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
}

// Custom type to handle different default value types
public enum DefaultValue: Codable, Equatable {
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

public struct PropertyDetails: Codable {
    let type: String?  // Made optional because it might be missing when anyOf is present
    let title: String?
    let items: Items?
    let anyOf: [TypeDefinition]?
    let defaultValue: DefaultValue?

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case items
        case anyOf
        case defaultValue = "default"
    }
}

public struct TypeDefinition: Codable {
    let type: String
}

struct Items: Codable {
    let type: String
}

// MARK: - Response Models

struct ToolsResponse: Codable {
    let tools: [MCPTool]
}

// MARK: - Tool Extensions

extension MCPTool {
    var requiredParameters: [String] {
        return inputSchema.required ?? []
    }

    func parameterType(for name: String) -> String? {
        if let property = inputSchema.properties?[name] {
            if let type = property.type {
                return type
            } else if let anyOf = property.anyOf {
                return anyOf.map { $0.type }.joined(separator: "|")
            }
        }
        return nil
    }

    /// Convert MCPTool to dictionary representation
    func toDictionary(serverName: String? = nil) -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "description": description,
            "type": inputSchema.type
        ]

        // Add server name if provided
        if let serverName = serverName {
            dict["server"] = serverName
        }

        // Add properties if they exist
        if let properties = inputSchema.properties {
            var propsDict: [String: [String: Any]] = [:]

            for (propName, details) in properties {
                var propDetails: [String: Any] = [:]

                // Add type if available
                if let type = details.type {
                    propDetails["type"] = type
                }

                // Add title if available
                if let title = details.title {
                    propDetails["title"] = title
                }

                // Add default value if available
                if let defaultValue = details.defaultValue {
                    switch defaultValue {
                    case .string(let value): propDetails["default"] = value
                    case .integer(let value): propDetails["default"] = value
                    case .double(let value): propDetails["default"] = value
                    case .boolean(let value): propDetails["default"] = value
                    case .null: propDetails["default"] = NSNull()
                    }
                }

                // Add items if available
                if let items = details.items {
                    propDetails["items"] = ["type": items.type]
                }

                // Add anyOf if available
                if let anyOf = details.anyOf {
                    propDetails["anyOf"] = anyOf.map { ["type": $0.type] }
                }

                propsDict[propName] = propDetails
            }

            dict["properties"] = propsDict
        }

        // Add required fields if they exist
        if let required = inputSchema.required {
            dict["required"] = required
        }

        // Add schema if it exists
        if let schema = inputSchema.schema {
            dict["schema"] = schema
        }

        return dict
    }
}

extension MCPTool {
    func toOpenAITool() -> Tool {
        let parameters = Parameters(
            type: inputSchema.type,
            properties: convertProperties(),
            required: inputSchema.required ?? []
        )

        return Tool(
            function: FunctionDefinition(
                name: name,
                description: description,
                parameters: parameters
            )
        )
    }

    private func convertProperties() -> [String: Property] {
        guard let mcpProperties = inputSchema.properties else {
            return [:]
        }

        var properties: [String: Property] = [:]

        for (key, mcpProperty) in mcpProperties {
            if let type = mcpProperty.type {
                if type == "array" {
                    // Use the new array property initializer
                    properties[key] = Property.array(
                        description: mcpProperty.title,
                        itemType: mcpProperty.items?.type ?? "string"
                    )
                } else {
                    properties[key] = Property(
                        type: type,
                        description: mcpProperty.title
                    )
                }
            } else if let anyOf = mcpProperty.anyOf {
                properties[key] = Property(
                    type: anyOf.first?.type ?? "string",
                    description: mcpProperty.title
                )
            }
        }

        return properties
    }
}
