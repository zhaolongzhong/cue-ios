import SwiftUI

struct NumberInputView: View {
    let label: String
    @Binding var text: String
    let onSubmit: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            TextField(label, text: $text)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(AppTheme.Colors.secondaryBackground))
                .cornerRadius(8)
                .onChange(of: text) { _, newValue in
                    // Only allow numeric characters
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered != newValue {
                        text = filtered
                    }
                }
                .onSubmit {
                    submitValue()
                }
                #if os(iOS)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            submitValue()
                            hideKeyboard()
                        }
                    }
                }
                #endif
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(text.isEmpty ? "Not set" : text)")
        .accessibilityHint("Enter a number")
    }

    private func submitValue() {
        if let turns = Int(text) {
            onSubmit(turns)
        }
    }

    private func hideKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
