import SwiftUI

/// A demo view showcasing the VS Code-like code editor
struct CodeEditorDemoView: View {
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
    
    @State private var fileName = "ContentView.swift"
    @State private var fontSize: CGFloat = 14
    @State private var showLineNumbers = true
    @State private var highlightCurrentLine = true
    
    var body: some View {
        VStack(spacing: 12) {
            // Editor header with filename
            HStack {
                Text(fileName)
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Save", action: saveCode)
                    Divider()
                    Button("Increase Font", action: increaseFontSize)
                    Button("Decrease Font", action: decreaseFontSize)
                    Divider()
                    Toggle("Show Line Numbers", isOn: $showLineNumbers)
                    Toggle("Highlight Current Line", isOn: $highlightCurrentLine)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            
            // Code editor
            CodeEditorView(
                text: $code,
                fontSize: fontSize,
                showLineNumbers: showLineNumbers,
                highlightCurrentLine: highlightCurrentLine
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Status bar
            HStack {
                Text("Lines: \(code.components(separatedBy: "\n").count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Swift")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Size: \(Int(fontSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
        }
        .background(Color(.systemBackground))
    }
    
    private func saveCode() {
        // In a real app, this would save to a file
        print("Saving code...")
    }
    
    private func increaseFontSize() {
        fontSize = min(fontSize + 1, 24)
    }
    
    private func decreaseFontSize() {
        fontSize = max(fontSize - 1, 10)
    }
}

struct CodeEditorDemoView_Previews: PreviewProvider {
    static var previews: some View {
        CodeEditorDemoView()
    }
}