//
//  EditMCPServerView.swift
//  CueApp
//

import SwiftUI

struct EditMCPServerView: View {
    let serverName: String
    @State var server: MCPServerEditorModel
    let onSave: (MCPServerEditorModel) -> Void
    let onCancel: () -> Void

    @State private var argsText = ""
    @State private var envText = ""
    @State private var showEnvSection = false
    @State private var envVariables: [EnvVariable] = []
    @State private var editorStyle: EnvironmentVariablesSection.EditorStyle = .grid

    var body: some View {
        VStack {
            MacHeader(title: "Edit MCP Server")
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Server details section
                    ServerDetailsSection(
                        serverName: $server.name,
                        command: $server.command
                    )

                    // Arguments section
                    ArgumentsField(
                        title: "Arguments",
                        placeholder: "e.g. -y, linear-mcp-server",
                        helpText: "One argument per line or comma-separated",
                        argsText: $argsText,
                        args: $server.args
                    )

                    // Environment variables section
                    EnvironmentVariablesSection(
                        title: "Environment Variables",
                        style: editorStyle,
                        envVariables: $envVariables,
                        envText: $envText,
                        showSection: $showEnvSection,
                        envDict: $server.env
                    )
                }
                .padding()
            }
            .frame(maxWidth: 400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CancelButton(label: "Cancel (esc)", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    PrimaryActionButton(
                        label: "Save (↩)",
                        isDisabled: server.name.isEmpty || server.command.isEmpty,
                        action: saveServer
                    )
                }
            }
            .onAppear {
                // Initialize the view state
                argsText = server.args.joined(separator: "\n")
                envText = MCPServerUtils.envDictToText(server.env)
                envVariables = MCPServerUtils.dictToEnvVariables(server.env)
                showEnvSection = !server.env.isEmpty
            }
        }
}

    private func saveServer() {
        // In case the text editor is active, make sure to update the model
        if editorStyle == .text {
            server.env = MCPServerUtils.parseEnvVariables(envText)
        } else {
            // In case the grid editor is active
            server.env = MCPServerUtils.envVariablesToDict(envVariables)
        }

        // Make sure arguments are updated
        server.args = MCPServerUtils.parseArguments(argsText)

        onSave(server)
    }
}
