import Foundation
import Combine
import CueGemini
import CueOpenAI
import CueCommon
import OSLog

@MainActor
public class GeminiChatViewModel: ObservableObject {
    @Published var messageContent: String = ""
    @Published var newMessage: String = ""
    @Published var error: ChatError?

    let liveAPIClient: LiveAPIClient
    @Published private(set) var state: VoiceState = .idle {
        didSet {
            logger.debug("Voice state change to \(self.state.description)")
            switch state {
            case .error(let message):
                error = .sessionError(message)
            default:
                break
            }
        }
    }
    private var messages: [String] = []
    private var messageContents: [ModelContent] = []
    private let apiKey: String
    private let gemini: Gemini
    let toolManager: ToolManager
    private var cancellables = Set<AnyCancellable>()
    let logger = Logger(subsystem: "Gemini", category: "Gemini")

    @Published var availableTools: [OpenAITool] = [] {
        didSet {
            updateTools()
        }
    }
    private var geminiTool: GeminiTool?

    public init(apiKey: String) {
        self.apiKey = apiKey
        self.gemini = Gemini(apiKey: apiKey)
        self.liveAPIClient = LiveAPIClient()
        self.state = liveAPIClient.voiceChatState
        self.toolManager = ToolManager()
        self.availableTools = toolManager.getTools()
        setupLiveAPISubscription()
        #if os(macOS)
        setupToolsSubscription()
        #endif
    }

    private func setupLiveAPISubscription() {
        liveAPIClient.voiceChatStatePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.state = state
                }
                .store(in: &cancellables)

        liveAPIClient.eventsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self = self else { return }
                Task {
                    await self.handleServerMessage(message)
                }
            }
            .store(in: &cancellables)
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

    public func connect() async throws {
        do {
            var tools: [GeminiTool] = []
            if let tool = self.geminiTool {
                tools.append(tool)
            }
            let generationConfig = GenerationConfig(
                responseModalities: [Modality.audio],
                speechConfig: SpeechConfig(voiceName: .aoede)
            )
            let setupDetails = BidiGenerateContentSetup.SetupDetails(
                model: "models/\(Gemini.ChatModel.gemini20FlashExp.id)",
                generationConfig: generationConfig,
                systemInstruction: nil,
                tools: tools
            )
            try await liveAPIClient.connect(apiKey: apiKey, setupDetails: setupDetails)
        } catch {
            self.error = .sessionError(error.localizedDescription)
        }
    }

    public func disconnect() {
        liveAPIClient.endSession()
    }

    public func sendMessage() async {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if !self.state.isConnected {
            do {
                try await sendMessageUseClient()
            } catch {
                self.error = .sessionError(error.localizedDescription)
            }
            return
        }

        do {
            messages.append(newMessage)
            try await sendText(newMessage)
            newMessage = ""
        } catch {
            self.error = .sessionError(error.localizedDescription)
        }
    }

    public func sendText(_ text: String) async throws {
        logger.debug("Sending text message: \(text)")
        let content = BidiGenerateContentClientContent(clientContent: .init(
            turnComplete: true,
            turns: [.init(
                role: "user",
                parts: [.init(text: text)]
            )]
        ))
        try await liveAPIClient.send(content)
    }

    public func sendMessageUseClient() async throws {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let newContent = ModelContent(role: "user", parts: [ModelContent.Part.text(newMessage)])
        messageContents.append(newContent)
        try await generateContent()
    }

    public func generateContent() async throws {
        do {
            var tools: [GeminiTool] = []
            if let tool = self.geminiTool {
                tools.append(tool)
            }
            let response = try await gemini.chat.generateContent(
                model: Gemini.ChatModel.gemini20FlashExp.id,
                messages: messageContents,
                tools: tools
            )

            AppLog.log.debug("Response: \(String(describing: response))")
            let candidateContent = response.candidates[0].content
            messageContents.append(candidateContent)

            // Check for function call and handle it
            if case .functionCall(let functionCall) = candidateContent.parts[0] {
                // Call the tool and get result
                let result = await handleFunctionCall(functionCall)
                // Create function response message
                let functionResponse = ModelContent(
                    role: "user",
                    parts: [.functionResponse(FunctionResponse(
                        id: functionCall.id,
                        name: functionCall.name,
                        response: [
                            "name": .string(functionCall.name),
                            "content": .string(result)
                        ]
                    ))]
                )
                // Add function response to message history
                messageContents.append(functionResponse)
                // Generate new content with the function response
                try await generateContent()
            } else {
                self.messageContent = candidateContent.parts[0].text ?? ""
            }
            newMessage = ""
        } catch {
            AppLog.log.error("Generate content error: \(error)")
        }
    }

    private func updateTools() {
        self.geminiTool = toolManager.getGeminiTool()
    }

    public func clearError() {
        error = nil
    }
}
