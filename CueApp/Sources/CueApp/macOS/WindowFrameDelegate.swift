import Foundation

#if os(macOS)
import AppKit

class WindowFrameDelegate: NSObject, NSWindowDelegate {
    let id: String
    let maxWidth: CGFloat

    init(id: String, maxWidth: CGFloat = .infinity) {
        self.id = id
        self.maxWidth = maxWidth
    }

    // Enforce maximum width
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(width: min(frameSize.width, maxWidth), height: frameSize.height)
    }

    // Save frame when moved or resized
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        saveFrame(window.frame)
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        saveFrame(window.frame)
    }

    private func saveFrame(_ frame: NSRect) {
        let frameDict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        UserDefaults.standard.set(frameDict, forKey: "windowFrame_\(id)")
    }
}

#endif
