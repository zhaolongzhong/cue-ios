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
    @State private var envText = ""
    @State private var showEnvSection = false

    var onAdd: (MCPServerEditorModel) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                Form {
                    Section(header: Text("Server Details")) {
                        TextField("Server Name", text: $serverName)
                        TextField("Command", text: $command)
                        VStack(alignment: .leading) {
                            Text("Arguments (one per line)")
                                .font(.headline)
                            TextEditor(text: $argsText)
                                .frame(minHeight: 100)
                                .lineLimit(3)
                                .border(Color.secondary.opacity(0.2))
                        }
                    }

                    Section(header: HStack {
                        Text("Environment Variables")
                        Spacer()
                        Button {
                            showEnvSection.toggle()
                        } label: {
                            Label(showEnvSection ? "Hide" : "Show", systemImage: showEnvSection ? "chevron.up" : "chevron.down")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }) {
                        if showEnvSection {
                            VStack(alignment: .leading) {
                                Text("Environment Variables (KEY=VALUE format, one per line)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $envText)
                                    .frame(minHeight: 100)
                                    .lineLimit(3)
                                    .border(Color.secondary.opacity(0.2))
                                    .font(.system(.body, design: .monospaced))
                            }
                        } else {
                            Text("Click to add environment variables")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 400)
            .navigationTitle("Add MCP Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Server") {
                        let args = argsText.split(separator: "\n")
                            .map {
                                var arg = String($0.trimmingCharacters(in: .whitespacesAndNewlines))
                                // Remove leading and trailing quotes if they exist
                                if (arg.hasPrefix("\"") && arg.hasSuffix("\"")) ||
                                   (arg.hasPrefix("'") && arg.hasSuffix("'")) {
                                    arg = String(arg.dropFirst().dropLast())
                                }
                                return arg.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            .filter { !$0.isEmpty }
                        let env = parseEnvVariables(envText)

                        let newServer = MCPServerEditorModel(
                            name: serverName,
                            command: command,
                            args: args,
                            env: env
                        )
                        onAdd(newServer)
                    }
                    .disabled(serverName.isEmpty || command.isEmpty)
                }
            }
        }
        .standardSheet(minHeight: 400)
    }

    private func parseEnvVariables(_ text: String) -> [String: String] {
        var envDict = [String: String]()

        text.split(separator: "\n")
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }
            .forEach { line in
                let components = line.split(separator: "=", maxSplits: 1)
                if components.count == 2 {
                    var key = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                    var value = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)

                    // Clean up key - remove quotes if present
                    if (key.hasPrefix("\"") && key.hasSuffix("\"")) ||
                       (key.hasPrefix("'") && key.hasSuffix("'")) {
                        key = String(key.dropFirst().dropLast())
                    }

                    // Clean up value - remove quotes if present
                    if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                       (value.hasPrefix("'") && value.hasSuffix("'")) {
                        value = String(value.dropFirst().dropLast())
                    }

                    envDict[key] = value
                }
            }

        return envDict
    }
}
