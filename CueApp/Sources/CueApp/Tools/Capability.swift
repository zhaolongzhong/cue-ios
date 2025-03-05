//
//  Capability.swift
//  CueApp
//

import CueMCP
import CueOpenAI

enum Capability: Equatable, Sendable {
    case tool(Tool)
    #if os(macOS)
    case mcpServer(ServerContext)
    #endif

    var name: String {
        switch self {
        case .tool(let tool):
            return tool.name
        #if os(macOS)
        case .mcpServer(let server):
            return server.serverName
        #endif
        }
    }
}
