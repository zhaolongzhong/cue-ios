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
    @State private var textFieldHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .primaryLabel()

            ZStack(alignment: .topLeading) {
                TextEditor(text: $argsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: textFieldHeight)
                    .styledTextField()

                if argsText.isEmpty {
                    Text(placeholder)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 10)
                }
            }
            .onChange(of: argsText) { _, newValue in
                args = MCPServerUtils.parseArguments(newValue)
            }

            if let helpText = helpText {
                Text(helpText)
                    .secondaryLabel()
            }
        }
    }
}
