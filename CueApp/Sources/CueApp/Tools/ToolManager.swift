import Foundation
import CueOpenAI

@MainActor
class ToolManager {
    private let localTools: [LocalTool]
    private let mcpManager: MCPServerManager?

    init() {
        self.localTools = [
            WeatherTool(),
            ScreenshotTool()
        ]
        #if os(macOS)
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
        } catch {
            AppLog.log.error("❌ Failed to start MCP servers: \(error)")
        }
        #endif
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

extension MCPServerManager {
    func getToolsJSON() -> [Tool] {
        return serverTools.flatMap { (_, tools) in
            tools.map { tool in
                return tool.toOpenAITool()
            }
        }
    }
}
