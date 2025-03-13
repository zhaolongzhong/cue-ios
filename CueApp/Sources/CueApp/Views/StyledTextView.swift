import SwiftUI
import os

struct StyledTextView: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: String
    let maxCharacters: Int
    let isExpanded: Bool
    let onShowMore: (() -> Void)?

    private var markdownHighlighter: MarkdownHighlighter {
        MarkdownHighlighter(colorScheme: colorScheme)
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

    private let logger = Logger(subsystem: "StyledTextView", category: "StyledTextView")

    init(content: String, maxCharacters: Int = 500, isExpanded: Bool = true, onShowMore: (() -> Void)? = nil) {
        self.content = content
        self.maxCharacters = maxCharacters
        self.isExpanded = isExpanded
        self.onShowMore = onShowMore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AttributedString(markdownHighlighter.process(truncatedContent)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(0)
                .textSelection(.enabled)
                .lineSpacing(8)
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
}
