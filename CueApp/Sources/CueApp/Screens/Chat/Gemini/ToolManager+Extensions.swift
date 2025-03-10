import Foundation
import CueGemini
import CueOpenAI

extension ToolManager {
    func getGeminiTool() -> GeminiTool? {
        var functionDeclarations: [FunctionDeclaration] = localTools.compactMap { tool in
            // Convert local tool properties to Schema dictionary
            let parameters: [String: Schema] = tool.parameterDefinition.schema.mapValues { localProperty in
                Schema(
                    type: convertToDataType(localProperty.type),
                    description: localProperty.description,
                    items: localProperty.items.map { items in
                        Schema(type: convertToDataType(items.type))
                    }
                )
            }

            return FunctionDeclaration(
                name: tool.name,
                description: tool.description,
                parameters: parameters,
                requiredParameters: tool.parameterDefinition.required
            )
        }

        AppLog.log.debug("Local tools before validation: \(functionDeclarations.count)")

        #if os(macOS)
        let mcpTools = mcpManager.getOpenAITools()
        let convertedMcpTools = mcpTools.map { openAITool in
            // Convert OpenAI properties to Schema dictionary
            let parameters: [String: Schema] = openAITool.function.parameters.properties.mapValues { property in
                Schema(
                    type: convertToDataType(property.type),
                    description: property.description,
                    items: property.items.map { items in
                        Schema(type: convertToDataType(items.type))
                    }
                )
            }

            return FunctionDeclaration(
                name: openAITool.function.name,
                description: openAITool.function.description,
                parameters: parameters,
                requiredParameters: openAITool.function.parameters.required
            )
        }

        if convertedMcpTools.count > 0 {
            AppLog.log.debug("Mcp tools before validation: \(convertedMcpTools.count)")
            functionDeclarations.append(contentsOf: convertedMcpTools)
        }
        #endif

        // Validate all function declarations before creating the tool
        let validatedDeclarations = validateFunctionDeclarations(functionDeclarations)
        AppLog.log.debug("Valid function declarations: \(validatedDeclarations.count)")
        if validatedDeclarations.isEmpty {
            return nil
        }
        return Tool(functionDeclarations: validatedDeclarations)
    }

    func validateFunctionDeclarations(_ declarations: [FunctionDeclaration]) -> [FunctionDeclaration] {
        return declarations.map { declaration in
            print("Validating function: \(declaration.name), parameters: \(String(describing: declaration.parameters))")

            // Check for the specific issue with empty properties
            if let parameters = declaration.parameters {
                if parameters.type == .object && (parameters.properties == nil || parameters.properties?.isEmpty == true) {
                    // Instead of skipping, create a new declaration with a placeholder property
                    AppLog.log.debug("Adding placeholder property to function \(declaration.name)")

                    // Create a dictionary with placeholder property
                    let fixedProperties: [String: Schema] = [
                        "_placeholder": Schema(type: .string, description: "Placeholder property")
                    ]

                    // Return a new declaration with the fixed properties
                    return FunctionDeclaration(
                        name: declaration.name,
                        description: declaration.description,
                        parameters: fixedProperties,
                        requiredParameters: parameters.requiredProperties
                    )
                }

                // Check for array items of object type with empty properties
                if let properties = parameters.properties {
                    var needsFixing = false
                    var fixedProperties: [String: Schema] = [:]

                    for (key, schema) in properties {
                        if schema.type == .array, let items = schema.items, items.type == .object,
                        items.properties == nil || items.properties?.isEmpty == true {
                            AppLog.log.debug("Adding placeholder property to array items in function \(declaration.name), parameter \(key)")
                            // Create a fixed schema for the array items with placeholder property
                            let fixedItemsSchema = Schema(
                                type: .object,
                                properties: ["_placeholder": Schema(type: .string, description: "Placeholder property")]
                            )

                            // Create a fixed schema for the array
                            let fixedArraySchema = Schema(
                                type: .array,
                                description: schema.description,
                                items: fixedItemsSchema
                            )

                            fixedProperties[key] = fixedArraySchema
                            needsFixing = true
                        } else {
                            fixedProperties[key] = schema
                        }
                    }

                    if needsFixing {
                        // Return a new declaration with fixed properties
                        return FunctionDeclaration(
                            name: declaration.name,
                            description: declaration.description,
                            parameters: fixedProperties,
                            requiredParameters: parameters.requiredProperties
                        )
                    }
                }
            }

            // If no fixes needed, return the original declaration
            return declaration
        }
    }

    private func convertToDataType(_ type: String) -> DataType {
        switch type.lowercased() {
        case "string": return .string
        case "number": return .number
        case "integer": return .integer
        case "boolean": return .boolean
        case "array": return .array
        case "object": return .object
        default: return .string
        }
    }
}
