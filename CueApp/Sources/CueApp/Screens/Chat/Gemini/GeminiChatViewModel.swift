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
    @Published var messages: [ModelContent] = []
    @Published var messageParmas: [Gemini.ChatMessageParam] = []
    @Published var model: ChatModel = .gemini20FlashExp {
        didSet {
            updateTools()
        }
    }
    @Published var availableTools: [OpenAITool] = [] {
        didSet {
            updateTools()
        }
    }
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

    let liveAPIClient: LiveAPIClient
    private let apiKey: String
    private let gemini: Gemini
    let toolManager: ToolManager
    private var geminiTool: GeminiTool?
    private var cancellables = Set<AnyCancellable>()
    let logger = Logger(subsystem: "Gemini", category: "Gemini")

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

    private func updateTools() {
        self.geminiTool = toolManager.getGeminiTool()
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

    public func startSession() async {
        do {
            try await connect()
        } catch {
            self.error = .sessionError(String(describing: error))
        }
    }

    public func endSession() async {
        liveAPIClient.endSession()
    }

    public func pauseChat() {
        liveAPIClient.pauseChat()
    }

    public func resumeChat() {
        liveAPIClient.resumeChat()
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
        messages.append(newContent)
        let userMessage = Gemini.ChatMessageParam.userMessage(newContent)
        messageParmas.append(userMessage)
        newMessage = ""
        try await generateContent()
    }

    public func generateContent() async throws {
        do {
            let tools = geminiTool.map { [$0] } ?? []
            let response = try await gemini.chat.generateContent(
                model: model.id,
                messages: messages,
                tools: tools
            )
            AppLog.log.debug("Response: \(String(describing: response))")
            let candidateContent = response.candidates[0].content
            messages.append(candidateContent)
            messageParmas.append(Gemini.ChatMessageParam.assistantMessage(candidateContent))

            if case .functionCall(let functionCall) = candidateContent.parts[0] {
                try await handleFunctionCallAndRecursivelyGenerate(functionCall)
            } else {
                messageContent = candidateContent.parts[0].text ?? ""
            }
        } catch let error as Gemini.Error {
            handleGeminiError(error)
        } catch {
            self.error = .sessionError("An unexpected error occurred: \(error.localizedDescription)")
            AppLog.log.error("Generate content error: \(error)")
        }
    }

    private func handleFunctionCallAndRecursivelyGenerate(_ functionCall: GeminiFunctionCall) async throws {
        let result = await handleFunctionCall(functionCall)
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
        messages.append(functionResponse)
        messageParmas.append(Gemini.ChatMessageParam.toolMessage(functionResponse))
        try await generateContent()
    }

    private func handleGeminiError(_ error: Gemini.Error) {
        switch error {
        case .apiError(let apiError):
            if apiError.error.status == "INVALID_ARGUMENT" {
                if apiError.error.message.contains("API key expired") {
                    self.error = .sessionError("Your API key has expired. Please renew your API key to continue.")
                } else if apiError.error.message.contains("API key not valid") {
                    self.error = .sessionError("Your API key is invalid. Please renew your API key to continue.")
                }
            } else {
                let detailMessage = apiError.error.details.first { $0.message != nil }?.message ?? apiError.error.message
                self.error = .sessionError("Error: \(detailMessage)")
            }
        case .unexpectedAPIResponse(let message):
            if message.contains("API key expired") {
                self.error = .sessionError("Your API key has expired. Please renew your API key to continue.")
            } else {
                self.error = .sessionError("An error occurred while generating content: \(message)")
            }
        default:
            self.error = .sessionError("An unexpected error occurred: \(error.localizedDescription)")
        }
        AppLog.log.error("Generate content error: \(error)")
    }

    public func clearError() {
        error = nil
    }
}
