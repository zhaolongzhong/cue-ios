import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    let role: String
    let content: String
    let maxCharacters: Int
    let isExpanded: Bool
    let onShowMore: () -> Void

    init(
        role: String,
        content: String,
        maxCharacters: Int = 300,
        isExpanded: Bool = false,
        onShowMore: @escaping () -> Void = { }
    ) {
        self.role = role
        self.content = content
        self.maxCharacters = maxCharacters
        self.isExpanded = isExpanded
        self.onShowMore = onShowMore
    }

    var isUser: Bool {
        return role == "user"
    }

    var bubbleColor: Color {
        return isUser ? AppTheme.Colors.Message.userBubble.opacity(0.2) : AppTheme.Colors.background
    }

    func copyToPasteboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        #else
        UIPasteboard.general.string = content
        #endif
    }

    var body: some View {
        HStack(alignment: .top) {
            if isUser {
                Spacer()
            } else {
                avatar.padding(.vertical, 4)
            }
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if isUser {
                        Spacer()
                    }
                    MessageBubbleContent(
                        role: role,
                        content: content,
                        maxCharacters: maxCharacters,
                        isExpanded: isExpanded,
                        onShowMore: onShowMore
                    )
                    .padding(.horizontal, getHorizontalPadding())
                    .padding(.vertical, isUser ? 10 : 4)
                    .background(isUser ? bubbleColor : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: isUser ? 16 : 0))
                    .textSelection(.enabled)
                    if !isUser {
                        Spacer()
                    }
                }
                HStack(alignment: .top) {
                    if isUser {
                        Spacer()
                    }
                    CopyButton(role: role, content: content, isVisible: isHovering) {
                        copyToPasteboard()
                    }
                    .padding(.horizontal, getHorizontalPadding())
                    if !isUser {
                        Spacer()
                    }
                }

            }
            if !isUser {
                Spacer()
            }

        }
        .padding(.horizontal, 2)
        .padding(.vertical, 0)
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        #endif
    }

    private func getHorizontalPadding() -> CGFloat {
        return isUser ? 14 : 8
    }

    private var avatar: some View {
        Text("~")
            .font(.system(size: 20, weight: .light, design: .monospaced))
            .foregroundColor(isUser ? .blue : .gray)
            .frame(width: 22, height: 22)
            .background(
                Circle()
                    .stroke(lineWidth: 1)
                    .opacity(0.5)
            )
    }
}

struct MessageBubbleContent: View {
    @Environment(\.colorScheme) private var colorScheme
    let role: String
    let content: String
    let maxCharacters: Int
    let isExpanded: Bool
    let onShowMore: () -> Void

    var body: some View {
        let text = content
        let segments = extractSegments(from: text)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(segments.indices, id: \.self) { index in
                switch segments[index] {
                case .text(let content):
                    StyledTextView(
                        content: content,
                        colorScheme: colorScheme,
                        maxCharacters: maxCharacters,
                        isExpanded: isExpanded,
                        onShowMore: onShowMore)
                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)
                }
            }

        }
    }
}
