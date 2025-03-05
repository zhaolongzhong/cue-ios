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
    public var providersViewModel: ProvidersViewModel

    private lazy var _viewModelFactory: ViewModelFactory = {
        ViewModelFactory(providersViewModel: providersViewModel)
    }()

    public var viewModelFactory: ViewModelFactory {
        _viewModelFactory
    }

    public init() {
        self.providersViewModel = ProvidersViewModel()
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
    private var homeViewModel: HomeViewModel?
    private var chatViewModels: [String: AssistantChatViewModel] = [:]
    private var settingsViewModel: SettingsViewModel?
    private var openAILiveChatViewModel: OpenAILiveChatViewModel?
    private var geminiChatViewModel: GeminiChatViewModel?
    private var openAIChatViewModel: OpenAIChatViewModel?
    private var anthropicChatViewModel: AnthropicChatViewModel?
    private var cueChatViewModel: CueChatViewModel?
    private var localChatViewModel: LocalChatViewModel?
    private var emailScreenViewModel: EmailScreenViewModel?
    private var mcpServersViewModel: MCPServersViewModel?

    let providersViewModel: ProvidersViewModel

    public init(providersViewModel: ProvidersViewModel) {
        self.providersViewModel = providersViewModel
    }

    func makeHomeViewModel() -> HomeViewModel {
        if let homeViewModel = self.homeViewModel {
            return homeViewModel
        }

        let homeViewModel = HomeViewModel()
        self.homeViewModel = homeViewModel
        return homeViewModel
    }

    func makeAssistantsViewModel() -> AssistantsViewModel {
        if let assistantsViewModel = self.assistantsViewModel {
            return assistantsViewModel
        }

        let assistantsViewModel = AssistantsViewModel()
        self.assistantsViewModel = assistantsViewModel
        return assistantsViewModel
    }

    func makeAssistantChatViewModel(assistant: Assistant) -> AssistantChatViewModel {
        if let existing = chatViewModels[assistant.id] {
            return existing
        } else {
            let newViewModel = AssistantChatViewModel(assistant: assistant)
            chatViewModels[assistant.id] = newViewModel
            return newViewModel
        }
    }

    func makeAssistantChatViewModelBy(id: String) -> AssistantChatViewModel? {
        guard let assistant = assistantsViewModel?.getAssistant(for: id) else {
            return nil
        }
        if let existing = chatViewModels[assistant.id] {
            return existing
        } else {
            let newViewModel = AssistantChatViewModel(assistant: assistant)
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

    public func makeOpenAILiveChatViewModel(conversationId: String?) -> OpenAILiveChatViewModel {
        if let openAILiveChatViewModel = self.openAILiveChatViewModel {
            return openAILiveChatViewModel
        } else {
            let realtimeChatViewModel = OpenAILiveChatViewModel(conversationId: conversationId, apiKey: providersViewModel.openAIKey)
            self.openAILiveChatViewModel = realtimeChatViewModel
            return realtimeChatViewModel
        }
    }

    public func makeOpenAIChatViewModel(_ conversationId: String? = nil) -> OpenAIChatViewModel {
        if let openAIChatViewModel = self.openAIChatViewModel {
            return openAIChatViewModel
        } else {
            let openAIChatViewModel = OpenAIChatViewModel(conversationId: conversationId, apiKey: providersViewModel.openAIKey)
            self.openAIChatViewModel = openAIChatViewModel
            return openAIChatViewModel
        }
    }

    public func makeGeminiChatViewModel(_ conversationId: String? = nil) -> GeminiChatViewModel {
        if let geminiChatViewModel = self.geminiChatViewModel {
            return geminiChatViewModel
        } else {
            let geminiChatViewModel = GeminiChatViewModel(conversationId: conversationId, apiKey: providersViewModel.geminiKey)
            self.geminiChatViewModel = geminiChatViewModel
            return geminiChatViewModel
        }
    }

    public func makeAnthropicChatViewModel(conversationId: String? = nil) -> AnthropicChatViewModel {
        let anthropicChatViewModel = AnthropicChatViewModel(conversationId: conversationId, apiKey: providersViewModel.anthropicKey)
        self.anthropicChatViewModel = anthropicChatViewModel
        return anthropicChatViewModel
    }

    public func makeCueChatViewModel(conversationId: String? = nil) -> CueChatViewModel {
        if let cueChatViewModel = self.cueChatViewModel {
            return cueChatViewModel
        } else {
            let cueChatViewModel = CueChatViewModel(conversationId: conversationId)
            self.cueChatViewModel = cueChatViewModel
            return cueChatViewModel
        }
    }

    public func makeLocalChatViewModel(conversationId: String? = nil) -> LocalChatViewModel {
        if let localChatViewModel = self.localChatViewModel {
            return localChatViewModel
        } else {
            let localChatViewModel = LocalChatViewModel(apiKey: providersViewModel.openAIKey)
            self.localChatViewModel = localChatViewModel
            return localChatViewModel
        }
    }

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel()
    }

    func makeSignUpViewModel() -> SignUpViewModel {
        SignUpViewModel()
    }

    func makeEmailScreenViewModel() -> EmailScreenViewModel {
        if let emailScreenViewModel = self.emailScreenViewModel {
            return emailScreenViewModel
        }

        let emailScreenViewModel = EmailScreenViewModel()
        self.emailScreenViewModel = emailScreenViewModel
        return emailScreenViewModel
    }

    func makeMCPServersViewModel() -> MCPServersViewModel {
        if let mcpServersViewModel = self.mcpServersViewModel {
            return mcpServersViewModel
        }

        let mcpServersViewModel = MCPServersViewModel()
        self.mcpServersViewModel = mcpServersViewModel
        return mcpServersViewModel
    }

    func cleanup() {
        AppLog.log.debug("ViewModelFactory cleanup, set assistantsViewModel and chatViewModel to nil")
        self.assistantsViewModel?.cleanup()
        self.assistantsViewModel = nil
        self.chatViewModels.values.forEach { $0.cleanup() }
        self.chatViewModels.removeAll()
    }
}
