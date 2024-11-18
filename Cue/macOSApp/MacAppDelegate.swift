//
//  MacAppDelegate.swift
//

#if os(macOS)
import SwiftUI
import CueApp

class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillResignActive(_ notification: Notification) {
        AppLog.log.debug("applicationWillResignActive")
        NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        AppLog.log.debug("applicationWillBecomeActive")
        NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(NSSize(width: 800, height: 600))
            window.center()
            window.title = "Cue"
        }
    }
}

#endif
