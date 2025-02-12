import SwiftUI
import CueOpenAI

#if os(macOS)
extension MainWindowView {

    // MARK: - Window State Persistence
    func saveWindowState(for window: NSWindow) {
        let frame = window.frame
        UserDefaults.standard.set(frame.origin.x, forKey: UserDefaultsKeys.windowOriginX)
        UserDefaults.standard.set(frame.origin.y, forKey: UserDefaultsKeys.windowOriginY)
        UserDefaults.standard.set(frame.size.width, forKey: UserDefaultsKeys.windowWidth)
        UserDefaults.standard.set(frame.size.height, forKey: UserDefaultsKeys.windowHeight)
    }

    func loadWindowState(for window: NSWindow) {
        let originX = UserDefaults.standard.double(forKey: UserDefaultsKeys.windowOriginX)
        let originY = UserDefaults.standard.double(forKey: UserDefaultsKeys.windowOriginY)
        let width = UserDefaults.standard.double(forKey: UserDefaultsKeys.windowWidth)
        let height = UserDefaults.standard.double(forKey: UserDefaultsKeys.windowHeight)

        if width > 0 && height > 0 && width > height {
            let newFrame = NSRect(x: originX, y: originY, width: width, height: height)
            window.setFrame(newFrame, display: true)
        } else {
            // Set default size if no saved state
            window.setContentSize(NSSize(width: WindowSize.small.width, height: WindowSize.small.height))
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
