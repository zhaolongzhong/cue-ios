import SwiftUI

struct ThinkingBlockView: View {
    let text: String
    let blockId: String
    let message: CueChatMessage
    let onToggle: (String) -> Void

    var isExpanded: Bool {
        message.isThinkingBlockExpanded(id: blockId)
    }

    init(text: String, blockId: String, message: CueChatMessage, onToggle: @escaping (String) -> Void) {
        self.text = text
        self.blockId = blockId
        self.message = message
        self.onToggle = onToggle
    }

    var streamingState: StreamingState? {
        message.streamingState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggle(blockId)
                }
            } label: {
                HStack(spacing: 4) {
                    if message.isStreaming {
                        AnimatedText(text: "Reasoning")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        if streamingState?.isThinkingComplete == true && streamingState?.isStreamingMode == true {
                            Text("Reasoned for")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)

                            if let duration = streamingState?.thinkingDuration {
                                Text("\(duration, specifier: "%.0f") seconds")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Reasoning")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .frame(width: 3)
                        .foregroundColor(.secondary.opacity(0.3))
                    Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.vertical, 4)
        .id("\(blockId)_\(isExpanded ? "expanded" : "collapsed")")
    }
}
