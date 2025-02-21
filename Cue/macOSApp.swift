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
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(.contentSize)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }

        CommonWindowGroup(id: WindowId.settings.rawValue, dependencies: dependencies, appCoordinator: mainCoordinator) {
            SettingsWindowView()
        }

        CommonWindowGroup(id: "realtime-chat-window", dependencies: dependencies, appCoordinator: AppCoordinator(updater: nil)) {
            RealtimeWindowView()
        }

        CommonWindowGroup(id: WindowId.providersManagement.rawValue, dependencies: dependencies, appCoordinator: AppCoordinator(updater: nil)) {
           ProviderManagementWindowView()
       }
    }
}

struct CommonWindowGroup<Content: View>: Scene {
    @StateObject private var appCoordinator: AppCoordinator
    let id: String
    let enableVisualEffect: Bool
    let dependencies: AppDependencies
    let content: () -> Content

    init(id: String, dependencies: AppDependencies, appCoordinator: AppCoordinator, enableVisualEffect: Bool = false, content: @escaping () -> Content) {
        _appCoordinator = StateObject(wrappedValue: appCoordinator)
        self.id = id
        self.dependencies = dependencies
        self.enableVisualEffect = enableVisualEffect
        self.content = content
    }

    var body: some Scene {
        WindowGroup(id: id) {
            if enableVisualEffect {
                ZStack {
                    VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                        .opacity(0.3)
                        .ignoresSafeArea()
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .environmentObject(dependencies)
                        .environmentObject(appCoordinator)
                }
            } else {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environmentObject(dependencies)
                    .environmentObject(appCoordinator)
            }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
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
            .frame(minHeight: 400)
            .frame(minWidth: 600)
            .environmentObject(dependencies.providersViewModel)
            .withCoordinatorAlert()
    }
}

struct RealtimeWindowView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var dependencies: AppDependencies

    var body: some View {
        let apiKey = dependencies.providersViewModel.getAPIKey(for: Provider.openai)
        RealtimeChatScreen(viewModelFactory: dependencies.viewModelFactory.makeRealtimeChatViewModel, apiKey: apiKey)
            .environmentObject(coordinator)
            .environmentObject(dependencies)
            .navigationTitle("")
            .withCoordinatorAlert()
    }
}

struct ProviderManagementWindowView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var dependencies: AppDependencies

    var body: some View {
        ProvidersScreen(providersViewModel: dependencies.providersViewModel)
            .environmentObject(coordinator)
            .frame(width: 400)
            .frame(minHeight: 300)
            .environmentObject(dependencies)
            .withCoordinatorAlert()
    }
}

#endif
