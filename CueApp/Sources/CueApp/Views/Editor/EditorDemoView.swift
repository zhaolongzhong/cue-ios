import SwiftUI

struct EditorDemoView: View {
    let sampleCode = """
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
        CodeEditorView(content: sampleCode)
            .navigationTitle("Code Editor")
    }
}