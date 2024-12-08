import SwiftUI

struct AssistantRowView: View {
    let assistant: Assistant
    let status: ClientStatus?
    @Environment(\.colorScheme) var colorScheme

    var isOnline: Bool {
        return status?.isOnline == true
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(self.isOnline ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(assistant.name.prefix(2).uppercased())
                        .foregroundColor(.white)
                        .font(.headline)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(assistant.name)
                    .font(.body)
                if let status = status {
                    Text("Runner: ...\(status.runnerId?.suffix(4) ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if assistant.metadata?.isPrimary == true {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 14))
            }

            if self.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

public struct AssistantRow: View {
    let assistant: Assistant
    let viewModel: AssistantsViewModel

    public var body: some View {
        AssistantRowView(
            assistant: assistant,
            status: viewModel.getClientStatus(for: assistant)
        )
        .tag(assistant.id)
        .contextMenu {
            if assistant.metadata?.isPrimary != true {
                AssistantContextMenu(
                    assistant: assistant,
                    viewModel: viewModel
                )
            }
        }
    }
}
