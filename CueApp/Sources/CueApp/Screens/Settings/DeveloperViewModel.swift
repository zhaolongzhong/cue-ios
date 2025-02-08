import Foundation
import SwiftUI
import Combine
import CueOpenAI
import CueAnthropic
import CueMCP

@MainActor
class DeveloperViewModel: ObservableObject {
    private let toolManager: ToolManager
    private var cancellables = Set<AnyCancellable>()
    @Published private(set) var configPath: String?
    @Published private(set) var config: MCPServersConfig?
    @Published var availableTools: [Tool] = []

    init() {
        self.toolManager = ToolManager()
        self.configPath = ConfigManager.shared.getConfigPath()
        self.config = ConfigManager.shared.getConfig()
    }

    private func setupToolsSubscription() {
        toolManager.mcptoolsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.availableTools = self.toolManager.getTools()
            }
            .store(in: &cancellables)
    }

    func startServer() async {
        await self.toolManager.startMcpServer()
    }

    func openConfigFile() {
        guard let configPath = configPath else { return }
        #if os(macOS)
        NSWorkspace.shared.selectFile(configPath, inFileViewerRootedAtPath: "")
        #endif
    }

    func createDefaultConfig() {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.title = "Create MCP Config"
        savePanel.nameFieldStringValue = "mcp_config.json"
        savePanel.allowedContentTypes = [.json]

        if savePanel.runModal() == .OK, let url = savePanel.url {
            ConfigManager.shared.createDefaultConfig(at: url)
            self.configPath = url.path
            self.config = ConfigManager.shared.getConfig()
        }
        #endif
    }

    #if os(macOS)
    func getMcpToolsBy(serverName: String) -> [Tool] {
        let tools = toolManager.getMCPToolsBy(serverName: serverName).map { $0.toOpenAITool() }
        return tools
    }
    #endif
}
