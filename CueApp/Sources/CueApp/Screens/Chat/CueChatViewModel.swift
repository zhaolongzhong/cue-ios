import Foundation
import Combine
import CueCommon
import CueOpenAI
import CueAnthropic

@MainActor
final class CueChatViewModel: ObservableObject {
    private let cueClient: CueClient
    private let toolManager: ToolManager
    private let rateLimitManager: RateLimitManager
    private var tools: [JSONValue] = []
    private var cancellables = Set<AnyCancellable>()

    @Published var model: ChatModel = .gpt4oMini {
        didSet {
            updateTools()
        }
    }
    
    @Published var remainingRequests: Int = 50
    @Published var rateLimitInfo: String = ""
    @Published var messages: [CueChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [Tool] = [] {
        didSet {
            updateTools()
        }
    }
    @Published var error: ChatError?

    init() {
        self.cueClient = CueClient()
        self.toolManager = ToolManager()
        self.rateLimitManager = RateLimitManager()
        self.availableTools = toolManager.getTools()
        updateTools()
        setupToolsSubscription()
        updateRateLimitInfo()
    }
    
    private func updateRateLimitInfo() {
        let modelId = model.rawValue
        let config = RateLimitConfig.defaultConfigs[modelId] ?? RateLimitConfig.defaultConfigs["default"]!
        let (_, remaining, _) = rateLimitManager.checkRateLimit(for: modelId)
        remainingRequests = remaining
        rateLimitInfo = "(\(remaining)/\(config.requestLimit) requests)"
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
        // Check rate limit before proceeding
        let modelId = model.rawValue
        let (isLimited, _, timeUntilReset) = rateLimitManager.checkRateLimit(for: modelId)
        if isLimited {
            if let remainingTime = timeUntilReset {
                error = ChatError.apiError(RateLimitError.limitExceeded(remainingTime: remainingTime).localizedDescription)
            } else {
                error = ChatError.apiError("Rate limit exceeded for \(model.displayName). Please try again later.")
            }
            return
        }
        
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

        do {
            let agent = AgentLoop(chatClient: cueClient, toolManager: toolManager, model: model.rawValue)
            let completionRequest = CompletionRequest(model: model.rawValue, tools: tools, toolChoice: "auto")
            let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)
            messages = updatedMessages
            
            // Increment request count and update UI only on successful request
            rateLimitManager.incrementRequestCount(for: modelId)
            updateRateLimitInfo()
        } catch {
            ErrorLogger.log(ChatError.unknownError(error.localizedDescription))
            self.error = ChatError.unknownError(error.localizedDescription)
        }
        isLoading = false
    }

    func clearError() {
        error = nil
    }
}
