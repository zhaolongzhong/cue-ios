import Foundation
import Combine
import CueCommon
import CueOpenAI
import CueAnthropic

@MainActor
final class CueChatViewModel: ObservableObject {
    private let cueClient: CueClient
    private let toolManager: ToolManager
    private var tools: [JSONValue] = []
    private var cancellables = Set<AnyCancellable>()
    private var currentAgent: AgentLoop<CueClient>?

    @Published var model: ChatModel = .gpt4oMini {
        didSet {
            updateTools()
        }
    }
    @Published var messages: [CueChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [Tool] = [] {
        didSet {
            updateTools()
        }
    }
    @Published var error: ChatError?
    @Published var agentState: AgentState = .idle

    init() {
        self.cueClient = CueClient()
        self.toolManager = ToolManager()
        self.availableTools = toolManager.getTools()
        updateTools()
        setupToolsSubscription()
    }

    private func updateTools() {
        tools = self.toolManager.getToolsJSONValue(model: self.model.id)
    }

    private func setupToolsSubscription() {
        toolManager.mcpToolsPublisher
            .sink { [weak self] _ in
                self?.availableTools = self?.toolManager.getTools() ?? []
            }
            .store(in: &cancellables)
    }

    func startServer() async {
        await toolManager.startMcpServer()
    }

    func sendMessage() async {
        var messageParams = Array(messages.suffix(10))
        let userMessage = CueChatMessage.anthropic(
            Anthropic.ChatMessageParam.userMessage(
                Anthropic.MessageParam(role: "user", content: [Anthropic.ContentBlock(content: newMessage)])
            )
        )
        messages.append(userMessage)
        messageParams.append(userMessage)

        isLoading = true
        newMessage = ""
        error = nil

        // Create and store new agent
        let agent = AgentLoop(chatClient: cueClient, toolManager: toolManager, model: model.rawValue)
        currentAgent = agent
        
        // Observe agent state
        Task { @MainActor in
            for await state in agent.$state.values {
                self.agentState = state
                self.isLoading = state != .idle && state != .stopped && state != .error("")
            }
        }

        do {
            let completionRequest = CompletionRequest(model: model.rawValue, tools: tools, toolChoice: "auto")
            let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)
            if agent.state != .stopped {
                messages = updatedMessages
            }
        } catch {
            self.error = ChatError.unknownError(error.localizedDescription)
            ErrorLogger.log(ChatError.unknownError(error.localizedDescription))
        }
        
        isLoading = false
        if error == nil && agent.state != .stopped {
            agentState = .idle
        }
    }
    
    func stopAgent() {
        currentAgent?.stop()
        isLoading = false
    }

    func clearError() {
        error = nil
    }
}
