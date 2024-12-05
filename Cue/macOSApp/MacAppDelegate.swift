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

    }

    func applicationWillTerminate(_ notification: Notification) {

    }
}
#endif
