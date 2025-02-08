//  MacAppDelegate.swift

#if os(macOS)
import CueApp
import SwiftUI
import GoogleSignIn

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register for GetURL events.
        let appleEventManager = NSAppleEventManager.shared()
        appleEventManager.setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(event:replyEvent:)),  // Changed to #selector
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleGetURLEvent(event: NSAppleEventDescriptor?, replyEvent: NSAppleEventDescriptor?) {
        if let urlString = event?.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
           let url = URL(string: urlString) {  // Changed from NSURL to URL
            GIDSignIn.sharedInstance.handle(url)
        }
    }

    func applicationWillTerminate(_: Notification) {
    }
}
#endif
