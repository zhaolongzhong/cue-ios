import SwiftUI
import Dependencies

enum TabSelection: String {
    case chat = "Chat"
    case anthropic = "Anthropic"
    case assistants = "Assistants"
    case settings = "Settings"
}

public struct AppTabView: View {
    @Dependency(\.webSocketService) public var webSocketService
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var apiKeysProviderViewModel: APIKeysProviderViewModel
    @State private var selectedTab: TabSelection = .assistants

    public var body: some View {
        TabView(selection: $selectedTab) {
            if !apiKeysProviderViewModel.openAIKey.isEmpty {
            OpenAIChatView(apiKey: apiKeysProviderViewModel.openAIKey)
                .tabItem {
                    Label("Chat", systemImage: "wand.and.stars")
                }
                .tag(TabSelection.chat)
            }
            if !apiKeysProviderViewModel.anthropicKey.isEmpty {
                AnthropicChatView(apiKey: apiKeysProviderViewModel.anthropicKey)
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
        .tint(Color(uiColor: .systemGray))
        #endif
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
            self.initialize(userId: appStateViewModel.state.currentUser?.id)
        }
    }

    private func initialize(userId: String?) {
        guard let _ = userId else {
            return
        }
        Task {
            await webSocketService.connect()
        }
    }
}
