import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    let message: CueChatMessage
    let isUser: Bool
    let maxCharacters: Int
    let isExpanded: Bool
    let onShowMore: (CueChatMessage) -> Void

    init(
        message: CueChatMessage,
        isExpanded: Bool = false,
        onShowMore: @escaping (CueChatMessage) -> Void = { _ in }
    ) {
        self.message = message
        self.isUser = message.isUser
        #if os(iOS)
        self.maxCharacters = 1000
        #else
        self.maxCharacters = 20000
        #endif
        self.isExpanded = isExpanded
        self.onShowMore = onShowMore
    }

    var bubbleColor: Color {
        return isUser ? AppTheme.Colors.Message.userBubble.opacity(0.2) : AppTheme.Colors.background
    }

    var body: some View {
        HStack(alignment: .top) {
            if isUser {
                Spacer()
            }
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if isUser {
                        Spacer()
                    }
                    MessageBubbleContent(
                        message: message,
                        maxCharacters: maxCharacters,
                        isExpanded: isExpanded,
                        onShowMore: onShowMore
                    )
                    .padding(.horizontal, isUser ? 16 : 6)
                    .padding(.vertical, isUser ? 10 : 0)
                    .background(isUser ? bubbleColor : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: isUser ? 18 : 0))
                    .textSelection(.enabled)
                    if !isUser {
                        Spacer()
                    }
                }
                if !message.isTool && !message.isToolMessage {
                    HStack(alignment: .top) {
                        if isUser {
                            Spacer()
                        }
                        CopyButton(content: message.content, isVisible: isHovering)
                            .padding(.horizontal, isUser ? 0 : 2)
                            .padding(.top, 4)
                        if !isUser {
                            Spacer()
                        }
                    }
                }
            }
            if !isUser {
                Spacer()
            }

        }
        .padding(.horizontal, isUser ? 18 : 14)
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        #endif
    }

    private var avatar: some View {
        Text("~")
            .font(.system(size: 20, weight: .light, design: .monospaced))
            .foregroundColor( .primary)
            .frame(width: 20, height: 20)
            .background(
                Circle()
                    .stroke(AppTheme.Colors.separator, lineWidth: 1)
            )
            .padding(.leading, 4)
    }
}

struct MessageBubbleContent: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: CueChatMessage
    let maxCharacters: Int
    let isExpanded: Bool
    let onShowMore: (CueChatMessage) -> Void

    var body: some View {
        let text = message.content
        let segments = extractSegments(from: text)

        VStack(alignment: .leading, spacing: 4) {
            if message.isToolMessage {
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
                            onShowMore: {
                                onShowMore(message)
                            })
                    case .code(let language, let code):
                        CodeBlockView(language: language, code: code)
                    }
                }
            }
            if message.isTool {
                ToolMessageView(message: message)
            }
        }
    }
}
