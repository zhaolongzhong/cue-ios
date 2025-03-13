//
//  Capability.swift
//  CueApp
//

import CueMCP
import CueOpenAI

enum Capability: Sendable {
    case localTool(Tool)
    case tool(Tool)
    #if os(macOS)
    case mcpServer(ServerContext)
    #endif

    var name: String {
        switch self {
        case .localTool(let tool):
            return tool.name
        case .tool(let tool):
            return tool.name
        #if os(macOS)
        case .mcpServer(let server):
            return server.serverName
        #endif
        }
    }

    var isBuiltIn: Bool {
        if case .localTool = self {
            return true
        }
        return false
    }

    var isMCPServer: Bool {
        #if os(macOS)
        if case .mcpServer = self {
            return true
        }
        return false
        #else
            return false
        #endif
    }
}

extension Capability: Equatable {
    static func == (lhs: Capability, rhs: Capability) -> Bool {
        return lhs.name == rhs.name
    }
}
