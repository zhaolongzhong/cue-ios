import SwiftUI

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(action: {
            dismiss()
        }) {

            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                )
                .frame(width: 36, height: 36, alignment: .center)
                .contentShape(Rectangle())

        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
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