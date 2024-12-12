import CueApp
import SwiftUI

#if os(macOS)
@main
struct macOSApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    @StateObject private var dependencies = AppDependencies()
    @StateObject private var appCoordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            AuthenticatedView()
                .environmentObject(dependencies)
                .environmentObject(appCoordinator)
                // .environmentObject(dependencies.conversationManager)
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
                .navigationTitle("Settings")
        }
        .defaultSize(width: 500, height: 400)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
        .windowResizability(.contentSize)

        WindowGroup(id: "openai-chat-window") {
            let viewModel = APIKeysViewModel()
            let apiKey = viewModel.getAPIKey(for: APIKeyType.openai)
            OpenAIChatView(apiKey: apiKey)
                .navigationTitle("OpenAI")
        }
        .defaultSize(width: 500, height: 400)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
        .windowResizability(.contentSize)

        WindowGroup(id: "anthropic-chat-window") {
            let viewModel = APIKeysViewModel()
            let apiKey = viewModel.getAPIKey(for: APIKeyType.anthropic)
            AnthropicChatView(apiKey: apiKey)
                .navigationTitle("Anthropic")
        }
        .defaultSize(width: 500, height: 400)
        .windowStyle(.titleBar)
        .defaultPosition(.center)
        .windowResizability(.contentSize)
    }
}
#endif
