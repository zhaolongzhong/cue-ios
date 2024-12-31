import SwiftUI

public enum WindowSize {
    public static let defaultWidth: CGFloat = 600
    public static let defaultHeight: CGFloat = 400

    public struct Auth {
        public static let width: CGFloat = 340
        public static let height: CGFloat = 480
    }
}

public struct WindowSizeModifier: ViewModifier {
    let width: CGFloat
    let height: CGFloat

    init(width: CGFloat = WindowSize.defaultWidth, height: CGFloat = WindowSize.defaultHeight) {
        self.width = width
        self.height = height
    }

    public func body(content: Content) -> some View {
        content
            #if os(macOS)
            .frame(minWidth: width, minHeight: height)
            .onAppear {
                setWindowSize(width: width, height: height)
            }
            #endif
    }
}

extension View {
    public func windowSize(width: CGFloat = WindowSize.defaultWidth, height: CGFloat = WindowSize.defaultHeight) -> some View {
        modifier(WindowSizeModifier(width: width, height: height))
    }

    public func authWindowSize() -> some View {
        windowSize(width: WindowSize.Auth.width, height: WindowSize.Auth.height)
    }
}
