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
    private var baseChatViewModels: [String: BaseChatViewModel] = [:]
    private var conversationViewModels: [String: ConversationsViewModel] = [:]
    private var settingsViewModel: SettingsViewModel?
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

    func makeAssistantChatViewModelV2(assistant: Assistant, conversationId: String = "") -> AssistantChatViewModelV2 {
        if let existing = baseChatViewModels[assistant.id] as? AssistantChatViewModelV2 {
            return existing
        } else {
            let newViewModel = AssistantChatViewModelV2(assistant: assistant, conversationId: conversationId)
            baseChatViewModels[assistant.id] = newViewModel
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

    func makeConversationViewModel(provider: Provider) -> ConversationsViewModel {
        if let existing = conversationViewModels[provider.id] {
            return existing
        } else {
            let newViewModel = ConversationsViewModel(provider: provider)
            conversationViewModels[provider.id] = newViewModel
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

    func makeBaseChatViewModel(
        _ conversationId: String,
        provider: Provider,
        richTextFieldState: RichTextFieldState? = nil
    ) -> BaseChatViewModel {
        if let existing = baseChatViewModels[conversationId] {
            return existing
        } else {
            switch provider {
            case .openai:
                let newViewModel = self.makeOpenAIChatViewModel(conversationId)
                baseChatViewModels[conversationId] = newViewModel
                return newViewModel
            case .anthropic:
                let newViewModel = self.makeAnthropicChatViewModel(conversationId)
                baseChatViewModels[conversationId] = newViewModel
                return newViewModel
            case .gemini:
                let newViewModel = self.makeGeminiChatViewModel(conversationId)
                baseChatViewModels[conversationId] = newViewModel
                return newViewModel
            case .local:
                let newViewModel = self.makeLocalChatViewModel(conversationId)
                baseChatViewModels[conversationId] = newViewModel
                return newViewModel
            case .cue:
                let newViewModel = self.makeCueChatViewModel(conversationId: conversationId)
                baseChatViewModels[conversationId] = newViewModel
                return newViewModel
            }
        }
    }

    public func makeOpenAILiveChatViewModel(conversationId: String) -> OpenAILiveChatViewModel {
        let realtimeChatViewModel = OpenAILiveChatViewModel(conversationId: conversationId, apiKey: providersViewModel.openAIKey)
        return realtimeChatViewModel
    }

    public func makeOpenAIChatViewModel(_ conversationId: String) -> OpenAIChatViewModel {
        let openAIChatViewModel = OpenAIChatViewModel(conversationId: conversationId, apiKey: providersViewModel.openAIKey)
        return openAIChatViewModel
    }

    public func makeGeminiChatViewModel(_ conversationId: String) -> GeminiChatViewModel {
        let geminiChatViewModel = GeminiChatViewModel(conversationId: conversationId, apiKey: providersViewModel.geminiKey)
        return geminiChatViewModel
    }

    public func makeAnthropicChatViewModel(_ conversationId: String) -> AnthropicChatViewModel {
        let anthropicChatViewModel = AnthropicChatViewModel(conversationId: conversationId, apiKey: providersViewModel.anthropicKey)
        return anthropicChatViewModel
    }

    public func makeCueChatViewModel(conversationId: String) -> CueChatViewModel {
        let cueChatViewModel = CueChatViewModel(conversationId: conversationId)
        return cueChatViewModel
    }

    public func makeLocalChatViewModel(_ conversationId: String) -> LocalChatViewModel {
        let localChatViewModel = LocalChatViewModel(conversationId: conversationId, apiKey: providersViewModel.openAIKey)
        return localChatViewModel
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
        self.baseChatViewModels.removeAll()
    }
}
