import CueApp
import SwiftUI

#if os(macOS)
import Sparkle

@main
struct macOSApp: App {

    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    @StateObject private var dependencies = AppDependencies()
    @StateObject private var mainCoordinator: AppCoordinator
    @StateObject private var windowConfigStore: WindowConfigurationStore
    @StateObject private var windowManager: CompanionWindowManager
    private let updaterController: SPUStandardUpdaterController

    init() {
        let dynamicDelegate = DynamicFeedUpdaterDelegate(initialURL: "")
        let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: dynamicDelegate, userDriverDelegate: nil)
        _mainCoordinator = StateObject(wrappedValue: AppCoordinator(updater: updaterController.updater, dynamicDelegate: dynamicDelegate))
        self.updaterController = updaterController
        let windowConfigStore = WindowConfigurationStore()
        _windowConfigStore = StateObject(wrappedValue: windowConfigStore)
        _windowManager = StateObject(wrappedValue: CompanionWindowManager(configStore: windowConfigStore))
    }

    var body: some Scene {
        WindowGroup {
            AuthenticatedView()
                .environmentObject(dependencies)
                .environmentObject(mainCoordinator)
                .environmentObject(windowConfigStore)
                .environmentObject(windowManager)
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

        CompanionWindows(
            dependencies: dependencies,
            configStore: windowConfigStore,
            windowManager: windowManager
        )

        CompanionWindows(
            windowId: WindowId.openaiLiveChatWindow,
            dependencies: dependencies,
            configStore: windowConfigStore,
            windowManager: windowManager
        )

        CompanionWindows(
            windowId: WindowId.geminiLiveChatWindow,
            dependencies: dependencies,
            configStore: windowConfigStore,
            windowManager: windowManager
        )

        CommonWindowGroup(id: WindowId.settings.rawValue, dependencies: dependencies, appCoordinator: AppCoordinator(updater: nil)) {
            SettingsWindowView()
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
        .defaultSize(width: WindowSize.Small.width, height: WindowSize.Small.height)
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
