//
//  AddMCPServerView.swift
//  CueApp
//

import SwiftUI

struct AddMCPServerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var serverName = ""
    @State private var command = ""
    @State private var argsText = ""
    @State private var args: [String] = []
    @State private var showEnvSection = false
    @State private var envVariables: [EnvVariable] = []
    @State private var env: [String: String] = [:]

    var onAdd: (MCPServerEditorModel) -> Void

    var body: some View {
        VStack {
            MacHeader(title: "Add MCP Server")
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Server details section
                    ServerDetailsSection(
                        serverName: $serverName,
                        command: $command
                    )

                    // Arguments section
                    ArgumentsField(
                        title: "Arguments",
                        placeholder: "e.g. -y, linear-mcp-server",
                        helpText: "One argument per line or comma-separated",
                        argsText: $argsText,
                        args: $args
                    )

                    // Environment variables section
                    EnvironmentVariablesSection(
                        title: "Environment Variables",
                        envVariables: $envVariables,
                        envText: .constant(""),
                        showSection: $showEnvSection,
                        envDict: $env
                    )
                }
                .padding()
            }
            .frame(maxWidth: 400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CancelButton(label: "Cancel (esc)", action: { dismiss() })
                }

                ToolbarItem(placement: .confirmationAction) {
                    PrimaryActionButton(
                        label: "Add (↩)",
                        isDisabled: serverName.isEmpty || command.isEmpty,
                        action: addServer
                    )
                }
            }
        }
    }

    private func addServer() {
        let newServer = MCPServerEditorModel(
            name: serverName,
            command: command,
            args: args,
            env: env
        )
        onAdd(newServer)
    }
}
