import CueApp
import SwiftUI

#if os(macOS)
import Sparkle

@main
struct macOSApp: App {

    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    @StateObject private var dependencies = AppDependencies()
    @StateObject private var mainCoordinator: AppCoordinator
    private let updaterController: SPUStandardUpdaterController

    init() {
        let dynamicDelegate = DynamicFeedUpdaterDelegate(initialURL: "")
        let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: dynamicDelegate, userDriverDelegate: nil)
        _mainCoordinator = StateObject(wrappedValue: AppCoordinator(updater: updaterController.updater, dynamicDelegate: dynamicDelegate))
        self.updaterController = updaterController
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedView()
                .environmentObject(dependencies)
                .environmentObject(mainCoordinator)
        }
        .windowToolbarStyle(.unified)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }

        CommonWindowGroup(id: "settings-window", dependencies: dependencies, appCoordinator: mainCoordinator) {
            SettingsWindowView()
        }

        CommonWindowGroup(id: "openai-chat-window", dependencies: dependencies, appCoordinator: AppCoordinator(updater: nil)) {
            OpenAIWindowView()
        }

        CommonWindowGroup(id: "realtime-chat-window", dependencies: dependencies, appCoordinator: AppCoordinator(updater: nil)) {
            RealtimeWindowView()
        }

        CommonWindowGroup(id: "anthropic-chat-window", dependencies: dependencies, appCoordinator: AppCoordinator(updater: nil)) {
            AnthropicWindowView()
        }
    }
}

struct CommonWindowGroup<Content: View>: Scene {
    @StateObject private var appCoordinator: AppCoordinator
    let id: String
    let dependencies: AppDependencies
    let content: () -> Content

    init(id: String, dependencies: AppDependencies, appCoordinator: AppCoordinator, content: @escaping () -> Content) {
        _appCoordinator = StateObject(wrappedValue: appCoordinator)
        self.id = id
        self.dependencies = dependencies
        self.content = content
    }

    var body: some Scene {
        WindowGroup(id: id) {
            ZStack {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                    .opacity(0.3)
                    .ignoresSafeArea()
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(dependencies)
                    .environmentObject(appCoordinator)
            }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .windowStyle(.titleBar)
        .defaultSize(width: WindowSize.small.width, height: WindowSize.small.height)
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
            .navigationTitle("Settings")
            .frame(minHeight: 400)
            .frame(width: 600)
            .environmentObject(dependencies.apiKeysProviderViewModel)
            .withCoordinatorAlert()
    }
}

struct OpenAIWindowView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var dependencies: AppDependencies

    var body: some View {
        let apiKey = dependencies.apiKeysProviderViewModel.getAPIKey(for: APIKeyType.openai)
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
        let apiKey = dependencies.apiKeysProviderViewModel.getAPIKey(for: APIKeyType.openai)
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
        let apiKey = dependencies.apiKeysProviderViewModel.getAPIKey(for: APIKeyType.anthropic)
        AnthropicChatView(apiKey: apiKey)
            .environmentObject(coordinator)
            .environmentObject(dependencies)
            .navigationTitle("Anthropic")
            .withCoordinatorAlert()
    }
}

#endif
