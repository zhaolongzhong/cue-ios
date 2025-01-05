import Foundation
import CueOpenAI
import Combine

@MainActor
class ToolManager {
    private var localTools: [LocalTool]
    #if os(macOS)
    private let mcpManager: MCPServerManager?
    #endif
    private let mcpToolsSubject = CurrentValueSubject<[MCPTool], Never>([])
    var mcptoolsPublisher: AnyPublisher<[MCPTool], Never> {
        mcpToolsSubject.eraseToAnyPublisher()
    }

    init() {
        self.localTools = [
            WeatherTool()
        ]
        #if os(macOS)
        self.localTools.append(ScreenshotTool())
        self.mcpManager = MCPServerManager()
        #endif
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
        if let mcpTools = mcpManager?.getToolsJSON() {
            tools.append(contentsOf: mcpTools)
        }
        #endif
        return tools
    }

    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let safeArgs = ToolArguments(arguments)
        if let tool = localTools.first(where: { $0.name == name }) {
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
}

#if os(macOS)
extension MCPServerManager {
    func getToolsJSON() -> [Tool] {
        return serverTools.flatMap { (_, tools) in
            tools.map { tool in
                return tool.toOpenAITool()
            }
        }
    }
}
#endif
