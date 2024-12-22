import CueApp
import SwiftUI

#if os(macOS)
@main
struct macOSApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    @StateObject private var dependencies = AppDependencies()
    @StateObject private var mainCoordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            AuthenticatedView()
                .environmentObject(dependencies)
                .environmentObject(mainCoordinator)
        }
        .windowToolbarStyle(.unified)
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            SidebarCommands()
            ToolbarCommands()
        }

        CommonWindowGroup(id: "settings-window", dependencies: dependencies) {
            SettingsWindowView()
        }

        CommonWindowGroup(id: "openai-chat-window", dependencies: dependencies) {
            OpenAIWindowView()
        }

        CommonWindowGroup(id: "realtime-chat-window", dependencies: dependencies) {
            RealtimeWindowView()
        }

        CommonWindowGroup(id: "anthropic-chat-window", dependencies: dependencies) {
            AnthropicWindowView()
        }
    }
}

struct CommonWindowGroup<Content: View>: Scene {
    @StateObject private var openAICoordinator = AppCoordinator()
    let id: String
    let dependencies: AppDependencies
    let content: () -> Content

    var body: some Scene {
        WindowGroup(id: id) {
            ZStack {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                    .opacity(0.3)
                    .ignoresSafeArea()
                content()
                    .environmentObject(dependencies)
                    .environmentObject(openAICoordinator)
            }
        }
        .defaultSize(width: 500, height: 400)
        .defaultPosition(.center)
        .windowResizability(.contentSize)
    }
}

struct SettingsWindowView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var dependencies: AppDependencies

    var body: some View {
        SettingsView(viewModelFactory: dependencies.viewModelFactory.makeSettingsViewModel)
            .environmentObject(coordinator)
            .frame(minWidth: 500, minHeight: 300)
            .navigationTitle("Settings")
            .withCoordinatorAlert()
    }
}

struct OpenAIWindowView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var dependencies: AppDependencies

    var body: some View {
        let viewModel = APIKeysViewModel()
        let apiKey = viewModel.getAPIKey(for: APIKeyType.openai)
        OpenAIChatView(apiKey: apiKey)
            .environmentObject(coordinator)
            .environmentObject(dependencies)
            .navigationTitle("OpenAI")
            .withCoordinatorAlert()
    }
}

struct RealtimeWindowView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var dependencies: AppDependencies

    var body: some View {
        let viewModel = APIKeysViewModel()
        let apiKey = viewModel.getAPIKey(for: APIKeyType.openai)
        RealtimeChatScreen(viewModelFactory: dependencies.viewModelFactory.makeRealtimeChatViewModel, apiKey: apiKey)
            .environmentObject(coordinator)
            .environmentObject(dependencies)
            .navigationTitle("")
            .withCoordinatorAlert()
    }
}

struct AnthropicWindowView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var dependencies: AppDependencies

    var body: some View {
        let viewModel = APIKeysViewModel()
        let apiKey = viewModel.getAPIKey(for: APIKeyType.anthropic)
        AnthropicChatView(apiKey: apiKey)
            .environmentObject(coordinator)
            .environmentObject(dependencies)
            .navigationTitle("Anthropic")
            .withCoordinatorAlert()
    }
}

#endif
