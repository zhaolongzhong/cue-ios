import Foundation
import SwiftUI

extension Color {
    static var almostPrimary: Color {
        return Color.primary.opacity(0.9)
    }
}

extension AppTheme {
    // MARK: - Colors
    public enum Colors {
        // Primary backgrounds
        public static var background: Color {
            #if os(iOS)
            Color(uiColor: .systemBackground)
            #elseif os(macOS)
            Color(nsColor: .textBackgroundColor)
            #endif
        }

        public static var secondaryBackground: Color {
            #if os(iOS)
            Color(uiColor: .secondarySystemBackground)
            #elseif os(macOS)
            Color(nsColor: .windowBackgroundColor).opacity(0.8)
            #endif
        }

        public static var tertiaryBackground: Color {
            #if os(iOS)
            Color(uiColor: .tertiarySystemBackground)
            #elseif os(macOS)
            Color(nsColor: .controlBackgroundColor)
            #endif
        }

        // Grouped backgrounds
        public static var groupedBackground: Color {
            #if os(iOS)
            Color(uiColor: .systemGroupedBackground)
            #elseif os(macOS)
            Color(nsColor: .controlBackgroundColor)
            #endif
        }

        // Label/Text colors
        public static var primaryText: Color {
            #if os(iOS)
            Color(uiColor: .label)
            #elseif os(macOS)
            Color(nsColor: .labelColor)
            #endif
        }

        public static var secondaryText: Color {
            #if os(iOS)
            Color(uiColor: .secondaryLabel)
            #elseif os(macOS)
            Color(nsColor: .secondaryLabelColor)
            #endif
        }

        // System fills
        public static var systemFill: Color {
            #if os(iOS)
            Color(uiColor: .systemFill)
            #elseif os(macOS)
            Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
            #endif
        }

        // Separators
        public static var separator: Color {
            #if os(iOS)
            Color(uiColor: .separator)
            #elseif os(macOS)
            Color(nsColor: .separatorColor)
            #endif
        }

        // Tint color
        public static var tint: Color {
            #if os(iOS)
            Color(uiColor: .tintColor)
            #elseif os(macOS)
            Color(nsColor: .controlAccentColor)
            #endif
        }

        // Approach 1: Using System Fill colors (Recommended)
        public static var inputFieldBackground: Color {
            #if os(iOS)
            Color(uiColor: .systemFill)
            #elseif os(macOS)
            Color(nsColor: .controlBackgroundColor)
            #endif
        }

        // Approach 2: Using Secondary System Background
        public static var alternateInputBackground: Color {
            #if os(iOS)
            Color(uiColor: .secondarySystemBackground)
            #elseif os(macOS)
            Color(nsColor: .textBackgroundColor)
            #endif
        }

        // For focused state (optional)
        public static var inputFieldFocusedBackground: Color {
            #if os(iOS)
            Color(uiColor: .secondarySystemFill)
            #elseif os(macOS)
            Color(nsColor: .controlAccentColor).opacity(0.1)
            #endif
        }

        public static var systemGray: Color {
            #if os(iOS)
            Color(uiColor: .systemGray)
            #else
            Color(nsColor: .systemGray)
            #endif
        }

        // Toolbar background
        public static var toolbarBackground: Color {
            #if os(iOS)
            Color(uiColor: .systemBackground)
                .opacity(0.9)
            #else
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.95)
            #endif
        }

        // Control Button Colors
        public static var controlButtonBackground: Color {
            #if os(iOS)
            Color(uiColor: .systemFill)
            #else
            Color(nsColor: .systemGray).opacity(0.3)
            #endif
        }

        public static var controlButtonDisabledBackground: Color {
            #if os(iOS)
            Color(uiColor: .tertiarySystemFill)
            #else
            Color(nsColor: .disabledControlTextColor)
            #endif
        }

        public static var controlButtonForeground: Color {
            #if os(iOS)
            Color(uiColor: .secondaryLabel)
            #else
            Color(nsColor: .labelColor)
            #endif
        }

        public static var controlButtonDisabledForeground: Color {
            #if os(iOS)
            Color(uiColor: .tertiaryLabel)
            #else
            Color(nsColor: .secondaryLabelColor)
            #endif
        }

        // Message colors
        enum Message {
            static let userBubble = Color(.lightGray)

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
                inputFieldBackground
            }

            static func text(for colorScheme: ColorScheme) -> Color {
                colorScheme == .light ? .primary : .white
            }

            static func placeholder(for colorScheme: ColorScheme) -> Color {
                colorScheme == .light ? .secondary : .secondary
            }
        }
    }
}
