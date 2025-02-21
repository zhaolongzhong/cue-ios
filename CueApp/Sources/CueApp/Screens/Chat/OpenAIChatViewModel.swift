import Foundation
import Combine
import CueCommon
import CueOpenAI

@MainActor
final class OpenAIChatViewModel: ObservableObject {
    @Published var model: ChatModel = .gpt4oMini {
        didSet {
            updateTools()
        }
    }
    @Published var messages: [OpenAI.ChatMessageParam] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [Tool] = [] {
        didSet {
            updateTools()
        }
    }
    @Published var error: ChatError?
    @Published var observedApp: AccessibleApplication?
    #if os(macOS)
    private var textAreaContent: TextAreaContent?
    #endif
    @Published var focusedLines: String?

    private let openAI: OpenAI
    private let toolManager: ToolManager
    private var tools: [JSONValue] = []
    #if os(macOS)
    private let axManager: AXManager
    #endif
    private var cancellables = Set<AnyCancellable>()

    init(apiKey: String) {
        self.openAI = OpenAI(apiKey: apiKey)
        self.toolManager = ToolManager()
        #if os(macOS)
        self.axManager = AXManager()
        #endif
        self.availableTools = toolManager.getTools()
        updateTools()
        setupToolsSubscription()
        setupTextAreaContentSubscription()
    }

    private func updateTools() {
        tools = self.toolManager.getToolsJSONValue(model: self.model.id)
    }

    private func setupToolsSubscription() {
        toolManager.mcpToolsPublisher
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.availableTools = self.toolManager.getTools()
            }
            .store(in: &cancellables)
    }

    private func setupTextAreaContentSubscription() {
        #if os(macOS)
        axManager.$textAreaContentList
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.textAreaContent = newValue.first
                self.focusedLines = self.textAreaContent?.focusedLines
            }
            .store(in: &cancellables)
        #endif
    }

    func startServer() async {
        await self.toolManager.startMcpServer()
    }

    func updateObservedApplication(to newApp: AccessibleApplication) {
        #if os(macOS)
        self.axManager.updateObservedApplication(to: newApp)
        #endif
        self.observedApp = newApp
    }

    func stopObserveApp() {
        #if os(macOS)
        self.axManager.stopObserving()
        self.observedApp = nil
        self.textAreaContent = nil
        #endif
    }

    func sendMessage() async {
        var messageParams = Array(self.messages.suffix(10))

        #if os(macOS)
        if let textAreaContent = self.axManager.textAreaContentList.first {
            let context = textAreaContent.getTextAreaContext()
            let contextMessage = OpenAI.ChatMessageParam.assistantMessage(
                OpenAI.AssistantMessage(role: Role.assistant.rawValue, content: context)
            )
            messageParams.append(contextMessage)
        }
        #endif

        // Add the user's new message.
        let userMessage = OpenAI.ChatMessageParam.userMessage(
            OpenAI.MessageParam(role: Role.user.rawValue, content: newMessage)
        )
        self.messages.append(userMessage)
        messageParams.append(userMessage)

        isLoading = true
        newMessage = ""

        do {
            let agent = AgentLoop(chatClient: openAI, toolManager: toolManager, model: model.id)
            let completionRequest = CompletionRequest(model: model.id, tools: tools, toolChoice: "auto")
            let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)
            messages = updatedMessages
        } catch {
            let chatError = ChatError.unknownError(error.localizedDescription)
            self.error = chatError
            ErrorLogger.log(chatError)
        }
        isLoading = false
    }

    func clearError() {
        error = nil
    }
}
