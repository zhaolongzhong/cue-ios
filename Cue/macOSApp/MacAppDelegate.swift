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

            let toolbar = NSToolbar(identifier: "MainToolbar")
            toolbar.allowsUserCustomization = true
            toolbar.autosavesConfiguration = true
            window.toolbar = toolbar
        }
    }
}

// class AppDelegate: NSObject, NSApplicationDelegate {
//    func applicationDidFinishLaunching(_ notification: Notification) {
//        if let window = NSApplication.shared.windows.first {
//            window.setContentSize(NSSize(width: 1200, height: 800))
//            window.minSize = NSSize(width: 800, height: 600)
//            window.center()
//
//            // Set up toolbar
//            let toolbar = NSToolbar(identifier: "MainToolbar")
//            toolbar.allowsUserCustomization = true
//            toolbar.autosavesConfiguration = true
//            window.toolbar = toolbar
//        }
//    }
// }

#endif
