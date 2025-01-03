import SwiftUI

struct DismissButton: View {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            #if os(iOS)
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.almostPrimary)
                .frame(width: 30, height: 30)
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
        .keyboardShortcut(.cancelAction)
        #if os(macOS)
        .keyboardShortcut(.escape, modifiers: [])
        #endif
    }
}

struct DismissDoneButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("Done") {
            dismiss()
        }
        .buttonStyle(.plain)
    }
}
