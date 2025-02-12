import SwiftUI

struct EmailRow: View {
    let email: EmailSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(email.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                if email.requiresAction {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }

            Text(email.snippet)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if !email.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(email.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.all, 16)
    }
}
