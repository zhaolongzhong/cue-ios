import SwiftUI

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
        Button(action: {
            dismiss()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )

        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        #else
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.plain)
        #endif
    }
}
