import SwiftUI

enum TabSelection: String {
    case chat = "Chat"
    case anthropic = "Anthropic"
    case assistants = "Assistants"
    case settings = "Settings"
}

public struct AppTabView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @State private var selectedTab: TabSelection = .assistants
    @StateObject private var apiKeysViewModel: APIKeysViewModel

    public init(apiKeysViewModelFactory: @escaping () -> APIKeysViewModel) {
        _apiKeysViewModel = StateObject(wrappedValue: apiKeysViewModelFactory())
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            if !apiKeysViewModel.openAIKey.isEmpty {
                OpenAIChatView(apiKey: apiKeysViewModel.openAIKey)
                    .tabItem {
                        Label("Chat", systemImage: "wand.and.stars")
                    }
                    .tag(TabSelection.chat)
            }
            if !apiKeysViewModel.anthropicKey.isEmpty {
                AnthropicChatView(apiKey: apiKeysViewModel.anthropicKey)
                    .tabItem {
                        Label("Anthropic", systemImage: "character")
                    }
                    .tag(TabSelection.anthropic)
            }
            AssistantsView(viewModelFactory: dependencies.viewModelFactory.makeAssistantsViewModel)
                .tabItem {
                    Label("Assistants", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(TabSelection.assistants)

            SettingsView(viewModelFactory: dependencies.viewModelFactory.makeSettingsViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(TabSelection.settings)
        }
        .navigationTitle(selectedTab.rawValue)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accentColor(Color(.darkGray))
        .onChange(of: selectedTab) { _, _ in
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
        }
        .onAppear {
            AppLog.log.debug("AppTabView onAppear isAuthenticated:\(appStateViewModel.state.isAuthenticated)")
            self.initialize(userId: appStateViewModel.state.currentUser?.id)
        }
        .onChange(of: appStateViewModel.state.currentUser) { _, _ in
            AppLog.log.debug("AppTabView onChange")
            self.initialize(userId: appStateViewModel.state.currentUser?.id)
        }
    }

    private func initialize(userId: String?) {
        guard let userId = userId else {
            return
        }
        dependencies.webSocketStore.initialize(for: userId)
    }
}
