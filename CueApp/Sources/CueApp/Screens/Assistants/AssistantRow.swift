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
            InitialsAvatar(text: assistant.name.prefix(1).uppercased(), size: 32, avatarColor: assistant.assistantColor.color)

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

public struct AssistantRowV2: View {
    @Environment(\.colorScheme) var colorScheme
    let assistant: Assistant
    let status: ClientStatus?
    var actions: AssistantActions?

    private var isOnline: Bool {
        return status?.isOnline == true
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(assistant.assistantColor.color)
                        .frame(width: 36, height: 36)
                    InitialsAvatar(text: assistant.name.prefix(1).uppercased(), size: 36)
                }
                if self.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .padding(.trailing, 2)
                        .padding(.bottom, 2)
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(assistant.name)
                    Spacer()
                    if let lastUpdated = status?.lastUpdated.relativeDate {
                        Text(lastUpdated)
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }

                if let lastMessage = status?.lastMessage {
                    Text(lastMessage)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                }

            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            AssistantContextMenu(
                assistant: assistant,
                actions: actions
            )
        }
    }
}

public struct AssistantRowV3: View {
    @Environment(\.colorScheme) var colorScheme
    let assistantWithStatus: AssistantWithStatus
    var actions: AssistantActions?
    
    public var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(assistantWithStatus.assistant.assistantColor.color)
                        .frame(width: 40, height: 40)
                    InitialsAvatar(text: assistantWithStatus.name.prefix(1).uppercased(), size: 40)
                }
                if assistantWithStatus.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .padding(.trailing, 2)
                        .padding(.bottom, 2)
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(assistantWithStatus.name)
                        .fontWeight(assistantWithStatus.isPrimary ? .bold : .regular)
                    
                    if assistantWithStatus.isPrimary {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                    }
                    
                    Spacer()
                    
                    Text(assistantWithStatus.lastUpdated.relativeDate)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                }

                HStack(spacing: 6) {
                    // Status indicator (online/offline)
                    Circle()
                        .fill(assistantWithStatus.statusColor)
                        .frame(width: 6, height: 6)
                    
                    if let runnerId = assistantWithStatus.runnerId, !runnerId.isEmpty {
                        Text("Runner: ...\(runnerId.suffix(4))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let lastMessage = assistantWithStatus.lastMessage, !lastMessage.isEmpty {
                        Text(lastMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(assistantWithStatus.isOnline ? "Online" : "Offline")
                            .font(.caption)
                            .foregroundColor(assistantWithStatus.isOnline ? .green : .secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            AssistantContextMenu(
                assistant: assistantWithStatus.assistant,
                actions: actions
            )
        }
    }
}
