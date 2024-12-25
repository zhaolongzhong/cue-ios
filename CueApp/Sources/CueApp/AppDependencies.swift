import SwiftUI
import Combine
import Dependencies

@MainActor
public class AppDependencies: ObservableObject, AppStateDelegate {
    @Dependency(\.authService) var authService
    @Dependency(\.assistantService) var assistantService
    // public var conversationManager: ConversationManager
    public var webSocketStore: WebSocketManagerStore
    public var appStateViewModel: AppStateViewModel

    private lazy var _viewModelFactory: ViewModelFactory = {
        ViewModelFactory()
    }()

    public var viewModelFactory: ViewModelFactory {
        _viewModelFactory
    }

    public init() {
        self.webSocketStore = WebSocketManagerStore()
        // self.conversationManager = ConversationManager()
        self.appStateViewModel = AppStateViewModel()
        self.appStateViewModel.delegate = self
    }

    public func handleLogout() async {
        AppLog.log.debug("AppDependencies handleLogout")
        await webSocketStore.disconnect()
        // conversationManager.cleanup()
        self.viewModelFactory.cleanup()
    }
}

@MainActor
public class ViewModelFactory {
    @Dependency(\.authService) var authService
    @Dependency(\.assistantService) var assistantService
    @Dependency(\.webSocketManagerStore) var webSocketManagerStore

    private var assistantsViewModel: AssistantsViewModel?
    private var chatViewModels: [String: ChatViewModel] = [:]
    private var settingsViewModel: SettingsViewModel?
    private var apiKeysViewModel: APIKeysViewModel?

    func makeAssistantsViewModel() -> AssistantsViewModel {
        if let assistantsViewModel = self.assistantsViewModel {
            return assistantsViewModel
        }

        self.assistantsViewModel = AssistantsViewModel(
            assistantService: assistantService)
        return self.assistantsViewModel!
    }

    func makeChatViewViewModel(assistant: Assistant) -> ChatViewModel {
        if let existing = chatViewModels[assistant.id] {
            return existing
        } else {
            let newViewModel = ChatViewModel(assistant: assistant)
            chatViewModels[assistant.id] = newViewModel
            return newViewModel
        }
    }

    public func makeSettingsViewModel() -> SettingsViewModel {
        if let settingsViewModel = self.settingsViewModel {
            return settingsViewModel
        } else {
            let settingsViewModel = SettingsViewModel(authService: authService)
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
        LoginViewModel(authService: authService)
    }

    func makeSignUpViewModel() -> SignUpViewModel {
        SignUpViewModel(authService: authService)
    }

    func cleanup() {
        AppLog.log.debug("ViewModelFactory cleanup, set assistantsViewModel and chatViewModel to nil")
        self.assistantsViewModel?.cleanup()
        self.assistantsViewModel = nil
        self.chatViewModels.values.forEach { $0.cleanup() }
        self.chatViewModels.removeAll()
    }
}
