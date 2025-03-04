import SwiftUI

struct StyledTextView: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: String
    let maxCharacters: Int
    let isExpanded: Bool
    let onShowMore: (() -> Void)?

    #if os(iOS)
    let defaultFont = UIFont(name: "SF Mono", size: 13) ?? UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    #elseif os(macOS)
    let defaultFont = NSFont(name: "SF Mono", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    #endif

    init(content: String, maxCharacters: Int = 500, isExpanded: Bool = true, onShowMore: (() -> Void)? = nil) {
        self.content = content
        self.maxCharacters = maxCharacters
        self.isExpanded = isExpanded
        self.onShowMore = onShowMore
    }

    var codeBackgroundColor: Color {
        colorScheme == .light ?
            Color.black.opacity(0.05) :
            Color.white.opacity(0.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            styledText(truncatedContent)
            if isTruncated, let onShowMore = onShowMore {
                Button(action: onShowMore) {
                    Text("Show More")
                        .font(.system(.callout))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private var isTruncated: Bool {
        content.count > maxCharacters && !isExpanded
    }

    private var truncatedContent: String {
        if isTruncated {
            let index = content.index(content.startIndex, offsetBy: maxCharacters, limitedBy: content.endIndex) ?? content.endIndex
            return String(content[..<index])
        } else {
            return content
        }
    }

    private func styledText(_ content: String) -> some View {
        // Pre-process content to convert dash bullet points to dot bullet points
        let processedContent = convertDashesToDots(content)

        // Parse content for different markdown styles
        let segments = parseMarkdownStyles(text: processedContent)

        return segments.reduce(Text("")) { result, segment in
            switch segment {
            case .plain(let text):
                return result + Text(text).font(.body).foregroundColor(colorScheme == .dark ? .white : .black)
            case .bold(let text):
                return result + Text(text).bold().foregroundColor(colorScheme == .dark ? .white : .black)
            case .inlineCode(let code):
                let highlightedCode = SyntaxHighlighter.highlightedCode(colorScheme: colorScheme, language: "", code: code)
                let attributedString = NSMutableAttributedString(attributedString: highlightedCode)

                attributedString.addAttributes([
                    .font: defaultFont,
                    .backgroundColor: colorToNative(codeBackgroundColor)
                ], range: NSRange(location: 0, length: attributedString.length))

                return result + Text(AttributedString(attributedString))
            case .header1(let text):
                return result + Text(text).font(.title).bold().foregroundColor(colorScheme == .dark ? .white : .black)
            case .header2(let text):
                return result + Text(text).font(.title2).bold().foregroundColor(colorScheme == .dark ? .white : .black)
            case .header3(let text):
                return result + Text(text).font(.title3).bold().foregroundColor(colorScheme == .dark ? .white : .black)
            case .bulletPoint:
                return result + Text("• ").font(.body).foregroundColor(colorScheme == .dark ? .white : .black)
            }
        }
        .textSelection(.enabled)
    }

    enum MarkdownSegment {
        case plain(String)
        case bold(String)
        case inlineCode(String)
        case header1(String)
        case header2(String)
        case header3(String)
        case bulletPoint(String)
    }

    // Convert dash bullet points to dot bullet points
    private func convertDashesToDots(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let processedLines = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "- ") {
                // Convert directly using the trimmed line, then preserve leading whitespace
                let leadingWhitespace = String(line.prefix(while: { $0.isWhitespace }))
                return leadingWhitespace + "• " + String(trimmed.dropFirst(2))
            }
            return String(line)
        }
        return processedLines.joined(separator: "\n")
    }

    private func parseMarkdownStyles(text: String) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for headers
            if trimmedLine.starts(with: "# ") {
                let headerText = String(trimmedLine.dropFirst(2))
                segments.append(.header1(headerText))
            } else if trimmedLine.starts(with: "## ") {
                let headerText = String(trimmedLine.dropFirst(3))
                segments.append(.header2(headerText))
            } else if trimmedLine.starts(with: "### ") {
                let headerText = String(trimmedLine.dropFirst(4))
                segments.append(.header3(headerText))
            }
            // Check for bullet points - using trimmedLine for safer handling
            else if trimmedLine.starts(with: "• ") {
                // Add the bullet point marker
                segments.append(.bulletPoint(""))

                // Safely extract the content after the bullet point using the trimmed line
                let bulletContent = String(trimmedLine.dropFirst(2))

                // Process inline styles within the bullet point content
                let inlineSegments = parseInlineStyles(text: bulletContent)
                segments.append(contentsOf: inlineSegments)
            }
            // Process inline styles
            else {
                let inlineSegments = parseInlineStyles(text: String(line))
                segments.append(contentsOf: inlineSegments)

                // Add a newline after each line except the last one
                if line != lines.last {
                    segments.append(.plain("\n"))
                }
            }
        }

        return segments
    }

    private func parseInlineStyles(text: String) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        var currentIndex = text.startIndex

        let pattern = "\\*\\*(.*?)\\*\\*|`([^`]+)`"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            if let plainRange = Range(NSRange(location: currentIndex.utf16Offset(in: text), length: match.range.location - currentIndex.utf16Offset(in: text)), in: text) {
                let textContent = String(text[plainRange])
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
