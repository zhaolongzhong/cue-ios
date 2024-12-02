import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct MessageBubble: View {
    let message: MessageModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var bubbleColor: Color {
        return message.isUser ? AppTheme.Colors.Message.userBubble.opacity(0.2) : AppTheme.Colors.background
    }

    func copyToPasteboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.getText(), forType: .string)
        #else
        UIPasteboard.general.string = message.getText()
        #endif
    }

    var body: some View {
        HStack {

            VStack(spacing: 0) {
                HStack {
                    if message.isUser {
                        Spacer()
                    }
                    MessageBubbleContent(message: message)
                        .padding(.horizontal, message.isUser ? 12 : 8)
                        .padding(.vertical, message.isUser ? 8 : 4)
                        .background(message.isUser ? bubbleColor : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: message.isUser ? 12 : 0))
                        .textSelection(.enabled) 
                    if !message.isUser {
                        Spacer()
                    }
                }
                CopyButton(message: message) {
                    copyToPasteboard()
                }

            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 0)
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        #endif
    }
}

private struct MessageBubbleContent: View {
    let message: MessageModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let text = message.getText()
        let segments = extractSegments(from: text)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(segments.indices, id: \.self) { index in
                switch segments[index] {
                case .text(let content):
                    StyledTextView(content: content, colorScheme: colorScheme)
                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)
                }
            }

        }
    }

    private func copyToPasteboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.getText(), forType: .string)
        #else
        UIPasteboard.general.string = message.getText()
        #endif
    }

    enum MessageSegment {
        case text(String)
        case code(language: String, code: String)
    }

    private func extractSegments(from text: String) -> [MessageSegment] {
        var segments: [MessageSegment] = []
        var currentIndex = text.startIndex

        let pattern = "```([a-zA-Z]*)\\n([\\s\\S]*?)```"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            // Add text before code block
            if let textRange = Range(NSRange(location: NSRange(currentIndex..., in: text).location,
                                           length: match.range.location - NSRange(currentIndex..., in: text).location), in: text) {
                let textContent = String(text[textRange])
                let cleanedContent = textContent.replacingOccurrences(
                    of: "\\n\\s*$",
                    with: "",
                    options: .regularExpression
                )
                if !cleanedContent.isEmpty {
                    segments.append(.text(cleanedContent))
                }
            }

            // Add code block
            if let languageRange = Range(match.range(at: 1), in: text),
               let codeRange = Range(match.range(at: 2), in: text) {
                let language = String(text[languageRange])
                let code = String(text[codeRange])
                segments.append(.code(language: language, code: code))
            }

            if let matchRange = Range(match.range, in: text) {
                currentIndex = matchRange.upperBound
            }
        }

        // Add remaining text, cleaning up extra newlines
        if currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex...])
            if !remainingText.isEmpty {
                let cleanedContent = remainingText.replacingOccurrences(
                    of: "^\\s*\\n+",  // Remove leading newlines
                    with: "",
                    options: .regularExpression
                )
                if !cleanedContent.isEmpty {
                    segments.append(.text(cleanedContent))
                }
            }
        }

        return segments
    }
}
