//
//  MCPServerEditorModel.swift
//  CueApp
//

import SwiftUI
import CueMCP

struct MCPServerEditorModel: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var command: String
    var args: [String]
    var env: [String: String]

    init(name: String, command: String, args: [String], env: [String: String] = [:]) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
    }

    static func from(name: String, config: MCPServerConfig) -> MCPServerEditorModel {
        return MCPServerEditorModel(
            name: name,
            command: config.command,
            args: config.args,
            env: config.env ?? [:]
        )
    }

    func toServerConfig() -> MCPServerConfig {
        return MCPServerConfig(command: command, args: args, env: env.isEmpty ? nil : env)
    }
}
