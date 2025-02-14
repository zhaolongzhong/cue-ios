import Foundation
import CueGemini
import CueOpenAI

extension ToolManager {
    func getGeminiTool() -> GeminiTool {
        var functionDeclarations: [FunctionDeclaration] = localTools.map { tool in
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
        AppLog.log.debug("Local tools: \(functionDeclarations.count)")

        #if os(macOS)
        if let mcpTools = mcpManager?.getOpenAITools() {
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
                AppLog.log.debug("Mcp tools: \(convertedMcpTools.count)")
                functionDeclarations.append(contentsOf: convertedMcpTools)
            }
        }
        #endif

        return Tool(functionDeclarations: functionDeclarations)
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
