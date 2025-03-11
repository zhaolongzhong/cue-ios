import SwiftUI
import Combine

/// A VS Code-like code editor with line numbers and syntax highlighting capabilities
struct CodeEditorView: View {
    @Binding var text: String
    @State private var lineCount: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var editorHeight: CGFloat = 0
    @State private var isEditing: Bool = false
    
    var fontName: String = "Menlo"
    var fontSize: CGFloat = 14
    var showLineNumbers: Bool = true
    var lineNumberWidth: CGFloat = 40
    var highlightCurrentLine: Bool = true
    
    init(text: Binding<String>, 
         fontName: String = "Menlo", 
         fontSize: CGFloat = 14,
         showLineNumbers: Bool = true,
         lineNumberWidth: CGFloat = 40,
         highlightCurrentLine: Bool = true) {
        _text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.showLineNumbers = showLineNumbers
        self.lineNumberWidth = lineNumberWidth
        self.highlightCurrentLine = highlightCurrentLine
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Line numbers column
            if showLineNumbers {
                LineNumbersView(
                    lineCount: lineCount,
                    scrollOffset: $scrollOffset,
                    editorHeight: $editorHeight,
                    fontName: fontName,
                    fontSize: fontSize
                )
                .frame(width: lineNumberWidth)
                .background(Color(.systemGray6))
            }
            
            // Text editor
            CodeTextEditor(
                text: $text,
                lineCount: $lineCount,
                scrollOffset: $scrollOffset,
                editorHeight: $editorHeight,
                isEditing: $isEditing,
                fontName: fontName,
                fontSize: fontSize,
                highlightCurrentLine: highlightCurrentLine
            )
        }
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

/// The text editor component that handles the actual text editing
struct CodeTextEditor: View {
    @Binding var text: String
    @Binding var lineCount: Int
    @Binding var scrollOffset: CGFloat
    @Binding var editorHeight: CGFloat
    @Binding var isEditing: Bool
    
    var fontName: String
    var fontSize: CGFloat
    var highlightCurrentLine: Bool
    
    @State private var textViewHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Use UITextView wrapped in UIViewRepresentable for better performance
                TextViewWrapper(
                    text: $text,
                    lineCount: $lineCount,
                    scrollOffset: $scrollOffset,
                    editorHeight: $editorHeight,
                    isEditing: $isEditing,
                    fontName: fontName,
                    fontSize: fontSize
                )
                .onAppear {
                    self.editorHeight = geometry.size.height
                }
                .onChange(of: geometry.size.height) { newHeight in
                    self.editorHeight = newHeight
                }
            }
        }
    }
}

/// The line numbers column view
struct LineNumbersView: View {
    let lineCount: Int
    @Binding var scrollOffset: CGFloat
    @Binding var editorHeight: CGFloat
    
    var fontName: String
    var fontSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...max(1, lineCount), id: \.self) { line in
                            Text("\(line)")
                                .font(.custom(fontName, size: fontSize))
                                .foregroundColor(.gray)
                                .frame(height: fontSize * 1.4)
                                .padding(.trailing, 4)
                        }
                    }
                    .offset(y: -scrollOffset)
                    .frame(minHeight: editorHeight)
                }
                .disabled(true)
            }
        }
    }
}

/// UITextView wrapper for better text editing
struct TextViewWrapper: UIViewRepresentable {
    @Binding var text: String
    @Binding var lineCount: Int
    @Binding var scrollOffset: CGFloat
    @Binding var editorHeight: CGFloat
    @Binding var isEditing: Bool
    
    var fontName: String
    var fontSize: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        
        // Configure text view appearance
        textView.font = UIFont(name: fontName, size: fontSize)
        textView.backgroundColor = .clear
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        textView.showsVerticalScrollIndicator = true
        
        // Enable code editing features
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        
        // Add padding
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 8)
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update text if it's changed externally (not during editing)
        if textView.text != text && !isEditing {
            textView.text = text
            updateLineCount(text: text)
        }
        
        // Make sure the font is correctly set
        textView.font = UIFont(name: fontName, size: fontSize)
    }
    
    private func updateLineCount(text: String) {
        // Count newlines plus 1 for the last line
        lineCount = text.components(separatedBy: "\n").count
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextViewWrapper
        
        init(_ parent: TextViewWrapper) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // Update text binding
            parent.text = textView.text
            
            // Update line count
            parent.updateLineCount(text: textView.text)
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isEditing = true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isEditing = false
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Update scroll offset for line numbers view
            parent.scrollOffset = scrollView.contentOffset.y
        }
    }
}

// MARK: - Preview
struct CodeEditorView_Previews: PreviewProvider {
    static var previews: some View {
        CodeEditorPreview()
    }
    
    struct CodeEditorPreview: View {
        @State private var code = """
        import SwiftUI
        
        struct ContentView: View {
            var body: some View {
                Text("Hello, World!")
                    .padding()
            }
        }
        
        struct ContentView_Previews: PreviewProvider {
            static var previews: some View {
                ContentView()
            }
        }
        """
        
        var body: some View {
            VStack {
                Text("VS Code-like Editor")
                    .font(.headline)
                
                CodeEditorView(text: $code)
                    .frame(height: 300)
                    .padding()
            }
        }
    }
}