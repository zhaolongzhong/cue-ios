import Foundation

public struct MCPServerConfig: Codable, Sendable {
    public let command: String
    public let args: [String]
    public let env: [String: String]?

    public init(command: String, args: [String], env: [String : String]? = nil) {
        self.command = command
        self.args = args
        self.env = env
    }
}

public struct MCPServersConfig: Codable, Sendable {
    public var mcpServers: [String: MCPServerConfig]

    public init(mcpServers: [String : MCPServerConfig]) {
        self.mcpServers = mcpServers
    }
}
