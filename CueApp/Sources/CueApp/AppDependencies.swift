import SwiftUI
import Combine

@MainActor
public class AppDependencies: ObservableObject, AppStateDelegate {
    public var authService: AuthService
    public var assistantService: AssistantService
    // public var conversationManager: ConversationManager
    public var webSocketStore: WebSocketManagerStore
    public var appStateViewModel: AppStateViewModel

    private lazy var _viewModelFactory: ViewModelFactory = {
        ViewModelFactory(dependencies: self)
    }()

    public var viewModelFactory: ViewModelFactory {
        _viewModelFactory
    }

    public init() {
        self.webSocketStore = WebSocketManagerStore()
        // self.conversationManager = ConversationManager()
        let authService = AuthService()
        self.authService = authService
        self.assistantService = AssistantService()
        self.appStateViewModel = AppStateViewModel(authService: authService)
        self.appStateViewModel.delegate = self
    }

    public func handleLogout() async {
        AppLog.log.debug("AppDependencies handleLogout")
        webSocketStore.disconnect()
        // conversationManager.cleanup()
        self.viewModelFactory.cleanup()
    }
}

@MainActor
public class ViewModelFactory {
    let dependencies: AppDependencies
    private var assistantsViewModel: AssistantsViewModel?
    private var chatViewModels: [String: ChatViewModel] = [:]
    private var settingsViewModel: SettingsViewModel?
    private var apiKeysViewModel: APIKeysViewModel?

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

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(authService: dependencies.authService)
    }

    func makeSignUpViewModel() -> SignUpViewModel {
        SignUpViewModel(authService: dependencies.authService)
    }

    func cleanup() {
        AppLog.log.debug("ViewModelFactor clean up, set assistantsViewModel and chatViewModel to nil")
        self.assistantsViewModel?.cleanup()
        self.assistantsViewModel = nil
        self.chatViewModels.values.forEach { $0.cleanup() }
        self.chatViewModels.removeAll()
    }
}
