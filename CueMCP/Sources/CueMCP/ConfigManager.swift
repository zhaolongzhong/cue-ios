import Foundation

public class ConfigManager {
    @MainActor public static let shared = ConfigManager()

    private var bundleConfigPath: String {
        let paths = Bundle.main.paths(forResourcesOfType: "json", inDirectory: nil)
        if let configPath = paths.first(where: { $0.contains("mcp_config.json") }) {
            return configPath
        }
        return ""
    }

    public init() {
        print("📱 Initializing MCP ConfigManager")
        validateBundleConfig()
    }

    private func validateBundleConfig() {
        guard !bundleConfigPath.isEmpty else {
            print("📱 No bundle config found, will use empty config")
            return
        }

        print("📱 Using bundle config at: \(bundleConfigPath)")

        // Validate the bundle config
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: bundleConfigPath))
            let config = try JSONDecoder().decode(MCPServersConfig.self, from: data)
            print("📱 Validated bundle config with \(config.mcpServers.count) servers")
        } catch {
            print("❌ Failed to validate bundle config: \(error)")
        }
    }

    public func getConfigPath() -> String? {
        return bundleConfigPath.isEmpty ? nil : bundleConfigPath
    }

    public func getConfig() -> MCPServersConfig {
        // If we have a valid bundle config, try to use it
        if !bundleConfigPath.isEmpty {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: bundleConfigPath))
                return try JSONDecoder().decode(MCPServersConfig.self, from: data)
            } catch {
                print("❌ Failed to read bundle config: \(error)")
            }
        }

        // Return empty config if no bundle config or on error
        print("📱 Creating empty config")
        return MCPServersConfig(mcpServers: [:])
    }

    public func createDefaultConfig(at url: URL) {
        let config = MCPServersConfig(mcpServers: [:])
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: url)
            print("📱 Created default config file")
        }
    }
}
