import SwiftUI

struct LineNumberView: View {
    let number: Int
    let theme: EditorTheme
    let isSelected: Bool
    
    var body: some View {
        Text("\(number)")
            .font(theme.font)
            .foregroundColor(theme.lineNumberColor)
            .frame(width: 40, alignment: .trailing)
            .padding(.trailing, 8)
            .background(isSelected ? theme.currentLineColor : theme.backgroundColor)
    }
}