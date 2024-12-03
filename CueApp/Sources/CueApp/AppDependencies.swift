import SwiftUI

@MainActor
public class AppDependencies: ObservableObject {
    @Published public var authService: AuthService
    @Published public var assistantService: AssistantService
    @Published public var conversationManager: ConversationManager
    @Published public var webSocketStore: WebSocketManagerStore
    @Published public var appState: AppStateViewModel

    private lazy var _viewModelFactory: ViewModelFactory = {
        ViewModelFactory(dependencies: self)
    }()

    public var viewModelFactory: ViewModelFactory {
        _viewModelFactory
    }

    public init() {
        self.webSocketStore = WebSocketManagerStore()
        self.conversationManager = ConversationManager()
        let authService = AuthService()
        self.authService = authService
        self.appState = AppStateViewModel(authService: authService)
        self.assistantService = AssistantService()

    }
}

@MainActor
public class ViewModelFactory {
    let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }
}
