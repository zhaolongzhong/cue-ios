import SwiftUI

struct AssistantRowView: View {
    let assistant: AssistantStatus
    let status: ClientStatus?

    var body: some View {
        HStack {
            Circle()
                .fill(assistant.isOnline ? Color.green : Color.gray)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(assistant.name.prefix(1))
                        .foregroundColor(.white)
                        .font(.headline)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(assistant.name)
                    .font(.body)
                if let status = status {
                    Text("Runner: ...\(status.runnerId?.suffix(4) ?? "")")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            if assistant.assistant.metadata?.isPrimary == true {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 14))
            }

            Circle()
                .fill(assistant.isOnline ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 8)
    }
}
