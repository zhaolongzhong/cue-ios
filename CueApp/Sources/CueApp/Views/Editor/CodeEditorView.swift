import SwiftUI

struct CodeEditorView: View {
    @StateObject private var editorState: EditorState
    @Environment(\.colorScheme) private var colorScheme
    
    private var theme: EditorTheme {
        colorScheme == .dark ? .defaultDark : .defaultLight
    }
    
    init(content: String = "") {
        _editorState = StateObject(wrappedValue: EditorState(content: content))
    }
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                ForEach(editorState.lines) { line in
                    EditorLineView(line: line, theme: theme)
                        .onTapGesture {
                            editorState.selectLine(line.number - 1)
                        }
                }
            }
        }
        .background(theme.backgroundColor)
        .overlay(
            TextEditor(text: Binding(
                get: { editorState.content },
                set: { editorState.updateContent($0) }
            ))
            .font(theme.font)
            .opacity(0.1) // Make it almost invisible but still capture input
            .autocapitalization(.none)
            .disableAutocorrection(true)
        )
    }
}