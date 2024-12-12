import SwiftUI

struct RoundedTextField: View {
    let placeholder: String
    @Binding var text: String
    let isDisabled: Bool
    @FocusState private var isFocused: Bool
    var onSubmit: () async -> Void

    init(
        placeholder: String,
        text: Binding<String>,
        isDisabled: Bool = false,
        onSubmit: @escaping () async -> Void
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isDisabled = isDisabled
        self.onSubmit = onSubmit
    }

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.Colors.tertiaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppTheme.Colors.separator, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .disabled(isDisabled)
            .focused($isFocused)
            .onSubmit {
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task {
                        await onSubmit()
                    }
                }
            }
    }
}
