import SwiftUI
import MarkdownUI

extension MessageModel {
    enum Role: String {
        case user = "user"
        case assistant = "assistant"
        case tool = "tool"

        var isUser: Bool {
            self == .user
        }
    }

    var role: Role {
        Role(rawValue: author.role) ?? .assistant
    }

    var isUser: Bool {
        let res = self.role.isUser && !(self.isToolCall() || self.isToolMessage())
        return res
    }

}
struct MessageBubble: View {
    let message: MessageModel
    @Environment(\.colorScheme) private var colorScheme

    var bubbleColor: Color {
        return message.isUser ? AppTheme.Colors.Message.userBubble.opacity(0.5) : AppTheme.Colors.background
    }

    var borderColor: Color {
        return message.isUser ? .clear : AppTheme.Colors.Message.bubbleBorder
    }

    var markdownTheme: Theme {
        Theme()
            .text {
                ForegroundColor(textColor)
            }
            .code {
                FontFamilyVariant(.monospaced)
                ForegroundColor(textColor)
                BackgroundColor(codeBackgroundColor)
            }
            .strong {
                FontWeight(.semibold)
                ForegroundColor(textColor)
            }
            .emphasis {
                FontStyle(.italic)
                ForegroundColor(textColor)
            }
            .link {
                ForegroundColor(message.isUser ? .white : .accentColor)
            }
    }

    var textColor: Color {
        if message.isUser {
            return .white
        } else {
            return colorScheme == .light ? .primary : .white
        }
    }

    var codeBackgroundColor: Color {
            switch message.role {
            case .user:
                return Color.white.opacity(0.2)
            case .assistant, .tool:
                return colorScheme == .light ?
                    Color.black.opacity(0.05) :
                    Color.white.opacity(0.1)
            }
        }

    func copyToPasteboard() {
        #if os(iOS)
        UIPasteboard.general.string = message.getText()
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.getText(), forType: .string)
        #endif
    }

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }

            Markdown(message.getText())
//                .markdownTheme(markdownTheme)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .contextMenu {
                    Button(action: copyToPasteboard) {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                }

            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
