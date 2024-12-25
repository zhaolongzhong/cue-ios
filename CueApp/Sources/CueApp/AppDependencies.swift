import SwiftUI
import Combine
import Dependencies

protocol Cleanable {
    func cleanup() async
}

@MainActor
public class AppDependencies: ObservableObject, AppStateDelegate {
    @Dependency(\.assistantRepository) private var assistantRepository
    @Dependency(\.messageRepository) private var messageRepository
    @Dependency(\.clientStatusService) public var clientStatusService

    public var appStateViewModel: AppStateViewModel

    private lazy var _viewModelFactory: ViewModelFactory = {
        ViewModelFactory()
    }()

    public var viewModelFactory: ViewModelFactory {
        _viewModelFactory
    }

    public init() {
        self.appStateViewModel = AppStateViewModel()
        self.appStateViewModel.delegate = self
    }

    public func onLogout() async {
        AppLog.log.debug("AppDependencies handleLogout")
        self.viewModelFactory.cleanup()
        await self.assistantRepository.cleanup()
        await self.messageRepository.cleanup()
    }
}

@MainActor
public class ViewModelFactory {
    private var assistantsViewModel: AssistantsViewModel?
    private var chatViewModels: [String: ChatViewModel] = [:]
    private var settingsViewModel: SettingsViewModel?
    private var apiKeysViewModel: APIKeysViewModel?

    func makeAssistantsViewModel() -> AssistantsViewModel {
        if let assistantsViewModel = self.assistantsViewModel {
            return assistantsViewModel
        }

        self.assistantsViewModel = AssistantsViewModel()
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
            let settingsViewModel = SettingsViewModel()
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
        LoginViewModel()
    }

    func makeSignUpViewModel() -> SignUpViewModel {
        SignUpViewModel()
    }

    func cleanup() {
        AppLog.log.debug("ViewModelFactory cleanup, set assistantsViewModel and chatViewModel to nil")
        self.assistantsViewModel?.cleanup()
        self.assistantsViewModel = nil
        self.chatViewModels.values.forEach { $0.cleanup() }
        self.chatViewModels.removeAll()
    }
}
