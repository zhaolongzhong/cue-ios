import SwiftUI

public struct AssistantRow: View {
    @Environment(\.colorScheme) var colorScheme
    let assistant: Assistant
    let status: ClientStatus?
    var actions: AssistantActions?

    private var isOnline: Bool {
        return status?.isOnline == true
    }

    public var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(text: assistant.name.prefix(1).uppercased(), size: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(assistant.name)
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
                    .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            AssistantContextMenu(
                assistant: assistant,
                actions: actions
            )
        }
    }
}

public struct AssistantContextMenu: View {
    let assistant: Assistant
    var actions: AssistantActions?

    public var body: some View {
        Group {
            Button {
                actions?.onDetails(assistant: assistant)
            } label: {
                Label("Details", systemImage: "pencil")
            }

            if !assistant.isPrimary {
                Button {
                    actions?.onSetPrimary(assistant: assistant)
                } label: {
                    Label("Set as Primary", systemImage: "star.fill")
                }
            }

            Button(role: .destructive) {
                actions?.onDelete(assistant: assistant)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
