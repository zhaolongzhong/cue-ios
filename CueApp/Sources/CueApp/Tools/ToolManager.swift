import Foundation
import Combine
import CueCommon
import CueOpenAI
import CueAnthropic
import CueMCP

@MainActor
class ToolManager {
    var localTools: [LocalTool] = []
    #if os(macOS)
    let mcpManager: MCPServerManager?
    #endif
    private let mcpToolsSubject = CurrentValueSubject<[MCPTool], Never>([])
    var mcpToolsPublisher: AnyPublisher<[MCPTool], Never> {
        mcpToolsSubject.eraseToAnyPublisher()
    }

    init() {
        #if os(macOS)
        self.localTools.append(ScreenshotTool())
        self.mcpManager = MCPServerManager()
        #endif
        self.localTools.append(GmailTool())
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
        if mcpManager?.hasTool(name: name) == true {
            let result = try await mcpManager?.callToolByName(name, arguments: safeArgs.toDictionary())
            return String(describing: result)
        }
        #endif

        throw ToolError.toolNotFound(name)
    }

    func callTools(_ toolCalls: [ToolCall]) async -> [OpenAI.ToolMessage] {
        var results: [OpenAI.ToolMessage] = []

        for toolCall in toolCalls {
            if let data = toolCall.function.arguments.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                do {
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
        }

        return results
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
