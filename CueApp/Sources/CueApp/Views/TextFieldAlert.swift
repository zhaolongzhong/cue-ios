import SwiftUI

struct AlertButton {
    let title: String
    let style: AlertButtonStyle
    let action: () -> Void

    // Convert the AlertButton style to system ButtonRole
    var systemRole: ButtonRole? {
        switch style {
        case .cancel: return .cancel
        case .destructive: return .destructive
        case .default: return nil
        }
    }

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

                if !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }

                content
                    .padding(.horizontal)
                    .padding(.vertical)

                HStack {
                    Button {
                        isPresented = false
                        secondaryButton.action()
                    } label: {
                        Text(secondaryButton.title)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        primaryButton.action()
                        isPresented = false
                    } label: {
                        Text(primaryButton.title)
                            .foregroundColor(.primary.opacity(0.8))
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(12)
            .shadow(radius: 10)
            .frame(maxWidth: 300)
        }
    }
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
