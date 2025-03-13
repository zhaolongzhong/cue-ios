import Foundation
import Combine
import CueOpenAI
import CueAnthropic
import CueMCP

#if os(macOS)
import AppKit
#endif

@MainActor
class MCPServersViewModel: ObservableObject {
    private let toolManager: ToolManager
    private var cancellables = Set<AnyCancellable>()
    @Published private(set) var configPath: String?
    @Published private(set) var config: MCPServersConfig?
    @Published var availableCapabilities: [Capability] = []

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
                self.availableCapabilities = self.toolManager.getMCPCapabilities()
            }
            .store(in: &cancellables)
    }

    func startServer() async {
        AppLog.log.debug("Starting MCP server")
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

        let mcpFolderURL = documentsURL.appendingPathComponent("MCP", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: mcpFolderURL,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil)
        } catch {
            print("Error creating MCP directory: \(error)")
            return
        }

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

    func updateConfig(servers: [MCPServerEditorModel]) {
        guard let configPath = configPath else { return }

        var updatedConfig = MCPServersConfig(mcpServers: [:])

        for server in servers {
            updatedConfig.mcpServers[server.name] = server.toServerConfig()
        }

        ConfigManager.shared.saveConfig(updatedConfig, to: configPath)
        refreshConfig()
    }

    func deleteServer(named serverName: String) {
        guard let configPath = configPath, var config = self.config else { return }

        // Remove server from config
        config.mcpServers.removeValue(forKey: serverName)

        // Save updated config
        ConfigManager.shared.saveConfig(config, to: configPath)
        refreshConfig()
    }

    func getServersAsEditorModels() -> [MCPServerEditorModel] {
        guard let config = config else { return [] }

        return config.mcpServers.map { name, serverConfig in
            MCPServerEditorModel.from(name: name, config: serverConfig)
        }
    }

    func refreshConfig() {
        self.configPath = ConfigManager.shared.getConfigPath()
        self.config = ConfigManager.shared.getConfig()
        Task {
            await self.toolManager.startMcpServer(forceRestart: true)
        }
    }

    func getMCPCapabilities() -> [Capability] {
        return toolManager.getMCPCapabilities()
    }

    func getMCPTools(by capability: Capability) -> [Tool] {
        switch capability {
        #if os(macOS)
        case .mcpServer(let serverContext):
            let tools = toolManager.getMCPToolsBy(serverName: serverContext.serverName).map { $0.toOpenAITool() }
            return tools
        #endif
        default:
            return []
        }
    }

    #if os(macOS)
    func getMcpToolsBy(serverName: String) -> [Tool] {
        let tools = toolManager.getMCPToolsBy(serverName: serverName).map { $0.toOpenAITool() }
        return tools
    }
    #endif
}
