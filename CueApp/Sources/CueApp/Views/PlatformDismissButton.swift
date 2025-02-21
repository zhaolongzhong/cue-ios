import SwiftUI

struct DismissButton: View {
    let action: () -> Void
    var iconSize: CGFloat = 16
    var tappablePadding: CGFloat = 8

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            #if os(iOS)
            Image(systemName: "xmark")
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .padding(tappablePadding)
                .contentShape(Rectangle())
            #else
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color(.windowBackgroundColor).opacity(0.15))
                )
                .contentShape(Circle())
            #endif
        }
        .buttonStyle(.plain)
        .frame(width: 36, height: 36)
        .keyboardShortcut(.cancelAction)
        #if os(macOS)
        .keyboardShortcut(.escape, modifiers: [])
        #endif
    }
}
