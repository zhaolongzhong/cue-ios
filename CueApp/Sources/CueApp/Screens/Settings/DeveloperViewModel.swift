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
        toolManager.mcpToolsPublisher
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
        // Get Documents directory URL
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        // Create MCP directory URL
        let mcpFolderURL = documentsURL.appendingPathComponent("MCP", isDirectory: true)

        // Create MCP directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: mcpFolderURL,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil)
        } catch {
            print("Error creating MCP directory: \(error)")
            return
        }

        // Configure save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Create MCP Config"
        savePanel.nameFieldStringValue = "mcp_config.json"
        savePanel.allowedContentTypes = [.json]
        savePanel.directoryURL = mcpFolderURL  // Set initial directory to MCP folder

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
