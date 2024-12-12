import CueOpenAI

extension InputSchema {
    public init(type: String, properties: [String: PropertyDetails]?, required: [String]?, additionalProperties: Bool? = nil, schema: String? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
        self.schema = schema
    }
}

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
