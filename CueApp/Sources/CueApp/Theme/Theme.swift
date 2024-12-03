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
