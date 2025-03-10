import SwiftUI

func copyToPasteboard(_ content: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(content, forType: .string)
    #else
    UIPasteboard.general.string = content
    #endif
}

extension Color {
    var native: Any {
        #if os(macOS)
        return NSColor(self)
        #else
        return UIColor(self)
        #endif
    }
}
