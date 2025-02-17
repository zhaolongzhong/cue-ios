import SwiftUI

struct RepliesSection: View {
    @Environment(\.colorScheme) var colorScheme
    private let sectionTitle: String
    private let emailSummaries: [EmailSummary]
    private let onReply: (EmailSummary) -> Void
    private let onOpenDetail: (EmailSummary) -> Void
    private let onArchive: ([EmailSummary]) -> Void

    public init(
        sectionTitle: String = "Replies",
        sectionOtherTitle: String? = nil,
        emailSummaries: [EmailSummary],
        onReply: @escaping (EmailSummary) -> Void,
        onOpenDetail: @escaping (EmailSummary) -> Void,
        onArchive: @escaping ([EmailSummary]) -> Void
    ) {
        self.sectionTitle = sectionTitle
        self.emailSummaries = emailSummaries
        self.onReply = onReply
        self.onOpenDetail = onOpenDetail
        self.onArchive = onArchive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sectionTitle)
                .font(.title)
            ForEach(Array(emailSummaries.enumerated()), id: \.element.id) { index, email in
                RepliesItemRow(email: email) {
                    onReply(email)
                }
                .onTapGesture {
                    onOpenDetail(email)
                }
                .contextMenu {
                    Button {
                        onArchive([email])
                    } label: {
                        Text("Archive")
                    }
                }

                if index < emailSummaries.count - 1 {
                    Divider()
                }
            }
        }
        .cardStyle()
    }
}

struct RepliesItemRow: View {
    let email: EmailSummary
    let action: () -> Void

    private var avatarLetter: String {
        String(email.from?.prefix(1).uppercased() ?? email.title.prefix(1).uppercased())
    }

    var body: some View {
        VStack(alignment: .leading) {
            header
            Text(email.content ?? "")
                .foregroundColor(.secondary)
                .lineLimit(3)
            CapsuleButton(title: "Compose reply") {
                action()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cornerRadius(12)
    }

    var header: some View {
        HStack(alignment: .top, spacing: 16) {
            InitialsAvatar(text: avatarLetter, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                if let from = email.from {
                    Text(from)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                Text(email.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("To you at \(email.date.relativeDate)")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
    }
}
