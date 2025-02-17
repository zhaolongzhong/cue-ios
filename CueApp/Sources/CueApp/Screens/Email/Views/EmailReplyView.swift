import SwiftUI

struct EmailReplyView: View {
    @Environment(\.colorScheme) var colorScheme
    private let emailSummary: EmailSummary
    private let emailDetails: GmailMessage
    private var onDismiss: () -> Void
    @ObservedObject private var emailViewModel: EmailScreenViewModel
    @State private var showQuote: Bool = false

    public init(
        emailSummary: EmailSummary,
        emailDetails: GmailMessage,
        emailViewModel: EmailScreenViewModel,
        onDismiss: @escaping () -> Void
    ) {
        self.emailSummary = emailSummary
        self.emailDetails = emailDetails
        self.emailViewModel = emailViewModel
        self.onDismiss = onDismiss
    }

    var body: some View {
        RepliesContentView(
            email: emailSummary,
            emailDetails: emailDetails,
            action: {
                Task {
                    await emailViewModel.sendReply(
                        emailDetails,
                        showQuote: showQuote
                    )
                    onDismiss()
                }
            },
            cancel: onDismiss,
            newMessage: $emailViewModel.newMessage,
            showQuote: $showQuote
        )
        .cardStyle()
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct RepliesContentView: View {
    let email: EmailSummary
    let emailDetails: GmailMessage
    let action: () -> Void
    let cancel: () -> Void
    @Binding var newMessage: String
    @Binding var showQuote: Bool
    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReplyHeaderView(email: email)

            TextEditor(text: $newMessage)
                .font(.body)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
                .frame(minHeight: 100)
                .focused($isTextEditorFocused)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        isTextEditorFocused = true
                    }
                )
                .onAppear {
                    isTextEditorFocused = true
                }

            // Quote controls
            HStack {
                Toggle("Include quoted text", isOn: $showQuote)
                    .font(.caption)

                Spacer()
            }
            .foregroundColor(.secondary)

            // Quoted text section
            if showQuote {
                QuotedContentView(email: emailDetails)
            }

            HStack(spacing: 12) {
                RelySendButton(action: action)
                CapsuleButton(title: "Cancel") {
                    cancel()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ReplyHeaderView: View {
    let email: EmailSummary

    private var avatarLetter: String {
        String(email.from?.prefix(1).uppercased() ?? email.title.prefix(1).uppercased())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            InitialsAvatar(text: avatarLetter, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                if let from = email.from {
                    Text("To: \(from)")
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Text("Re: \(email.title)")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

struct RelySendButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Send")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 18)
            .frame(height: 32)
            .background(
                Capsule()
                    .fill(Color.pink.opacity(0.8))
            )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }
}
