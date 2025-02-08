import CueOpenAI
import CueAnthropic
import CueMCP

extension Tool {
    public func toMCPTool() -> MCPTool {
        // Convert properties to the format expected by MCPTool
        let mcpProperties = convertProperties()

        // Create InputSchema
        let inputSchema = InputSchema(
            type: function.parameters.type,
            properties: mcpProperties,
            required: function.parameters.required,
            additionalProperties: nil,
            schema: nil
        )

        return MCPTool(
            name: function.name,
            description: function.description,
            inputSchema: inputSchema
        )
    }

    private func convertProperties() -> [String: PropertyDetails] {
        var mcpProperties: [String: PropertyDetails] = [:]

        for (key, property) in function.parameters.properties {
            if property.type == "array" {
                // Handle array type properties
                mcpProperties[key] = PropertyDetails(
                    type: property.type,
                    title: property.description,
                    items: Items(type: property.items?.type ?? "string"),
                    anyOf: nil,
                    defaultValue: nil
                )
            } else {
                // Handle regular properties
                mcpProperties[key] = PropertyDetails(
                    type: property.type,
                    title: property.description,
                    items: nil,
                    anyOf: nil,
                    defaultValue: nil
                )
            }
        }

        return mcpProperties
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
