import SwiftUI

struct NewslettersSection: View {
    @Environment(\.colorScheme) var colorScheme
    private let sectionTitle: String
    private let sectionOtherTitle: String?
    private let emailSummaries: [EmailSummary]
    private let showGradientBorder: Bool
    private let onOpenDetail: (EmailSummary) -> Void
    private let onArchive: ([EmailSummary]) -> Void

    public init(
        sectionTitle: String = "Newsletters",
        sectionOtherTitle: String? = nil,
        emailSummaries: [EmailSummary],
        showGradientBorder: Bool = false,
        onOpenDetail: @escaping (EmailSummary) -> Void,
        onArchive: @escaping ([EmailSummary]) -> Void
    ) {
        self.sectionTitle = sectionTitle
        self.sectionOtherTitle = sectionOtherTitle
        self.emailSummaries = emailSummaries
        self.showGradientBorder = showGradientBorder
        self.onOpenDetail = onOpenDetail
        self.onArchive = onArchive
    }

    private var featuredNewsletters: [EmailSummary] {
        Array(emailSummaries.prefix(3))
    }

    private var otherNewsletters: [EmailSummary] {
        Array(emailSummaries.dropFirst(3))
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            Text(sectionTitle)
                .font(.title)

            VStack(spacing: 12) {
                ForEach(Array(featuredNewsletters.enumerated()), id: \.element.id) { index, email in
                    FeaturedNewsletterRow(email: email)
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

            if !otherNewsletters.isEmpty {
                if let otherTitle = sectionOtherTitle {
                    HStack {
                        Text(otherTitle)
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.top, 8)
                        Spacer()
                        Button {
                            Task {
                                onArchive(otherNewsletters)
                            }
                        } label: {
                            Text("Archive All")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                LazyVStack(spacing: 8) {
                    ForEach(otherNewsletters) { email in
                        NewsletterRow(email: email)
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
                    }
                }
            }
        }
        .cardStyle(showGradientBorder: showGradientBorder)
    }
}

struct FeaturedNewsletterRow: View {
    let email: EmailSummary

    private var avatarLetter: String {
        String(email.from?.prefix(1).uppercased() ?? email.title.prefix(1).uppercased())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            InitialsAvatar(text: avatarLetter, size: 36)
            VStack(alignment: .leading, spacing: 8) {
                Text(email.title)
                    .font(.headline)
                    #if os(macOS)
                    .fontWeight(.semibold)
                    #endif
                    .lineLimit(1)
                    .textSelection(.enabled)
                Text(email.snippet)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                if let from = email.fromName {
                    Text("From \(from)")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                if let keyInsights = email.keyInsights {
                    Text("Key Insights")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    ForEach(keyInsights, id: \.self) { insight in
                        BulletRow(text: insight)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .cornerRadius(12)
    }
}

struct NewsletterRow: View {
    let email: EmailSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundColor(.secondary)
            Text(email.title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

struct BulletRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 3))
                .foregroundColor(.secondary)
            Text(text)
                .font(.body)
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}
