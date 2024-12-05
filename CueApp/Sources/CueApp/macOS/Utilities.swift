import SwiftUI

// Helper function to set window size
@MainActor func setWindowSize(width: CGFloat, height: CGFloat) {
    #if os(macOS)
    if let window = NSApplication.shared.windows.first {
        let newSize = NSSize(width: width, height: height)
        window.setContentSize(newSize)
    }
    #endif
}
