import SwiftUI

struct QuotedContentView: View {
    let email: GmailMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .background(Color.gray.opacity(0.3))

            Text("···")
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))

            Text("On \(email.messageDate), \(email.from) wrote:")
                .foregroundColor(.secondary)
                .font(.caption)

            ScrollView(.vertical, showsIndicators: true) {
                Text(email.plainTextContent ?? "")
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: 200)
            .padding(.horizontal, 8)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
                    .padding(.vertical, 4),
                alignment: .leading
            )
        }
    }
}
