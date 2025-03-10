import Foundation

#if os(macOS)
struct TextAreaContent: Identifiable, Hashable, Sendable {
    let id: Int
    let content: String
    let size: CGSize
    let selectionRange: NSRange?
    let selectionLines: [String]
    let selectionLinesRange: LineRange?
    let fileName: String?
    let filePath: String?
}

extension TextAreaContent {
    func getTextAreaContext() -> String {
        let selectionLinesXML = self.selectionLines.joined(separator: "\n")
        return """
        <full_content>\(self.content)</full_content>
        <selection_lines>\(selectionLinesXML)</selection_lines>
        """
    }

    var focusedLines: String? {
        guard let lineRange = selectionLinesRange else { return nil }
        if lineRange.startLine == lineRange.endLine {
            return "(\(lineRange.startLine))"
        } else {
            return "(\(lineRange.startLine)-\(lineRange.endLine))"
        }
    }
}
#endif
