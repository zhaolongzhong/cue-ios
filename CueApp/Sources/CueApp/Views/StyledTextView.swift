import SwiftUI

struct StyledTextView: View {
    let content: String
    let colorScheme: ColorScheme

    var codeBackgroundColor: Color {
        colorScheme == .light ?
            Color.black.opacity(0.05) :
            Color.white.opacity(0.1)
    }

    var body: some View {
        styledText(content)
    }

    private func styledText(_ content: String) -> some View {
        let segments = parseInlineStyles(text: content)
        return segments.reduce(Text("")) { result, segment in
            switch segment {
            case .plain(let text):
                return result + Text(text).font(.system(.body))
            case .bold(let text):
                return result + Text(text).bold()
            case .inlineCode(let code):
                let highlightedCode = highlightedCode(colorScheme: colorScheme, language: "", code: code)
                let attributedString = NSMutableAttributedString(attributedString: highlightedCode)

                #if os(macOS)
                let codeFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                #else
                let codeFont = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                #endif

                attributedString.addAttributes([
                    .font: codeFont,
                    .backgroundColor: colorToNative(codeBackgroundColor)
                ], range: NSRange(location: 0, length: attributedString.length))

                return result + Text(AttributedString(attributedString))
            }
        }
        .textSelection(.enabled)
    }

    enum InlineSegment {
        case plain(String)
        case bold(String)
        case inlineCode(String)
    }

    private func parseInlineStyles(text: String) -> [InlineSegment] {
        var segments: [InlineSegment] = []
        var currentIndex = text.startIndex

        let pattern = "\\*\\*(.*?)\\*\\*|`([^`]+)`"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            if let textRange = Range(NSRange(location: NSRange(currentIndex..., in: text).location,
                                           length: match.range.location - NSRange(currentIndex..., in: text).location), in: text) {
                let textContent = String(text[textRange])
                if !textContent.isEmpty {
                    segments.append(.plain(textContent))
                }
            }

            if let boldRange = Range(match.range(at: 1), in: text) {
                segments.append(.bold(String(text[boldRange])))
            } else if let codeRange = Range(match.range(at: 2), in: text) {
                segments.append(.inlineCode(String(text[codeRange])))
            }

            if let matchRange = Range(match.range, in: text) {
                currentIndex = matchRange.upperBound
            }
        }

        if currentIndex < text.endIndex {
            segments.append(.plain(String(text[currentIndex...])))
        }

        return segments
    }

    private func colorToNative(_ color: Color) -> Any {
        #if os(macOS)
        return NSColor(color)
        #else
        return UIColor(color)
        #endif
    }
}