import SwiftUI

public enum Theme {
    public enum Colors {
        // System colors that automatically adapt to light/dark mode
        public static let background = Color(.systemBackground)
        public static let secondaryBackground = Color(.secondarySystemBackground)
        public static let tertiaryBackground = Color(.tertiarySystemBackground)
        public static let label = Color(.label)
        public static let secondaryLabel = Color(.secondaryLabel)
        public static let tertiaryLabel = Color(.tertiaryLabel)
        public static let systemFill = Color(.systemFill)

        // Custom color that adapts to light/dark mode
        public static var customAdaptive: Color {
            @Environment(\.colorScheme) var colorScheme
            return colorScheme == .dark ? .purple : .orange
        }
    }

    public enum Fonts {
        public static let largeTitle = Font.largeTitle
        public static let title = Font.title
        public static let headline = Font.headline
        public static let body = Font.body
        public static let caption = Font.caption
    }
}
