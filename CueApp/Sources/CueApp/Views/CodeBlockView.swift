import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct CodeBlockView: View {
    let language: String
    let code: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(language.isEmpty ? "plaintext" : language.lowercased())
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(colorScheme == .light ? .black : .white).opacity(0.05))

            // Code content
            Text(AttributedString(highlightedCode(colorScheme: colorScheme, language: language, code: code)))
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
        }
        .background(Color(colorScheme == .light ? .black : .white).opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func copyCode() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #else
        UIPasteboard.general.string = code
        #endif
    }
}
