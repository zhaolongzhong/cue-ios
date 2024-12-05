import SwiftUI
import CueApp

#if os(macOS)
@main
struct macOSApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            AuthenticatedView()
                .environmentObject(dependencies)
                .environmentObject(dependencies.conversationManager)
        }
        .windowToolbarStyle(.unified)
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            SidebarCommands()
            ToolbarCommands()
        }

        WindowGroup(id: "settings-window") {
            SettingsView()
                .environmentObject(dependencies)
                .frame(minWidth: 500, minHeight: 300)
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
        .windowResizability(.contentSize)
    }
}

#endif
