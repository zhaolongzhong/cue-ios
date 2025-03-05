//
//  ArgumentsField.swift
//  CueApp
//
import SwiftUI

struct ArgumentsField: View {
    let title: String
    let placeholder: String
    let helpText: String?

    @Binding var argsText: String
    @Binding var args: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .primaryLabel()

            if #available(macOS 14.0, iOS 17.0, *) {
                // For newer OS versions
                TextField(text: $argsText) {
                    Text(placeholder)
                        .font(.caption)
                }
                .font(.system(.body, design: .monospaced))
                .styledTextField()
                .onChange(of: argsText) { _, newValue in
                    args = MCPServerUtils.parseArguments(newValue)
                }
            } else {
                // For older OS versions
                TextField(placeholder, text: $argsText)
                    .font(.system(.body, design: .monospaced))
                    .styledTextField()
                    .onChange(of: argsText) { newValue in
                        args = MCPServerUtils.parseArguments(newValue)
                    }
            }

            if let helpText = helpText {
                Text(helpText)
                    .secondaryLabel()
            }
        }
    }
}
