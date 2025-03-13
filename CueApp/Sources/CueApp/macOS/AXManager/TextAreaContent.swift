import Foundation

struct LineRange: Codable, Hashable, Sendable {
    let startLine: Int
    let endLine: Int
}

struct TextAreaContent: Identifiable, Hashable, Sendable {
    let id: Int
    let content: String
    let size: CGSize
    let selectionRange: NSRange?
    let selectionLines: [String]
    let selectionLinesRange: LineRange?
    let fileName: String?
    let filePath: String?
    let app: AccessibleApplication
}

extension TextAreaContent {
    func getTextAreaContext() -> String {
        let selectionLinesXML = self.selectionLines.joined(separator: "\n")
        return """
        <file_name>\(fileName ?? "Not found")</file_name>
        <file_path>\(filePath ?? "Not found")</file_path>
        <full_content>\(self.content)</full_content>
        <selection_lines>\(selectionLinesXML)</selection_lines>
        <editor_info>\(app.name)</editor_info>
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
