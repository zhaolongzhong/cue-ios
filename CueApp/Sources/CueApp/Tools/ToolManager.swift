import Foundation
import Combine
import CueCommon
import CueOpenAI
import CueAnthropic
import CueMCP

@MainActor
public class ToolManager {
    var localTools: [LocalTool] = []
    #if os(macOS)
    let mcpManager: MCPServerManager?
    #endif
    private let mcpToolsSubject = CurrentValueSubject<[MCPTool], Never>([])
    var mcpToolsPublisher: AnyPublisher<[MCPTool], Never> {
        mcpToolsSubject.eraseToAnyPublisher()
    }

    public init(enabledTools: [LocalTool] = []) {
        #if os(macOS)
        self.localTools.append(ScreenshotTool())
        self.mcpManager = MCPServerManager()
        #endif
        self.localTools.append(contentsOf: enabledTools)
    }
    func startMcpServer() async {
        #if os(macOS)
        guard let mcpManager = self.mcpManager else {
            return
        }
        do {
            AppLog.log.debug("📱 Starting MCP servers...")
            try await mcpManager.startAll()
            notifyToolsUpdate()
        } catch {
            AppLog.log.error("❌ Failed to start MCP servers: \(error)")
        }
        #endif
    }

    #if os(macOS)
    private func notifyToolsUpdate() {
        var allTools: [MCPTool] = []
        if let mcpManager = mcpManager {
            for (serverName, tools) in mcpManager.serverTools {
                AppLog.log.debug("Add tools for server: \(serverName)")
                allTools.append(contentsOf: tools)
            }
        }
        mcpToolsSubject.send(allTools)
        AppLog.log.debug("Total mcp tools: \(allTools.count)")
    }

    func getMCPToolsBy(serverName: String) -> [MCPTool] {
        return mcpManager?.serverTools[serverName] ?? []
    }
    #endif

    func getMCPTools() -> [MCPTool] {
        var tools: [MCPTool] = localTools.map { tool in
            let properties = tool.parameterDefinition.schema.mapValues { property in
                return PropertyDetails(
                    type: property.type,
                    title: property.description,
                    items: property.type == "array" ? Items(type: property.items?.type ?? "string") : nil,
                    anyOf: nil,
                    defaultValue: nil
                )
            }
            let inputSchema = InputSchema(
                type: "object", // Default type for parameter schemas
                properties: properties,
                required: tool.parameterDefinition.required
            )
            return MCPTool(
                name: tool.name,
                description: tool.description,
                inputSchema: inputSchema
            )
        }
        #if os(macOS)
        if let mcpTools = mcpManager?.getTools() {
            tools.append(contentsOf: mcpTools)
        }
        #endif
        return tools
    }

    func getTools() -> [Tool] {
        var tools = localTools.map { tool in
            Tool(
                function: .init(
                    name: tool.name,
                    description: tool.description,
                    parameters: .init(
                        properties: tool.parameterDefinition.schema,
                        required: tool.parameterDefinition.required
                    )
                )
            )
        }

        #if os(macOS)
        if let mcpTools = mcpManager?.getOpenAITools() {
            tools.append(contentsOf: mcpTools)
        }
        #endif
        return tools
    }

    private func getToolsJSONValue() -> [JSONValue] {
        do {
            return try getTools().map { try JSONValue(encodable: $0) }
        } catch {
            print("Conversion error: \(error)")
            return []
        }
    }

    func getToolsJSONValue(model: String = ChatModel.gpt4oMini.id) -> [JSONValue] {
        if model.lowercased().contains("claude") {
            let mcpTools = self.getMCPTools()
            return mcpTools.compactMap {
                do {
                    return try JSONValue(encodable: $0)
                } catch {
                    return nil
                }
            }
        } else {
            return self.getToolsJSONValue()
        }
    }

    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let safeArgs = ToolArguments(arguments)
        if let tool = localTools.first(where: { $0.name == name }) {
            AppLog.log.debug("callTool, local tool: \(name), args: \(String(describing: safeArgs))")
            return try await tool.call(safeArgs)
        }

        #if os(macOS)
        guard let mcpManager = mcpManager, mcpManager.hasTool(name: name) == true else {
            throw ToolError.toolNotFound(name)
        }

        let result: MCPCallToolResult = try await mcpManager.callToolByName(name, arguments: safeArgs.toDictionary())
        let isError: Bool = result.isError
        let contents: [MCPContent] = result.content
        var texts = ""
        for content in contents {
            switch content {
            case .text(let textContent):
                texts += "\(textContent.text)"
            case .image:
                break
            }
        }

