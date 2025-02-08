import Foundation

#if os(macOS)
struct TextAreaContent {
    let id: Int
    let content: String
    let size: CGSize
    let selectionRange: NSRange?
    let selectionLines: [String]
    let selectionLinesRange: LineRange?
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
            return "Focused on line \(lineRange.startLine)"
        } else {
            return "Focused on lines \(lineRange.startLine)-\(lineRange.endLine)"
        }
    }
}
#endif
