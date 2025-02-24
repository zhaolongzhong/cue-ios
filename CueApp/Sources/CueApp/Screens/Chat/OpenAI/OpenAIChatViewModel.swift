import Foundation
import Combine
import CueCommon
import CueOpenAI

@MainActor
public final class OpenAIChatViewModel: ObservableObject {
    @Published var model: ChatModel = .gpt4oMini {
        didSet {
            updateTools()
        }
    }
    @Published var messages: [OpenAI.ChatMessageParam] = []
    @Published var newMessage: String = ""
    @Published var attachments: [Attachment] = []
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

    @Published var apiKey: String
    private let openAI: OpenAI
    private let toolManager: ToolManager
    private var tools: [JSONValue] = []
    #if os(macOS)
    private let axManager: AXManager
    #endif
    private var cancellables = Set<AnyCancellable>()

    public init(apiKey: String) {
        self.apiKey = apiKey
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

        do {
            var contentBlocks: [OpenAI.ContentBlock] = []

            if !newMessage.isEmpty {
                let textBlock = OpenAI.ContentBlock(
                    type: .text,
                    text: newMessage
                )
                contentBlocks.append(textBlock)
            }

            // Process attachments
            for attachment in attachments {
                switch attachment.type {
                case .document:
                    let fullText = try await AttachmentUtil.extractText(from: attachment)
                    let maxCharacters = 20000
                    let truncatedText = fullText.count > maxCharacters
                        ? String(fullText.prefix(maxCharacters)) + " [truncated]"
                        : fullText
                    let prefixedText = "<file_name>\(attachment.name)<file_name>" + truncatedText
                    let documentBlock = OpenAI.ContentBlock(
                        type: .text,
                        text: prefixedText
                    )
                    contentBlocks.append(documentBlock)
                case .image:
                    if let imageBlock = try await AttachmentUtil.processImage(from: attachment) {
                        contentBlocks.append(imageBlock)
                    }
                }
            }

            // Create a MessageParam with content blocks
            let userMessage: OpenAI.ChatMessageParam
            if contentBlocks.isEmpty {
                // If no content blocks were created, use a simple empty text block
                userMessage = .userMessage(
                    OpenAI.MessageParam(
                        role: "user",
                        contentBlocks: [OpenAI.ContentBlock(type: .text, text: "")]
                    )
                )
            } else {
                userMessage = .userMessage(
                    OpenAI.MessageParam(
                        role: "user",
                        contentBlocks: contentBlocks
                    )
                )
            }

            self.messages.append(userMessage)
            messageParams.append(userMessage)
        } catch {
            AppLog.log.error("Error processing message content: \(error.localizedDescription)")
        }

        isLoading = true
        newMessage = ""
        attachments.removeAll()

        do {
            let agent = AgentLoop(chatClient: openAI, toolManager: toolManager, model: model.id)
            let completionRequest = CompletionRequest(model: model.id, tools: tools, toolChoice: "auto")
            let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)
            messages.append(contentsOf: updatedMessages)
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

    func addAttachment(_ attachment: Attachment) {
        attachments.append(attachment)
    }
}
