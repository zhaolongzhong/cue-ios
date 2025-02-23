import SwiftUI

struct EditorTheme {
    let backgroundColor: Color
    let lineNumberColor: Color
    let textColor: Color
    let selectionColor: Color
    let currentLineColor: Color
    let font: Font
    
    static let defaultDark = EditorTheme(
        backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.12),
        lineNumberColor: Color.gray.opacity(0.5),
        textColor: Color.white,
        selectionColor: Color.blue.opacity(0.3),
        currentLineColor: Color(red: 0.15, green: 0.15, blue: 0.15),
        font: .system(size: 14, weight: .regular, design: .monospaced)
    )
    
    static let defaultLight = EditorTheme(
        backgroundColor: Color(red: 0.98, green: 0.98, blue: 0.98),
        lineNumberColor: Color.gray.opacity(0.5),
        textColor: Color.black,
        selectionColor: Color.blue.opacity(0.2),
        currentLineColor: Color(red: 0.95, green: 0.95, blue: 0.95),
        font: .system(size: 14, weight: .regular, design: .monospaced)
    )
}