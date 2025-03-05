//
//  EnvironmentVariablesSection.swift
//  CueApp
//

import SwiftUI

/// Environment variables editor with two different styles - grid or text
struct EnvironmentVariablesSection: View {
    enum EditorStyle {
        case grid   // Key-value pairs in grid style
        case text   // Text editor with KEY=VALUE format
    }

    let title: String
    let style: EditorStyle

    @Binding var envVariables: [EnvVariable]
    @Binding var envText: String
    @Binding var showSection: Bool
    @Binding var envDict: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .primaryLabel()
                Spacer()
                Button {
                    showSection.toggle()
                    // If opening the section and no variables exist yet, add an empty one
                    if showSection && style == .grid && envVariables.isEmpty {
                        envVariables.append(EnvVariable())
                    }
                } label: {
                    Image(systemName: showSection ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
            }
            .padding(.bottom, 2)

            if showSection {
                if style == .grid {
                    gridEditor
                } else {
                    textEditor
                }
            } else {
                Button {
                    showSection.toggle()
                    // If opening the section and no variables exist yet, add an empty one
                    if style == .grid && envVariables.isEmpty {
                        envVariables.append(EnvVariable())
                    }
                } label: {
                    Text("Tap to add environment variables")
                        .secondaryLabel()
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // Grid editor (key-value pairs in grid form)
    private var gridEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(envVariables.enumerated()), id: \.element.id) { index, _ in
                envVariableRow(forIndex: index)
            }

            Button {
                envVariables.append(EnvVariable())
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add")
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderless)
        }
        .onChange(of: envVariables) { _, newValue in
            // Update dictionary when array changes
            envDict = MCPServerUtils.envVariablesToDict(newValue)
        }
    }

    // Text editor (KEY=VALUE format)
    private var textEditor: some View {
        VStack(alignment: .leading) {
            Text("Environment Variables (KEY=VALUE format, one per line)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextEditor(text: $envText)
                .frame(minHeight: 100)
                .border(Color.secondary.opacity(0.2))
                .font(.system(.body, design: .monospaced))
                .onChange(of: envText) { _, newValue in
                    // Update dictionary when text changes
                    envDict = MCPServerUtils.parseEnvVariables(newValue)
                    // Update array when text changes
                    envVariables = MCPServerUtils.dictToEnvVariables(envDict)
                }
        }
    }

    private func envVariableRow(forIndex index: Int) -> some View {
        HStack(spacing: 8) {
            // Key field
            TextField("KEY", text: $envVariables[index].key)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(6)
                .frame(minWidth: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            Text("=")
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            // Value field
            TextField("VALUE", text: $envVariables[index].value)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            // Delete button
            Button {
                envVariables.remove(at: index)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.borderless)
            .opacity(envVariables.count > 1 ? 1 : 0)
        }
    }
}
