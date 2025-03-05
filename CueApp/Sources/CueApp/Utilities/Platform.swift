import SwiftUI

func copyToPasteboard(_ content: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(content, forType: .string)
    #else
    UIPasteboard.general.string = content
    #endif
}
