import SwiftUI

enum TextContentType {
    case text
    case email
    case password
}
struct PlatformTextField: View {
    let placeholder: String
    @Binding var text: String
    let textContentType: TextContentType?

    init(_ placeholder: String, text: Binding<String>, textContentType: TextContentType? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.textContentType = textContentType
    }

    var body: some View {
        if textContentType == TextContentType.password {
            secureField
        } else {
            commonTextFieldStyle
        }
    }

    var commonTextFieldStyle: some View {
        #if os(iOS) || os(tvOS) || os(watchOS)
        TextField(placeholder, text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            .autocapitalization(.none)

        #elseif os(macOS)
        TextField(placeholder, text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .frame(minHeight: 24)
        #endif
    }

    var secureField: some View {
        #if os(iOS) || os(tvOS) || os(watchOS)
        SecureField(placeholder, text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )

        #elseif os(macOS)
        SecureField(placeholder, text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .frame(minHeight: 24)
        #endif
    }
}
