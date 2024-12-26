import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension MessageBubbleContent {
    enum MessageSegment {
        case text(String)
        case code(language: String, code: String)
    }

    func extractSegments(from text: String) -> [MessageSegment] {
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

struct FullMessageView: View {
    let message: MessageModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Full Message")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding([.top, .horizontal])

            ScrollView {
                MessageBubble(
                    role: message.author.role,
                    content: message.getText(),
                    maxCharacters: message.getText().count,
                    isExpanded: true
                )
                .padding()
            }
            Spacer()
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
