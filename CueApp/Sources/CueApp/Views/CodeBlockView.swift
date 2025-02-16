import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct CodeBlockView: View {
    let language: String
    let code: String
    let hideHeader: Bool
    @Environment(\.colorScheme) private var colorScheme

    public init(
        language: String = "",
        code: String,
        hideHeader: Bool = false
    ) {
        self.language = language
        self.code = code
        self.hideHeader = hideHeader
    }

    var body: some View {
        VStack(spacing: 0) {
            if !hideHeader {
                HStack {
                    Text(language.isEmpty ? "plaintext" : language.lowercased())
                    Spacer()
                    CopyCodeButton(code: code)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(height: 32)
                .background(Color(colorScheme == .light ? .black.opacity(0.06) : .white.opacity(0.03)))
            }

            Text(AttributedString(SyntaxHighlighter.highlightedCode(colorScheme: colorScheme, language: language, code: code)))
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
                .background(
                    colorScheme == .light
                        ? Color(red: 0.92, green: 0.92, blue: 0.92)
                        : Color(red: 0.12, green: 0.12, blue: 0.12)
                )
        }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(lineWidth: 0.5).opacity(0.5))
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

struct CopyCodeButton: View {
    let code: String
    @State private var showCopiedFeedback = false
    @State private var isPressed = false

    var body: some View {
        Button(
            action: {
                // Trigger press animation
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }

                // Copy code
                copyCode()

                // Show feedback
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopiedFeedback = true
                }

                // Reset states after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCopiedFeedback = false
                    }
                }
            },
            label: {
                HStack(spacing: 4) {
                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                    Text(showCopiedFeedback ? "Copied!" : "Copy")
                }
                .foregroundStyle(.primary.opacity(0.8))
                .font(.system(size: 12))
                .frame(width: 65, height: 16)
                .scaleEffect(isPressed ? 0.8 : 1.0)
            }
        )
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
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
