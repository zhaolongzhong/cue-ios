import Foundation
import Combine
import CueCommon
import CueOpenAI
import CueAnthropic

@MainActor
public final class AnthropicChatViewModel: ObservableObject {
    private let anthropic: Anthropic
    private let toolManager: ToolManager
    private var tools: [JSONValue] = []
    private var cancellables = Set<AnyCancellable>()

    @Published var model: ChatModel = .claude35Sonnet {
        didSet {
            updateTools()
        }
    }
    @Published var messages: [Anthropic.ChatMessageParam] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [Tool] = [] {
        didSet {
            updateTools()
        }
    }
    @Published var error: ChatError?

    public init(apiKey: String) {
        self.anthropic = Anthropic(apiKey: apiKey)
        self.toolManager = ToolManager()
        self.availableTools = toolManager.getTools()
        #if os(macOS)
        setupToolsSubscription()
        #endif
    }

    private func updateTools() {
        tools = self.toolManager.getToolsJSONValue(model: self.model.id)
    }

    private func setupToolsSubscription() {
        toolManager.mcpToolsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.availableTools = self.toolManager.getTools()
            }
            .store(in: &cancellables)
    }

    func startServer() async {
        #if os(macOS)
        await self.toolManager.startMcpServer()
        #endif
    }

    func sendMessage() async {
        let userMessage = Anthropic.ChatMessageParam.userMessage(
            Anthropic.MessageParam(role: "user", content: [Anthropic.ContentBlock(content: newMessage)])
        )
        messages.append(userMessage)

        isLoading = true
        newMessage = ""

        do {
            let agent = AgentLoop(chatClient: anthropic, toolManager: toolManager, model: model.id)
            let completionRequest = CompletionRequest(model: model.id, tools: tools, toolChoice: "auto")
            let updatedMessages = try await agent.run(with: messages, request: completionRequest)
            self.messages = updatedMessages

        } catch let error as Anthropic.Error {
            let chatError: ChatError = {
                switch error {
                case .apiError(let apiError): return .apiError(apiError.error.message)
                default: return .unknownError(error.localizedDescription)
                }
            }()
            self.error = chatError
            ErrorLogger.log(chatError)
        } catch {
            let chatError = ChatError.unknownError(error.localizedDescription)
            self.error = chatError
            ErrorLogger.log(chatError)
        }

        isLoading = false
    }

    private func handleToolUse(_ toolBlock: Anthropic.ToolUseBlock) async -> String {
        do {
            // Convert tool input to [String: Any]
            var arguments: [String: Any] = [:]
            for (key, value) in toolBlock.input {
                switch value {
                case .string(let str): arguments[key] = str
                case .int(let int): arguments[key] = int
                case .number(let double): arguments[key] = double
                case .bool(let bool): arguments[key] = bool
                case .array(let arr): arguments[key] = arr
                case .object(let dict): arguments[key] = dict
                case .null: arguments[key] = NSNull()
                }
            }

            let result = try await toolManager.callTool(
                name: toolBlock.name,
                arguments: arguments
            )

            return result

        } catch {
            AppLog.log.error("Tool error: \(error)")
            return "Error: \(error.localizedDescription)"
        }
    }

    func clearError() {
        error = nil
    }
}
