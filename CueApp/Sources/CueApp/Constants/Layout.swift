import SwiftUI

/// Constants for layout dimensions used throughout the app
public enum Layout {
    /// Window dimensions
    enum Window {
        public static let minimumWidth: CGFloat = 600
        public static let minimumHeight: CGFloat = 220
    }

    /// Sidebar dimensions
    enum Sidebar {
        public static let minimumWidth: CGFloat = 200
        public static let idealWidth: CGFloat = 250
        public static let maximumWidth: CGFloat = 500
    }

    enum Sheet {
        enum Normal {
            enum Large {
                public static let width: CGFloat = 620
                public static let height: CGFloat = 680
            }

            enum Normal {
                public static let width: CGFloat = 585
                public static let height: CGFloat = 490
            }
        }
    }

    enum EditorSheet {
        public static let width: CGFloat = 700
        public static let height: CGFloat = 760
    }

    enum TextFieldEditorSheet {
        public static let width: CGFloat = 500
        public static let height: CGFloat = 400
    }

    /// Common UI element dimensions
    enum Elements {
        public static let popupMenuWidth: CGFloat = 320
        public static let headerHeight: CGFloat = 46
        public static let headerMediumHeight: CGFloat = 42
        public static let headerSmallHeight: CGFloat = 38
    }
}
