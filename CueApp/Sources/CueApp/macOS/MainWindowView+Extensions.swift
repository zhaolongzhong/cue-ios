import SwiftUI
import CueOpenAI

#if os(macOS)
extension MainWindowView {
    // MARK: - Window State Persistence

    func saveWindowState(for window: NSWindow) {

        let frame = window.frame
        UserDefaults.standard.set(frame.origin.x, forKey: "windowOriginX")
        UserDefaults.standard.set(frame.origin.y, forKey: "windowOriginY")
        UserDefaults.standard.set(frame.size.width, forKey: "windowWidth")
        UserDefaults.standard.set(frame.size.height, forKey: "windowHeight")
    }

    func loadWindowState(for window: NSWindow) {
        let originX = UserDefaults.standard.double(forKey: "windowOriginX")
        let originY = UserDefaults.standard.double(forKey: "windowOriginY")
        let width = UserDefaults.standard.double(forKey: "windowWidth")
        let height = UserDefaults.standard.double(forKey: "windowHeight")

        if width > 0 && height > 0 && width > height {
            let newFrame = NSRect(x: originX, y: originY, width: width, height: height)
            window.setFrame(newFrame, display: true)
        } else {
            // Set default size if no saved state
            window.setContentSize(NSSize(width: 800, height: 600))
            window.center()
        }
    }

    // MARK: - Window Delegate

    class WindowDelegate: NSObject, NSWindowDelegate {
        var saveState: () -> Void

        init(saveState: @escaping () -> Void) {
            self.saveState = saveState
        }

        func windowDidMove(_ notification: Notification) {
            saveState()
        }

        func windowDidResize(_ notification: Notification) {
            saveState()
        }
    }
}
#endif
