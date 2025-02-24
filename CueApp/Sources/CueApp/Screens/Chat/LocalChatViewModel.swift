import Foundation
import Combine
import CueCommon
import CueOpenAI
import os

@MainActor
public final class LocalChatViewModel: ObservableObject {
    @Published var attachments: [Attachment] = []
    @Published var model: ChatModel = .deepSeekR17B { didSet { updateTools() } }
    @Published var isStreamingEnabled: Bool = true
    @Published var isToolEnabled: Bool = true
    @Published var baseURL: String = ""
    @Published var messages: [CueChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var availableTools: [Tool] = [] { didSet { updateTools() } }
    @Published var error: ChatError?
    @Published var observedApp: AccessibleApplication?
    @Published var focusedLines: String?

    // Track streaming state for each message via its id.
    var streamingStates: [String: StreamingState] = [:]
    @Published private(set) var streamingMessageId: String?
    @Published private(set) var isStreaming = false
    @Published var streamingMessageContent: String = ""

    private let localClient: LocalClient
    private let toolManager: ToolManager
    private var tools: [JSONValue] = []
    #if os(macOS)
    private let axManager: AXManager
    private var textAreaContent: TextAreaContent?
    #endif
    private var cancellables = Set<AnyCancellable>()
    var maxMessages: Int = 10
    var maxTurn: Int = 10
    private var currentTurn: Int = 0
    public let logger = Logger(subsystem: "local_provider", category: "LocalChatViewModel")

    public init(apiKey: String = "") {
        self.localClient = LocalClient()
        self.toolManager = ToolManager()
        #if os(macOS)
        self.axManager = AXManager()
        #endif
        self.availableTools = toolManager.getTools()
        updateTools()
        setupToolsSubscription()
        setupTextAreaContentSubscription()
    }

    func resetMessages() {
        self.messages.removeAll()
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
        var messageParams  = Array(self.messages.suffix(maxMessages))
        #if os(macOS)
        if let textAreaContent = self.axManager.textAreaContentList.first {
            let context = textAreaContent.getTextAreaContext()
            let contextMessage = OpenAI.ChatMessageParam.assistantMessage(
                OpenAI.AssistantMessage(role: Role.assistant.rawValue, content: context)
            )
            messageParams.append(.local(contextMessage))
        }
        #endif

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
                    do {
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
                    } catch {
                        AppLog.log.error("Error when processing attachment: \(error)")
                    }
                case .image:
                    break
                }
            }

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

        self.messages.append(CueChatMessage.openAI(userMessage))

        // Use string content type for request
        let simpleMessage = OpenAI.ChatMessageParam.userMessage(
            OpenAI.MessageParam(role: Role.user.rawValue, content: .string(userMessage.content.contentAsString))
        )
        messageParams.append(CueChatMessage.openAI(simpleMessage))

        isLoading = true
        newMessage = ""
        attachments.removeAll()
        currentTurn = 0

        do {
            if isStreamingEnabled {
                try await sendMessageStream(messageParams)
            } else {
                try await sendMessageWithoutStream(messageParams)
            }
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

    func prepareForMessageParams(_ messageParams: [CueChatMessage]) -> [OpenAI.ChatMessageParam] {
        let openAIChatMessageParams = messageParams.compactMap { message -> OpenAI.ChatMessageParam? in
            switch message {
            case .local(let param, _, _), .openAI(let param):
                switch param {
                case .userMessage(let userMessage):
                    return OpenAI.ChatMessageParam.userMessage(.init(role: "user", contentString: userMessage.contentAsString))
                default:
                    return param
                }
            default:
                return nil
            }
        }
        return openAIChatMessageParams
    }

    func sendMessageWithoutStream(_ chatMessages: [CueChatMessage]) async throws {
        logger.debug("Send message without streaming")
        let messageParams = prepareForMessageParams(chatMessages)

        let completionRequest = CompletionRequest(
            model: model.id,
            tools: isToolEnabled ? tools : [],
            toolChoice: isToolEnabled ? "auto" : nil
        )
        let agent = AgentLoop(chatClient: localClient, toolManager: toolManager, model: model.id)
        let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)
        messages.append(contentsOf: updatedMessages.map { .openAI($0) })
        addStreamingStateToNewMessages()
    }

