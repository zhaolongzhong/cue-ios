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

    // Track user-defined config path
    private var userConfigPath: String?

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
        // Return user config path if available, otherwise bundle path
        return userConfigPath ?? (bundleConfigPath.isEmpty ? nil : bundleConfigPath)
    }

    public func getConfig() -> MCPServersConfig {
        // Try to read from user config path first
        if let userPath = userConfigPath {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: userPath))
                return try JSONDecoder().decode(MCPServersConfig.self, from: data)
            } catch {
                print("❌ Failed to read user config: \(error)")
            }
        }

        // Fall back to bundle config
        if !bundleConfigPath.isEmpty {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: bundleConfigPath))
                return try JSONDecoder().decode(MCPServersConfig.self, from: data)
            } catch {
                print("❌ Failed to read bundle config: \(error)")
            }
        }

        // Return empty config if no config or on error
        print("📱 Creating empty config")
        return MCPServersConfig(mcpServers: [:])
    }

    public func createDefaultConfig(at url: URL) {
        let config = MCPServersConfig(mcpServers: [:])
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: url)
            userConfigPath = url.path
            print("📱 Created default config file at \(url.path)")
        } catch {
            print("❌ Failed to create default config: \(error)")
        }
    }

    public func saveConfig(_ config: MCPServersConfig, to path: String) {
        do {
            let url = URL(fileURLWithPath: path)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: url)
            userConfigPath = path
            print("📱 Saved config to \(path)")
        } catch {
            print("❌ Failed to save config: \(error)")
        }
    }
}
