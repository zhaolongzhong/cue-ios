import SwiftUI

public enum WindowSize {
    public static let defaultWidth: CGFloat = 600
    public static let defaultHeight: CGFloat = 400

    public static let miniWidth: CGFloat = 600
    public static let miniHeight: CGFloat = 220
    public static let sidebarMiniWidth: CGFloat = 200
    public static let sidebarIdealWidth: CGFloat = 250
    public static let sidebarMaxWidth: CGFloat = 500

    public struct Small {
        public static let width: CGFloat = 720
        public static let height: CGFloat = 500
    }

    public struct Auth {
        public static let width: CGFloat = 340
        public static let height: CGFloat = 480
    }

    public struct Companion {
        public static let width: CGFloat = 440
        public static let height: CGFloat = 540
        public static let minWidth: CGFloat = 320
        public static let maxWidth: CGFloat = 600
        public static let minHeight: CGFloat = 280
    }

    public struct Voice {
        public static let minWidth: CGFloat = 280
        public static let minHeight: CGFloat = 350
    }

    public struct Settings {
        public static let minWidth: CGFloat = 600
        public static let minHeight: CGFloat = 500
    }
}

public struct WindowSizeModifier: ViewModifier {
    let width: CGFloat
    let height: CGFloat
    let isFixedSize: Bool

    init(width: CGFloat = WindowSize.defaultWidth,
         height: CGFloat = WindowSize.defaultHeight,
         isFixedSize: Bool = false) {
        self.width = width
        self.height = height
        self.isFixedSize = isFixedSize
    }

    private func configureWindow() {
        #if os(macOS)
        if let window = NSApp.windows.first {
            if isFixedSize {
                window.styleMask.remove(.resizable)
                window.setContentSize(NSSize(width: width, height: height))
                window.collectionBehavior.remove(.fullScreenPrimary)
                window.minSize = NSSize(width: width, height: height)
                window.maxSize = NSSize(width: width, height: height)
            } else {
                window.styleMask.insert(.resizable)
                window.minSize = NSSize(width: width, height: height)
                window.setContentSize(NSSize(width: width, height: height))
            }
        }
        #endif
    }

    public func body(content: Content) -> some View {
        content
            #if os(macOS)
            .frame(
                width: isFixedSize ? width : nil,
                height: isFixedSize ? height : nil
            )
            .onAppear {
                setWindowSize(width: width, height: height)
                configureWindow()
            }
            #endif
    }
}

extension View {
    public func windowSize(width: CGFloat = WindowSize.defaultWidth, height: CGFloat = WindowSize.defaultHeight) -> some View {
        modifier(WindowSizeModifier(width: width, height: height))
    }

    public func authWindowSize() -> some View {
        modifier(WindowSizeModifier(width: WindowSize.Auth.width,
                                    height: WindowSize.Auth.height,
                                    isFixedSize: true))
    }
}
