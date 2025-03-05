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

    var body: some View {
        NavigationStack {
            ScrollView {
                Form {
                    Section(header: Text("Server Details")) {
                        TextField("Server Name", text: $server.name)
                        TextField("Command", text: $server.command)

                        VStack(alignment: .leading) {
                            Text("Arguments (one per line)")
                                .font(.headline)
                            TextEditor(text: $argsText)
                                .frame(minHeight: 100)
                                .border(Color.secondary.opacity(0.2))
                                .onChange(of: argsText) { _, _ in
                                    updateServerArgs()
                                }
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
                                    .border(Color.secondary.opacity(0.2))
                                    .font(.system(.body, design: .monospaced))
                                    .onChange(of: envText) { _, _ in
                                        updateServerEnv()
                                    }
                            }
                        } else {
                            let envCount = server.env.count
                            Text(envCount > 0 ? "\(envCount) environment variable\(envCount > 1 ? "s" : "") configured" : "No environment variables")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 400)
            .navigationTitle("Edit Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateServerArgs()
                        updateServerEnv()
                        onSave(server)
                    }
                    .disabled(server.name.isEmpty || server.command.isEmpty)
                }
            }
            .onAppear {
                argsText = server.args.joined(separator: "\n")
                envText = server.env.map { key, value in "\(key)=\(value)" }.joined(separator: "\n")
                showEnvSection = !server.env.isEmpty
            }
        }
        .standardSheet(minHeight: 400)
    }

    private func updateServerArgs() {
        server.args = argsText.split(separator: "\n")
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
    }

    private func updateServerEnv() {
        var envDict = [String: String]()

        envText.split(separator: "\n")
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

        server.env = envDict
    }
}
