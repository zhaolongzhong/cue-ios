#if os(macOS)
extension MCPServerManager {
    /// Get all tools from all initialized servers
    func getTools() -> [MCPTool] {
        // Flatten all server tools into a single array
        return serverTools.values.flatMap { $0 }
    }

    /// Check if a tool with the given name exists in any server
    func hasTool(name: String) -> Bool {
        // Search through all servers' tools
        return serverTools.values.contains { tools in
            tools.contains { tool in
                tool.name == name
            }
        }
    }

    /// Get the server name that provides a specific tool
    func getServerForTool(name: String) -> String? {
        for (serverName, tools) in serverTools {
            if tools.contains(where: { $0.name == name }) {
                return serverName
            }
        }
        return nil
    }

    /// Get a specific tool by name
    func getTool(name: String) -> MCPTool? {
        for tools in serverTools.values {
            if let tool = tools.first(where: { $0.name == name }) {
                return tool
            }
        }
        return nil
    }

    func getToolsDictionary() -> [[String: Any]] {
        return serverTools.flatMap { (serverName, tools) in
            tools.map { tool in
                tool.toDictionary(serverName: serverName)
            }
        }
    }
}

// MARK: - Tool Management Helper Methods

extension MCPServerManager {
    /// Update tools for a specific server
    @MainActor
    func updateServerTools(_ server: String) async throws {
        if let tools = try? await listServerTools(server) {
            serverTools[server] = tools
        }
    }

    /// Update tools for all active servers
    @MainActor
    func refreshAllTools() async {
        for serverName in servers.keys {
            try? await updateServerTools(serverName)
        }
    }

    /// Call a tool by name with provided arguments
    @MainActor
    func callToolByName(_ name: String, arguments: [String: Any]) async throws -> MCPCallToolResult {
        guard let serverName = getServerForTool(name: name) else {
            throw MCPServerError.toolNotFound(name)
        }

        return try await callToolWithResult(serverName, name: name, arguments: arguments)
    }
}

// MARK: - Additional Error Cases

extension MCPServerError {
    static func toolNotFound(_ name: String) -> MCPServerError {
        return .invalidConfig("Tool not found: \(name)")
    }
}
#endif
