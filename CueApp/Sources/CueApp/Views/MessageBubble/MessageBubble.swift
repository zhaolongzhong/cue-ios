import SwiftUI
import CueAnthropic

struct MessageBubble: View {
    @State private var isHovering = false

    let message: CueChatMessage
    let isExpanded: Bool
    let isStreaming: Bool
    let onShowMore: (CueChatMessage) -> Void

    var isUser: Bool { message.isUser }

    #if os(iOS)
    let maxCharacters = 1000
    #else
    let maxCharacters = 20000
    #endif

    init(
        message: CueChatMessage,
        isExpanded: Bool = false,
        onShowMore: @escaping (CueChatMessage) -> Void = { _ in }
    ) {
        self.message = message
        self.isExpanded = isExpanded
        self.isStreaming = message.isStreaming
        self.onShowMore = onShowMore
    }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer() }
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if isUser { Spacer() }
                    MessageBubbleContent(
                        message: message,
                        maxCharacters: maxCharacters,
                        isExpanded: isExpanded,
                        onShowMore: onShowMore
                    )
                    .textSelection(.enabled)
                    if !isUser { Spacer() }
                }

                if !message.isTool && !message.isToolMessage {
                    MessageBubbleControlButtons(message: message, isHovering: $isHovering)
                        .padding(.top, 4)
                }
            }
            if !isUser { Spacer() }
        }
        .animation(.spring(), value: isStreaming)
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { isHovering = hovering }
        }
        #endif
    }
}

struct MessageBubbleContent: View {
    @Environment(\.colorScheme) private var colorScheme

    let message: CueChatMessage
    let maxCharacters: Int
    let isExpanded: Bool
    let onShowMore: (CueChatMessage) -> Void
    let segments: [CueChatMessage.MessageSegment]

    init(message: CueChatMessage, maxCharacters: Int, isExpanded: Bool, onShowMore: @escaping (CueChatMessage) -> Void) {
        self.message = message
        self.maxCharacters = maxCharacters
        self.isExpanded = isExpanded
        self.onShowMore = onShowMore
        self.segments = message.segments
    }

    var body: some View {
        return Group {
            if message.isUser {
                UserMessageView(segments: segments)
                    .padding(.top, 4)
            } else if message.isTool {
                VStack(alignment: .leading) {
                    ToolMessageView(message: message)
                }
            } else if message.isToolMessage {
               ToolMessageView(message: message)
            } else {
                VStack(alignment: .leading) {
                    ForEach(segments.indices, id: \.self) { index in
                        switch segments[index] {
                        case .text(let content):
                            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                StyledTextView(
                                    content: content,
                                    maxCharacters: maxCharacters,
                                    isExpanded: isExpanded,
                                    onShowMore: { onShowMore(message) }
                                )
                            }
                        case .code(let language, let code):
                            CodeBlockView(language: language, code: code)
                                .padding(.top, 10)
                        case .thinking(let text):
                            ThinkingBlockView(
                                text: text,
                                message: message
                            )
                        case .file(let fileData):
                            Text(fileData.fileName)
                        case .image(let imageFileData):
                            AdaptiveImageView(dataURL: imageFileData.url)
                        }
                    }
                }
           }
        }
    }
}