    func sendMessageStream(_ chatMessages: [CueChatMessage]) async throws {
        logger.debug("Send message with streaming")
        let messageParams = prepareForMessageParams(chatMessages)

        // Initialize a new streaming state for this message.
        let id = UUID().uuidString
        streamingMessageId = id
        streamingStates[id] = StreamingState(startTime: Date(), isStreamingMode: true)

        isStreaming = true

        do {
            try await localClient.sendStream(
                model: self.model.rawValue,
                messages: messageParams,
                tools: isToolEnabled ? tools : [],
                toolChoice: isToolEnabled ? "auto" : nil
            ) { [weak self] chunk in
                guard let self = self, let id = self.streamingMessageId else { return }

                self.streamingStates[id]?.chunks.append(chunk)

                if let content = chunk.message.content {
                    self.streamingStates[id]?.content += content
                    self.updateStreamingMessage(for: id, content: self.streamingStates[id]?.content ?? "", isComplete: chunk.done)
                }
                if let toolCalls = chunk.message.toolCalls {
                    logger.debug("Tool calls: \(toolCalls)")
                    self.streamingStates[id]?.toolCalls.append(contentsOf: toolCalls)
                    self.updateStreamingMessage(for: id, content: self.streamingStates[id]?.content ?? "", isComplete: chunk.done)
                }

                if chunk.done {
                    logger.debug("Chunk done: \(String(describing: chunk)), \(String(describing: self.streamingStates[id]?.content))")
                    self.streamingStates[id]?.isComplete = true
                    self.streamingStates[id]?.endTime = chunk.createdAt
                    // Clear the current streaming id once finished.
                    self.streamingMessageId = nil
                    self.isStreaming = false
                    self.updateStreamingMessage(for: id, content: self.streamingStates[id]?.content ?? "", isComplete: chunk.done)
                    if let toolCalls = self.streamingStates[id]?.toolCalls, !toolCalls.isEmpty {
                        Task {
                            await handleStreamingToolCalls(toolCalls)
                        }
                    }
                }
            }
        } catch {
            let chatError = ChatError.unknownError(error.localizedDescription)
            self.error = chatError
            ErrorLogger.log(chatError)
            self.streamingMessageId = nil
            self.isStreaming = false
        }
        isLoading = false
    }

    func handleStreamingToolCalls(_ toolCalls: [ToolCall]) async {
        logger.debug("Handle streaming tool calls: \(toolCalls)")
        guard toolCalls.isEmpty == false else {
            return
        }
        let toolMessages = await toolManager.callTools(toolCalls)
        for tm in toolMessages {
            let nativeToolMsg = OpenAI.ChatMessageParam.toolMessage(tm)
            messages.append(.openAI(nativeToolMsg))
        }
        currentTurn += 1
        if currentTurn >= maxTurn {
            logger.debug("Max turn reached, stopping streaming.")
            return
        }
        Task {
            let messageParams  = Array(self.messages.suffix(maxMessages))
            try await sendMessageStream(messageParams)
        }
    }
}

// MARK: Streaming
extension LocalChatViewModel {
    private func updateStreamingMessage(for id: String, content: String, isComplete: Bool = false) {
        var updatedContent = content
        if updatedContent.hasPrefix("<think>"), updatedContent.contains("</think>"), streamingStates[id]?.thinkingEndTime == nil {
            streamingStates[id]?.thinkingEndTime = Date()
        }
        if updatedContent.hasPrefix("<think>"), !updatedContent.contains("</think>") {
            updatedContent += "</think>"
        }
        streamingStates[id]?.isComplete = isComplete
        if let index = messages.firstIndex(where: { $0.id == id }) {
            let newMessage = CueChatMessage.streamingMessage(
                id: id,
                content: updatedContent,
                toolCalls: streamingStates[id]?.toolCalls ?? [],
                streamingState: streamingStates[id]
            )
            messages[index] = newMessage
        } else {
            let newMessage = CueChatMessage.streamingMessage(
                id: id,
                content: updatedContent,
                toolCalls: streamingStates[id]?.toolCalls ?? [],
                streamingState: streamingStates[id]
            )
            messages.append(newMessage)
        }
        if streamingMessageId == id {
            self.streamingMessageContent = updatedContent
        }
    }

    // Call this at the end of sendMessageWithoutStream()
    func addStreamingStateToNewMessages() {
        // After receiving messages, check for thinking blocks and add StreamingState
        processNonStreamingThinkingBlocks()
    }

    func processNonStreamingThinkingBlocks() {
       for (index, message) in messages.enumerated() {
           // Check if message has thinking blocks but no streaming state
           if message.hasThinkingBlocks && message.streamingState == nil {
               // Extract thinking block IDs
               let thinkingBlockIds = message.extractThinkingBlockIds(from: message.content.contentAsString)
               // Create basic StreamingState for tracking thinking blocks
               var newState = StreamingState(
                content: message.content.contentAsString,
                   isComplete: true,
                   startTime: nil,
                   thinkingEndTime: nil,
                   endTime: nil,
                   isStreamingMode: false
               )

               // Initialize all blocks as expanded by default
               for blockId in thinkingBlockIds {
                   newState.expandedThinkingBlocks[blockId] = true
               }

               // Update the message with the new state
               messages[index] = message.updateStreamingState(newState)
           }
       }
   }
}
