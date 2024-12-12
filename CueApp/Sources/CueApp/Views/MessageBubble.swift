import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    let role: String
    let content: String

    var isUser: Bool {
        return role == "user"
    }

    var bubbleColor: Color {
        return isUser ? AppTheme.Colors.Message.userBubble.opacity(0.2) : AppTheme.Colors.background
    }

    func copyToPasteboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #else
        UIPasteboard.general.string = content
        #endif
    }

    var body: some View {
        HStack(alignment: .top) {
            if isUser {
                Spacer()
            } else {
                avatar.padding(.vertical, 4)
            }
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if isUser {
                        Spacer()
                    }
                    MessageBubbleContent(role: role, content: content)
                        .padding(.horizontal, getHorizontalPadding())
                        .padding(.vertical, isUser ? 10 : 4)
                        .background(isUser ? bubbleColor : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: isUser ? 16 : 0))
                        .textSelection(.enabled)
                    if !isUser {
                        Spacer()
                    }
                }
                HStack(alignment: .top) {
                    if isUser {
                        Spacer()
                    }
                    CopyButton(role: role, content: content, isVisible: isHovering) {
                        copyToPasteboard()
                    }
                    .padding(.horizontal, getHorizontalPadding())
                    if !isUser {
                        Spacer()
                    }
                }

            }
            if !isUser {
                Spacer()
            }

        }
        .padding(.horizontal, 2)
        .padding(.vertical, 0)
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        #endif
    }

    private func getHorizontalPadding() -> CGFloat {
        return isUser ? 14 : 8
    }

    private var avatar: some View {
        Text("~")
            .font(.system(size: 20, weight: .light, design: .monospaced))
            .foregroundColor(isUser ? .blue : .gray)
            .frame(width: 22, height: 22)
            .background(
                Circle()
                    .stroke(lineWidth: 1)
                    .opacity(0.5)
            )
    }
}

private struct MessageBubbleContent: View {
    @Environment(\.colorScheme) private var colorScheme
    let role: String
    let content: String

    var body: some View {
        let text = content
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
        NSPasteboard.general.setString(content, forType: .string)
        #else
        UIPasteboard.general.string = content
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
