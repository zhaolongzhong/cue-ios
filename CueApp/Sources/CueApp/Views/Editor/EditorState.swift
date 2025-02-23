import Foundation

class EditorState: ObservableObject {
    @Published var lines: [EditorLine]
    @Published var selectedLineIndex: Int?
    @Published var content: String {
        didSet {
            updateLines()
        }
    }
    
    init(content: String = "") {
        self.content = content
        self.lines = []
        updateLines()
    }
    
    private func updateLines() {
        let lineStrings = content.components(separatedBy: .newlines)
        lines = lineStrings.enumerated().map { index, text in
            EditorLine(
                text: text,
                number: index + 1,
                isSelected: index == selectedLineIndex
            )
        }
    }
    
    func selectLine(_ index: Int) {
        guard index < lines.count else { return }
        selectedLineIndex = index
        updateLines()
    }
    
    func updateContent(_ newContent: String) {
        content = newContent
    }
}