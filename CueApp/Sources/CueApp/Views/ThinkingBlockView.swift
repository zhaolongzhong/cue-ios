import SwiftUI

struct ThinkingBlockView: View {
    let text: String
    let blockId: String
    let message: CueChatMessage
    @State private var expansionState: ExpansionState = .collapsed
    // Explicitly track content height for smoother animation
    @State private var contentHeight: CGFloat = 0

    enum ExpansionState {
        case collapsed
        case expanded
    }

    var isExpanded: Bool {
        expansionState == .expanded
    }

    init(text: String, blockId: String, message: CueChatMessage) {
        self.text = text
        self.blockId = blockId
        self.message = message
        self._expansionState = State(initialValue: message.isStreaming ? .expanded : .collapsed)
    }

    var streamingState: StreamingState? {
        message.streamingState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    expansionState = expansionState == .collapsed ? .expanded : .collapsed
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

                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Content view with better animation
            if isExpanded || message.isStreaming {
                VStack {
                    HStack(alignment: .top, spacing: 12) {
                        Rectangle()
                            .frame(width: 3)
                            .foregroundColor(.secondary.opacity(0.3))

                        Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.onAppear {
                                        contentHeight = geo.size.height
                                    }.onChange(of: text) { _, _ in
                                        contentHeight = geo.size.height
                                    }
                                }
                            )
                    }
                }
                .frame(height: isExpanded || message.isStreaming ? contentHeight : 0, alignment: .top)
                .clipped()
                .opacity(isExpanded || message.isStreaming ? 1 : 0)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.vertical, 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
        .clipped() // Contains animations within this view
    }
}
