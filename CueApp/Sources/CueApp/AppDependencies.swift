import SwiftUI
import Combine

@MainActor
public class AppDependencies: ObservableObject, AppStateDelegate {
    @Published public var authService: AuthService
    @Published public var assistantService: AssistantService
    // @Published public var conversationManager: ConversationManager
    @Published public var webSocketStore: WebSocketManagerStore
    @Published public var appStateViewModel: AppStateViewModel
    @Published public var liveAPIWebSocketManager: LiveAPIWebSocketManager
    @Published public var apiKeysViewModel: APIKeysViewModel

    private lazy var _viewModelFactory: ViewModelFactory = {
        ViewModelFactory(dependencies: self)
    }()

    public var viewModelFactory: ViewModelFactory {
        _viewModelFactory
    }

    public init() {
        self.apiKeysViewModel = APIKeysViewModel()
        self.webSocketStore = WebSocketManagerStore()
        // self.conversationManager = ConversationManager()
        let authService = AuthService()
        self.authService = authService
        self.assistantService = AssistantService()
        self.appStateViewModel = AppStateViewModel(authService: authService)
        self.liveAPIWebSocketManager = LiveAPIWebSocketManager()
        self.appStateViewModel.delegate = self
    }

    public func handleLogout() async {
        AppLog.log.debug("AppDependencies handleLogout")
        webSocketStore.disconnect()
        // conversationManager.cleanup()
        await assistantService.cleanup()
        self.viewModelFactory.cleanup()
    }
}

@MainActor
public class ViewModelFactory {
    let dependencies: AppDependencies
    private var apiKeysViewModel: APIKeysViewModel?
    private var settingsViewModel: SettingsViewModel?
    private var assistantsViewModel: AssistantsViewModel?
    private var chatViewModels: [String: ChatViewModel] = [:]
    private var anthropicViewModel: AnthropicChatViewModel?
    private var geminialViewModel: GeminiChatViewModel?
    private var openaiViewModel: OpenAIChatViewModel?
    private var broadcastViewModel: BroadcastViewModel?

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func makeAssistantsViewModel() -> AssistantsViewModel {
        if let assistantsViewModel = self.assistantsViewModel {
            return assistantsViewModel
        }

        self.assistantsViewModel = AssistantsViewModel(
            assistantService: dependencies.assistantService,
            webSocketManagerStore: dependencies.webSocketStore
        )
        return self.assistantsViewModel!
    }

    func makeChatViewViewModel(assistant: Assistant) -> ChatViewModel {
        if let existing = chatViewModels[assistant.id] {
            return existing
        } else {
            let newViewModel = ChatViewModel(assistant: assistant, webSocketManagerStore: self.dependencies.webSocketStore)
            chatViewModels[assistant.id] = newViewModel
            return newViewModel
        }
    }

    public func makeSettingsViewModel() -> SettingsViewModel {
        if let settingsViewModel = self.settingsViewModel {
            return settingsViewModel
        } else {
            let settingsViewModel = SettingsViewModel(authService: dependencies.authService)
            self.settingsViewModel = settingsViewModel
            return settingsViewModel
        }
    }

    public func makeAPIKeysViewModel() -> APIKeysViewModel {
        if let apiKeysViewModel = self.apiKeysViewModel {
            return apiKeysViewModel
        } else {
            let apiKeysViewModel = APIKeysViewModel()
            self.apiKeysViewModel = apiKeysViewModel
            return apiKeysViewModel
        }
    }
    
    func makeGeminiViewModel() -> GeminiChatViewModel {
        if let geminialViewModel = self.geminialViewModel {
            return geminialViewModel
        }

        self.geminialViewModel = GeminiChatViewModel(
            liveAPIWebSocketManager: dependencies.liveAPIWebSocketManager
        )
        return self.geminialViewModel!
    }
    
    func makeBroadcastViewModel() -> BroadcastViewModel {
        if let broadcastViewModel = self.broadcastViewModel {
            return broadcastViewModel
        }

        self.broadcastViewModel = BroadcastViewModel(
            webSocketManager: dependencies.liveAPIWebSocketManager
        )
        return self.broadcastViewModel!
    }

    func cleanup() {
        AppLog.log.debug("ViewModelFactor clean up, set assistantsViewModel and chatViewModel to nil")
        self.assistantsViewModel?.cleanup()
        self.assistantsViewModel = nil
        self.chatViewModels.values.forEach { $0.cleanup() }
        self.chatViewModels.removeAll()
    }
}
