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
            SettingsView(viewModelFactory: dependencies.viewModelFactory.makeSettingsViewModel)
                .environmentObject(dependencies)
                .frame(minWidth: 500, minHeight: 300)
        }
        .defaultSize(width: 500, height: 400)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
        .windowResizability(.contentSize)
    }
}
#endif
