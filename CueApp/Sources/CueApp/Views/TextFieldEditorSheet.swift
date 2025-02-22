import SwiftUI

struct TextFieldEditorSheet: View {
    let title: String
    @Binding var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        navigationView
        #else
        macOSView
        #endif
    }

    private var navigationView: some View {
        NavigationView {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(.all, 8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
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
                            onSave(text)
                            dismiss()
                        }
                    }
                }
                .padding(.all, 8)
        }
    }

    private var macOSView: some View {
        VStack {
            #if os(macOS)
            MacHeader(
                title: title,
                onDismiss: { dismiss() }
            )
            #endif
            VStack(spacing: 20) {
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary).opacity(0.2))

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)

                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: Layout.TextFieldEditorSheet.width, height: Layout.TextFieldEditorSheet.height)
    }
}
