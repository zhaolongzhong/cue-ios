import SwiftUI

struct InputAlert: View {
    @Binding var isPresented: Bool
    @Binding var text: String
    let title: String
    let message: String
    let placeholder: String
    let isNumeric: Bool
    let validator: ((String) -> Bool)?
    let onSave: (String) -> Void

    init(
        isPresented: Binding<Bool>,
        text: Binding<String>,
        title: String,
        message: String,
        placeholder: String = "Enter text",
        isNumeric: Bool = false,
        validator: ((String) -> Bool)? = nil,
        onSave: @escaping (String) -> Void
    ) {
        self._isPresented = isPresented
        self._text = text
        self.title = title
        self.message = message
        self.placeholder = placeholder
        self.isNumeric = isNumeric
        self.validator = validator
        self.onSave = onSave
    }

    var body: some View {
        CenteredAlert(
            isPresented: $isPresented,
            title: title,
            message: message,
            content: {
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .keyboardType(isNumeric ? .numberPad : .default)
                    .autocapitalization(.none)
                    #endif
                    .disableAutocorrection(true)
            },
            primaryButton: AlertButton(
                title: "Save"
            ) {
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if validator?(trimmedText) ?? !trimmedText.isEmpty {
                    onSave(trimmedText)
                }
            },
            secondaryButton: AlertButton(
                title: "Cancel",
                style: .cancel
            ) {
                isPresented = false
            }
        )
    }
}

extension View {
    func inputAlert(
        title: String,
        message: String,
        text: Binding<String>,
        isPresented: Binding<Bool>,
        placeholder: String = "Enter text",
        isNumeric: Bool = false,
        validator: ((String) -> Bool)? = nil,
        onSave: @escaping (String) -> Void
    ) -> some View {
        self.overlay(
            Group {
                if isPresented.wrappedValue {
                    InputAlert(
                        isPresented: isPresented,
                        text: text,
                        title: title,
                        message: message,
                        placeholder: placeholder,
                        isNumeric: isNumeric,
                        validator: validator,
                        onSave: onSave
                    )
                }
            }
        )
    }
}
