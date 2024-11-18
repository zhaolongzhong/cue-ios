import SwiftUI

// Main theme namespace
public enum AppTheme {
    // MARK: - Colors
    public enum Colors {
        // Background colors
        static var background: Color {
            #if os(iOS)
            Color(uiColor: .systemBackground)
            #else
            Color(nsColor: .windowBackgroundColor)
            #endif
        }

        static var secondaryBackground: Color {
            #if os(iOS)
            Color(uiColor: .secondarySystemBackground)
            #else
            Color(nsColor: .controlBackgroundColor)
            #endif
        }

        // Message colors
        enum Message {
            static let userBubble = Color.accentColor

            static var assistantBubble: Color {
                #if os(iOS)
                Color(uiColor: .systemGray6)
                #else
                Color(nsColor: .controlBackgroundColor)
                #endif
            }

            static var assistantBubbleDark: Color {
                #if os(iOS)
                Color(uiColor: .systemGray5)
                #else
                Color(nsColor: .darkGray)
                #endif
            }

            static let userText = Color.white
            static let assistantText = Color.primary
            static let assistantTextDark = Color.white

            static var bubbleBorder: Color {
                Color(white: 0.8)
            }
        }

        // Input field colors
        enum Input {
            static func background(for colorScheme: ColorScheme) -> Color {
                colorScheme == .light ? Color(white: 0.95) : Color(white: 0.15)
            }

            static func text(for colorScheme: ColorScheme) -> Color {
                colorScheme == .light ? .primary : .white
            }

            static func placeholder(for colorScheme: ColorScheme) -> Color {
                colorScheme == .light ? .secondary : .secondary
            }
        }
    }

    // MARK: - Dimensions
    enum Dimensions {
        // Message bubble dimensions
        enum Message {
            static let cornerRadius: CGFloat = 16
            static let padding: CGFloat = 12
            static let spacing: CGFloat = 12
            static let maxWidth: CGFloat = 260
        }

        // Input field dimensions
        enum Input {
            static let cornerRadius: CGFloat = 20
            static let padding: CGFloat = 10
            static let height: CGFloat = 40
            static let iconSize: CGFloat = 24
        }

        // Common spacing
        enum Spacing {
            static let small: CGFloat = 8
            static let medium: CGFloat = 12
            static let large: CGFloat = 16
        }
    }

    // MARK: - Typography
    enum Typography {
        static func messageText(colorScheme: ColorScheme, isUserMessage: Bool) -> Font {
            .body
        }

        static let inputText: Font = .body
        static let navigationTitle: Font = .headline
    }
}

// MARK: - View Modifiers
extension View {
    func messageBubbleStyle(isUser: Bool, colorScheme: ColorScheme) -> some View {
        self
            .padding(AppTheme.Dimensions.Message.padding)
            .background(
                isUser
                ? AppTheme.Colors.Message.userBubble
                : (colorScheme == .light
                   ? AppTheme.Colors.Message.assistantBubble
                   : AppTheme.Colors.Message.assistantBubbleDark)
            )
            .foregroundColor(
                isUser
                ? AppTheme.Colors.Message.userText
                : (colorScheme == .light
                   ? AppTheme.Colors.Message.assistantText
                   : AppTheme.Colors.Message.assistantTextDark)
            )
    }

    func inputFieldStyle(colorScheme: ColorScheme) -> some View {
        self
            .textFieldStyle(.plain)
            .padding(AppTheme.Dimensions.Input.padding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Dimensions.Input.cornerRadius)
                    .fill(AppTheme.Colors.Input.background(for: colorScheme))
            )
    }
}

// Example usage in ChatView
struct ModernChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var message = ""

    var body: some View {
        VStack(spacing: AppTheme.Dimensions.Spacing.medium) {
            // Message input
            HStack(spacing: AppTheme.Dimensions.Spacing.medium) {
                TextField("Type a message...", text: $message)
                    .inputFieldStyle(colorScheme: colorScheme)
                    .font(AppTheme.Typography.inputText)

                Button(action: {}) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: AppTheme.Dimensions.Input.iconSize))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, AppTheme.Dimensions.Spacing.medium)
            .background(AppTheme.Colors.background)
        }
    }
}
