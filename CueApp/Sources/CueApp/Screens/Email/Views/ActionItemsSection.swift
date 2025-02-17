import SwiftUI

struct ActionItemsSection: View {
    @Environment(\.colorScheme) var colorScheme
    private let sectionTitle: String
    private let emailSummaries: [EmailSummary]
    private let onOpenDetail: (EmailSummary) -> Void
    private let onArchive: ([EmailSummary]) -> Void

    public init(
        sectionTitle: String = "Action Items",
        sectionOtherTitle: String? = nil,
        emailSummaries: [EmailSummary],
        onOpenDetail: @escaping (EmailSummary) -> Void,
        onArchive: @escaping ([EmailSummary]) -> Void
    ) {
        self.sectionTitle = sectionTitle
        self.emailSummaries = emailSummaries
        self.onOpenDetail = onOpenDetail
        self.onArchive = onArchive
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            Text(sectionTitle)
                .font(.title)
            ForEach(Array(emailSummaries.enumerated()), id: \.element.id) { index, email in
                ActionItemRow(email: email) {
                    onOpenDetail(email)
                }
                .onTapGesture {
                    onOpenDetail(email)
                }
                .contextMenu {
                    Button {
                        Task {
                            onArchive([email])
                        }
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

struct ActionItemRow: View {
    let email: EmailSummary
    let action: () -> Void

    private var avatarLetter: String {
        String(email.from?.prefix(1).uppercased() ?? email.title.prefix(1).uppercased())
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 16) {
                InitialsAvatar(text: avatarLetter, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(email.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .textSelection(.enabled)
                    Text("To you at \(email.date.relativeDate)")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary.opacity(0.8))
                        .textSelection(.enabled)
                }
            }
            Text(email.snippet)
                .foregroundColor(.secondary)
                .lineLimit(3)
            CapsuleButton(title: "Resolve") {
                action()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cornerRadius(12)
    }
}
