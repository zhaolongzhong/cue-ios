import SwiftUI

#if os(macOS)
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async { // Ensure the window is available
            self.callback(nsView.window)
        }
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
