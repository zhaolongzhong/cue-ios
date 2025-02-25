import SwiftUI
import CueAnthropic

struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
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
        onShowMore: @escaping (CueChatMessage) -> Void = { _ in },
        onToggleThinking: @escaping (CueChatMessage, String) -> Void = { _, _ in }
    ) {
        self.message = message
        self.isExpanded = isExpanded
        self.isStreaming = message.isStreaming
        self.onShowMore = onShowMore
    }

    var bubbleColor: Color {
        isUser ? AppTheme.Colors.Message.userBubble.opacity(0.2) : AppTheme.Colors.background
    }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer() }
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if isUser { Spacer() }
                    VStack(alignment: .leading, spacing: 4) {
                        MessageBubbleContent(
                            message: message,
                            maxCharacters: maxCharacters,
                            isExpanded: isExpanded,
                            onShowMore: onShowMore
                        )
                    }
                    .padding(.horizontal, isUser ? 16 : 6)
                    .padding(.vertical, isUser ? 10 : 0)
                    .background(isUser ? bubbleColor : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: isUser ? 18 : 0))
                    .textSelection(.enabled)
                    if !isUser { Spacer() }
                }

                if !message.isTool && !message.isToolMessage {
                    HStack(alignment: .top) {
                        if isUser { Spacer() }
                        CopyButton(content: message.content.contentAsString, isVisible: isHovering && !isStreaming)
                            .padding(.horizontal, isUser ? 0 : 2)
                            .padding(.top, 4)
                        if !isUser { Spacer() }
                    }
                }
                if isStreaming {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 5, height: 5)
                                .opacity(isStreaming ? 1 : 0)
                                .animation(
                                    Animation.easeInOut(duration: 0.5)
                                        .repeatForever()
                                        .delay(0.2 * Double(index)),
                                    value: isStreaming
                                )
                        }
                    }
                    .padding(.top, 4)
                }
            }
            if !isUser { Spacer() }
        }
        .padding(.horizontal, isUser ? 18 : 14)
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
        return VStack(alignment: .leading, spacing: 4) {
            if message.isUser {
                VStack(alignment: .leading, spacing: 4) {
                    if message.isUser {
                        switch message.content {
                        case .string(let text):
                            Text(text)
                        case .array(let blocks):
                            ForEach(blocks.indices, id: \.self) { index in
                                if let blockText = blocks[index].text,
                                   let fileName = extractFileName(from: blockText) {
                                    Text(fileName)
                                } else {
                                    Text(blocks[index].text ?? "")
                                }
                            }
                        }
                    }
                }
            } else if message.isTool {
                VStack(alignment: .leading) {
                    if let segment = segments.filter({ $0.isThinking }).first {
                        ThinkingBlockView(
                            text: segment.text,
                            blockId: "",
                            message: message
                        )
                    }
                    ToolMessageView(message: message)
                }
            } else if message.isToolMessage {
               ToolMessageView(message: message)
           } else {
                ForEach(segments.indices, id: \.self) { index in
                    switch segments[index] {
                    case .text(let content):
                        StyledTextView(
                            content: content,
                            colorScheme: colorScheme,
                            maxCharacters: maxCharacters,
                            isExpanded: isExpanded,
                            onShowMore: { onShowMore(message) }
                        )
                    case .code(let language, let code):
                        CodeBlockView(language: language, code: code)
                    case .thinking(let text):
                        let cleanedText = text.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
                        if !cleanedText.isEmpty {
                            let blockId = message.generateConsistentBlockId(index: index)
                            ThinkingBlockView(
                                text: text,
                                blockId: blockId,
                                message: message
                            )
                        }
                    }
                }
            }
        }
    }
}

func extractFileName(from text: String) -> String? {
    let marker = "<file_name>"
    guard let startRange = text.range(of: marker),
          let endRange = text.range(of: marker, range: startRange.upperBound..<text.endIndex) else {
        return nil
    }
    return String(text[startRange.upperBound..<endRange.lowerBound])
}

extension CueChatMessage {
    var segments: [MessageSegment] {
        var finalSegments: [MessageSegment] = []
        if case .anthropic(let msg, _, let streamingState) = self {
            let contentBlocks: [Anthropic.ContentBlock]
            if let blocks = streamingState?.contentBlocks {
                contentBlocks = blocks
            } else {
                contentBlocks = msg.contentBlocks
            }
            for contentBlock in contentBlocks {
                let newSegments = extractSegments(from: contentBlock.text, isThinking: contentBlock.isThinking)
                finalSegments.append(contentsOf: newSegments)
            }
        } else {
            let newSegments = extractSegments(from: self.content.contentAsString)
            finalSegments.append(contentsOf: newSegments)
        }
        return finalSegments
    }
}