        let jsonString = """
        {"isError":\(isError),"content":"\(texts.replacingOccurrences(of: "\"", with: "\\\""))"}
        """
        return jsonString
        #else
        throw ToolError.toolNotFound(name)
        #endif
    }

    func callTools(_ toolCalls: [ToolCall]) async -> [OpenAI.ToolMessage] {
        var results: [OpenAI.ToolMessage] = []

        for toolCall in toolCalls {
            do {
                // Parse the arguments using our reusable function
                let args = parseToolArguments(toolCall.function.arguments)

                let result = try await self.callTool(
                    name: toolCall.function.name,
                    arguments: args
                )
                results.append(OpenAI.ToolMessage(
                    role: "tool",
                    content: result,
                    toolCallId: toolCall.id
                ))
            } catch {
                let toolError = ChatError.toolError(error.localizedDescription)
                ErrorLogger.log(toolError)
                results.append(OpenAI.ToolMessage(
                    role: "tool",
                    content: "Error: \(error.localizedDescription)",
                    toolCallId: toolCall.id
                ))
            }
        }

        return results
    }

    func callToolUse(_ toolUseBlock: Anthropic.ToolUseBlock) async -> Anthropic.ToolResultMessage {
        do {
            var arguments: [String: Any] = [:]
            for (key, value) in toolUseBlock.input {
                switch value {
                case .string(let str): arguments[key] = str
                case .int(let int): arguments[key] = int
                case .number(let double): arguments[key] = double
                case .bool(let bool): arguments[key] = bool
                case .array(let arr): arguments[key] = sanitizeForJSON(arr)
                case .object(let dict): arguments[key] = sanitizeForJSON(dict)
                case .null: arguments[key] = NSNull()
                }
            }
            let toolResult = try await callTool(name: toolUseBlock.name, arguments: arguments)
            let result = Anthropic.ToolResultContent(
                isError: false,
                toolUseId: toolUseBlock.id,
                type: "tool_result",
                content: [Anthropic.ContentBlock(content: toolResult)]
            )
            let toolResultMessage = Anthropic.ToolResultMessage(role: "user", content: [result])
            return toolResultMessage
        } catch {
            AppLog.log.error("Tool error: \(error)")
            let result = Anthropic.ToolResultContent(
                isError: false,
                toolUseId: toolUseBlock.id,
                type: "tool_result",
                content: [Anthropic.ContentBlock(content: "Tool error: \(error)")]
            )
            let toolResultMessage = Anthropic.ToolResultMessage(role: "user", content: [result])
            return toolResultMessage
        }
    }

    func handleToolCall(_ toolCalls: [ToolCall]) async -> [OpenAI.ToolMessage] {
        var results: [OpenAI.ToolMessage] = []

        for toolCall in toolCalls {
            do {
                // Parse the arguments using our reusable function
                let args = parseToolArguments(toolCall.function.arguments)

                // Call the tool with the arguments (even if empty)
                let result = try await self.callTool(name: toolCall.function.name, arguments: args)
                results.append(OpenAI.ToolMessage(role: "tool", content: result, toolCallId: toolCall.id))
            } catch {
                results.append(OpenAI.ToolMessage(role: "tool", content: "Error: \(error.localizedDescription)", toolCallId: toolCall.id))
            }
        }

        return results
    }

    func handleToolUse(_ toolBlock: Anthropic.ToolUseBlock) async -> String {
        do {
            var arguments: [String: Any] = [:]
            for (key, value) in toolBlock.input {
                switch value {
                case .string(let str): arguments[key] = str
                case .int(let int): arguments[key] = int
                case .number(let double): arguments[key] = double
                case .bool(let bool): arguments[key] = bool
                case .array(let arr): arguments[key] = sanitizeForJSON(arr)
                case .object(let dict): arguments[key] = sanitizeForJSON(dict)
                case .null: arguments[key] = NSNull()
                }
            }

            let result = try await self.callTool(name: toolBlock.name, arguments: arguments)
            return result

        } catch {
            AppLog.log.error("Tool error: \(error)")
            return "Error: \(error.localizedDescription)"
        }
    }

    private func sanitizeForJSON(_ value: Any) -> Any {
        if let array = value as? [Any] {
            return array.map { sanitizeForJSON($0) }
        } else if let dict = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[key] = sanitizeForJSON(val)
            }
            return result
        } else if value is NSNull || value is String || value is Int ||
                  value is Double || value is Bool || value is NSNumber {
            return value
        } else {
            // Convert non-JSON types to a string representation
            return String(describing: value)
        }
    }

    /// Parses tool call arguments into a dictionary, handling potential issues like incomplete JSON
    /// - Parameter argumentsString: The raw arguments string from a tool call
    /// - Returns: A dictionary of parsed arguments (empty if parsing fails)
    private func parseToolArguments(_ argumentsString: String) -> [String: Any] {
        // Return empty dictionary for empty input
        if argumentsString.isEmpty {
            return [:]
        }

        // Process the arguments string
        var processedArgs = argumentsString

        // Fix incomplete JSON (missing closing brace)
        if processedArgs.contains("{") && !processedArgs.contains("}") {
            processedArgs += "}"
        }

        // Try to parse the JSON
        if let data = processedArgs.data(using: .utf8),
           let parsedArgs = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parsedArgs
        }

        // Return empty dictionary if parsing fails
        return [:]
    }
}

#if os(macOS)
extension MCPServerManager {
    func getOpenAITools() -> [Tool] {
        return serverTools.flatMap { (_, tools) in
            tools.map { tool in
                return tool.toOpenAITool()
            }
        }
    }
}
#endif
