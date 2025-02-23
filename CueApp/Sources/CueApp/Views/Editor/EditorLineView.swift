import SwiftUI

struct EditorLineView: View {
    let line: EditorLine
    let theme: EditorTheme
    
    var body: some View {
        HStack(spacing: 0) {
            LineNumberView(
                number: line.number,
                theme: theme,
                isSelected: line.isSelected
            )
            
            Text(line.text)
                .font(theme.font)
                .foregroundColor(theme.textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(line.isSelected ? theme.currentLineColor : theme.backgroundColor)
        }
    }
}