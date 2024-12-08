import SwiftUI

struct TextEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State private var editedText: String
    let onSave: (String) -> Void

    init(title: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self._editedText = State(initialValue: initialText)
        self.onSave = onSave
    }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            mainContent
        }
        #else
        mainContent
            .frame(minWidth: 400, minHeight: 300)
        #endif
    }

    private var mainContent: some View {
        TextEditor(text: $editedText)
            .padding()
            #if os(macOS)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editedText)
                        dismiss()
                    }
                }
            }
    }
}

// View extension to provide the textFieldEditor modifier
extension View {
    func textFieldEditor(
        title: String,
        text: Binding<String>,
        isPresented: Binding<Bool>,
        onSave: @escaping (String) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            TextEditSheet(
                title: title,
                initialText: text.wrappedValue,
                onSave: { newValue in
                    text.wrappedValue = newValue
                    onSave(newValue)
                }
            )
        }
    }
}

// Helper view for labeled text
struct LabeledTextView: View {
    let label: String
    let text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                Text(text.isEmpty ? placeholder : text)
                    .font(.body)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
            }
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(text.isEmpty ? placeholder : text)")
        .accessibilityHint(text.isEmpty ? "Double tap to edit" : "Double tap to edit current text")
    }
}
