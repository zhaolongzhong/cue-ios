//  MacAppDelegate.swift

#if os(macOS)
import SwiftUI
import CueApp

class MacAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var mainWindow: NSWindow?

    func applicationWillResignActive(_ notification: Notification) {
        // Keep active when it's not focused so we can keep the websocket connected
        // AppLog.log.debug("applicationWillResignActive")
        // NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        AppLog.log.debug("applicationWillBecomeActive")
        NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Access the first window
        if let window = NSApplication.shared.windows.first {
            self.mainWindow = window  // Assign to mainWindow
            window.title = "Cue"

            // Configure window size and position
            loadWindowState(for: window)

            // Setup toolbar
            let toolbar = NSToolbar(identifier: "MainToolbar")
            toolbar.allowsUserCustomization = true
            toolbar.autosavesConfiguration = true
            window.toolbar = toolbar

            // Assign delegate to handle window events
            window.delegate = self
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowState()
    }

    // MARK: - Window State Persistence

    func saveWindowState() {
        guard let window = mainWindow else { return }
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

        if width > 0 && height > 0 {
            let newFrame = NSRect(x: originX, y: originY, width: width, height: height)
            window.setFrame(newFrame, display: true)
        } else {
            // Set default size if no saved state
            window.setContentSize(NSSize(width: 800, height: 600))
            window.center()
        }
    }

    // MARK: - NSWindowDelegate Methods

    func windowDidMove(_ notification: Notification) {
        saveWindowState()
    }

    func windowDidResize(_ notification: Notification) {
        saveWindowState()
    }
}
#endif
