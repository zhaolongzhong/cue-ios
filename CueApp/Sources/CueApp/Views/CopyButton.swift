import SwiftUI

struct CopyButton: View {
    let content: String
    let isVisible: Bool
    var copyAction: (() -> Void)?

    @State private var isPressed = false
    @State private var showCopiedFeedback = false

    var body: some View {
        Button(action: {
            // Trigger press animation
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }

            // Execute copy action
            copyToPasteboard(content)
            copyAction?()

            // Show copied feedback
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedFeedback = true
            }

            // Reset states after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopiedFeedback = false
                }
            }
        }) {
            ZStack {
                // Copy icon
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(showCopiedFeedback ? 0 : 0.6))
                    .scaleEffect(isPressed ? 0.8 : 1.0)

                // Checkmark feedback
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .opacity(showCopiedFeedback ? 1 : 0)
                    .scaleEffect(showCopiedFeedback ? 1 : 0.5)
            }
        }
        .buttonStyle(BorderlessButtonStyle())
        .opacity(isVisible ? 1 : 0)
        .frame(width: 18, height: 18)
    }
}
