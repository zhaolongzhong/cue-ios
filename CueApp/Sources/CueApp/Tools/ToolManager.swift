import Foundation
import CueOpenAI

@MainActor
class ToolManager {
    private let localTools: [LocalTool]

    init() {
        self.localTools = [
            WeatherTool(),
            ScreenshotTool()
        ]
    }

    func getTools() -> [Tool] {
        let tools = localTools.map { tool in
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

        return tools
    }

    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        let safeArgs = ToolArguments(arguments)

        if let tool = localTools.first(where: { $0.name == name }) {
            return try await tool.call(safeArgs)
        }
        throw ToolError.toolNotFound(name)
    }
}
