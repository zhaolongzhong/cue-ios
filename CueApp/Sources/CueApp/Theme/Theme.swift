import Foundation
import SwiftUI

// Main theme namespace
public enum AppTheme {
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
