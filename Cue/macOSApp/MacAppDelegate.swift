//  MacAppDelegate.swift

#if os(macOS)
import CueApp
import SwiftUI

class MacAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var mainWindow: NSWindow?

    func applicationWillResignActive(_: Notification) {
        // Keep active when it's not focused so we can keep the websocket connected
        // AppLog.log.debug("applicationWillResignActive")
        // NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
    }

    func applicationWillBecomeActive(_: Notification) {
        AppLog.log.debug("applicationWillBecomeActive")
        NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)
    }

    func applicationDidFinishLaunching(_: Notification) {
    }

    func applicationWillTerminate(_: Notification) {
    }
}
#endif
