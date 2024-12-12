import SwiftUI

struct CenteredAlert<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let content: Content
    let primaryButton: AlertButton
    let secondaryButton: AlertButton

    init(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        @ViewBuilder content: () -> Content,
        primaryButton: AlertButton,
        secondaryButton: AlertButton
    ) {
        self._isPresented = isPresented
        self.title = title
        self.message = message
        self.content = content()
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
            VStack(spacing: 20) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)

                content
                    .padding(.horizontal)
                    .padding(.vertical)

                HStack {
                    Button(action: {
                        isPresented = false
                        secondaryButton.action()
                    }) {
                        Text(secondaryButton.title)
                            .foregroundColor(secondaryButton.style == .cancel ? .red : .blue)
                    }

                    Spacer()

                    Button(action: {
                        primaryButton.action()
                        isPresented = false
                    }) {
                        Text(primaryButton.title)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(AppTheme.Colors.background)
            .cornerRadius(12)
            .shadow(radius: 10)
            .frame(maxWidth: 300)
        }
    }
}

struct AlertButton {
    let title: String
    let style: AlertButtonStyle
    let action: () -> Void

    init(
        title: String,
        style: AlertButtonStyle = .default,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.action = action
    }
}

enum AlertButtonStyle {
    case `default`
    case cancel
    case destructive
}

struct TextFieldAlert: View {
    @Binding var isPresented: Bool
    @Binding var text: String
    let title: String
    let message: String
    let onConfirm: (String) -> Void

    var body: some View {
        CenteredAlert(
            isPresented: $isPresented,
            title: title,
            message: message,
            content: {
                TextField("Enter text", text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                    .disableAutocorrection(true)
            },
            primaryButton: AlertButton(
                title: "Confirm"
            ) {
                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedText.isEmpty else { return }
                onConfirm(trimmedText)
                text = ""
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
