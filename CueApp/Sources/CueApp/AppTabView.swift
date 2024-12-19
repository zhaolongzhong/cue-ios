import SwiftUI

enum TabSelection: String {
    case chat = "Chat"
    case gemini = "Gemini"
    case anthropic = "Anthropic"
    case assistants = "Assistants"
    case settings = "Settings"
}

public struct AppTabView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var apiKeysViewModel: APIKeysViewModel
    @State private var selectedTab: TabSelection = .assistants

    public init() {}

    public var body: some View {
        let availableTabs: [TabSelection] = {
            var tabs: [TabSelection] = []
            if !apiKeysViewModel.openAIKey.isEmpty {
                tabs.append(.chat)
            }
            if !apiKeysViewModel.geminiKey.isEmpty {
                tabs.append(.gemini)
            }
            if !apiKeysViewModel.anthropicKey.isEmpty {
                tabs.append(.anthropic)
            }
            tabs.append(.assistants)
            tabs.append(.settings)
            return tabs
        }()

        TabView(selection: $selectedTab) {
            ForEach(availableTabs, id: \.self) { tab in
                switch tab {
                case .chat:
                    OpenAIChatView(apiKey: apiKeysViewModel.openAIKey)
                        .tabItem {
                            Label("Chat", systemImage: "wand.and.stars")
                        }
                        .tag(TabSelection.chat)
                        .onAppear {
                            AppLog.log.debug("OpenAI tab appeared with key length: \(apiKeysViewModel.openAIKey.count)")
                        }

                case .gemini:
                    GeminiChatView(
                        viewModelFactory: dependencies.viewModelFactory.makeGeminiViewModel,
                        broadcastViewModelFactory: dependencies.viewModelFactory.makeBroadcastViewModel,
                        apiKey: apiKeysViewModel.geminiKey
                    )
                    .tabItem {
                        Label("Gemini", systemImage: "wand.and.stars")
                    }
                    .tag(TabSelection.gemini)
                    .onAppear {
                        AppLog.log.debug("Gemini tab appeared with key length: \(apiKeysViewModel.geminiKey.count)")
                    }

                case .anthropic:
                    AnthropicChatView(apiKey: apiKeysViewModel.anthropicKey)
                        .tabItem {
                            Label("Anthropic", systemImage: "wand.and.stars.fill")
                        }
                        .tag(TabSelection.anthropic)
                        .onAppear {
                            AppLog.log.debug("Anthropic tab appeared with key length: \(apiKeysViewModel.anthropicKey.count)")
                        }

                case .assistants:
                    AssistantsView(viewModelFactory: dependencies.viewModelFactory.makeAssistantsViewModel)
                        .tabItem {
                            Label("Assistants", systemImage: "bubble.left.and.bubble.right")
                        }
                        .tag(TabSelection.assistants)

                case .settings:
                    SettingsView(viewModelFactory: dependencies.viewModelFactory.makeSettingsViewModel)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(TabSelection.settings)
                }
            }
        }
        .navigationTitle(selectedTab.rawValue)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accentColor(Color(.darkGray))
        .onChange(of: selectedTab) { _, _ in
            Task { @MainActor in
                #if os(iOS)
                HapticManager.shared.impact(style: .light)
                #endif
            }
        }
        .onAppear {
            AppLog.log.debug("""
                AppTabView appeared with keys:
                OpenAI: \(!apiKeysViewModel.openAIKey.isEmpty)
                Gemini: \(!apiKeysViewModel.geminiKey.isEmpty)
                Anthropic: \(!apiKeysViewModel.anthropicKey.isEmpty)
                """)
        }
        .onChange(of: apiKeysViewModel.openAIKey) { _, newValue in
            AppLog.log.debug("OpenAI key changed: \(!newValue.isEmpty)")
        }
        .onChange(of: apiKeysViewModel.geminiKey) { _, newValue in
            AppLog.log.debug("Gemini key changed: \(!newValue.isEmpty)")
        }
        .onChange(of: apiKeysViewModel.anthropicKey) { _, newValue in
            AppLog.log.debug("Anthropic key changed: \(!newValue.isEmpty)")
        }
        .onChange(of: appStateViewModel.state.currentUser) { _, _ in
            AppLog.log.debug("AppTabView user changed")
            self.initialize(userId: appStateViewModel.state.currentUser?.id)
        }
    }

    private func initialize(userId: String?) {
        guard let userId = userId else { return }
        dependencies.webSocketStore.initialize(for: userId)
    }
}
