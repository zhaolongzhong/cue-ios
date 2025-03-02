//
//  GeminiChatViewModel.swift
//  CueApp
//

import os
import Foundation
import CueCommon
import CueGemini
import CueOpenAI

@MainActor
public class GeminiChatViewModel: BaseChatViewModel {
    @Published var state: VoiceState = .idle {
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

    private let gemini: Gemini
    var geminiTool: GeminiTool?
    let liveAPIClient: LiveAPIClient
    let logger = Logger(subsystem: "Gemini", category: "Gemini")

    public init(apiKey: String) {
        self.gemini = Gemini(apiKey: apiKey)
        self.liveAPIClient = LiveAPIClient()
        self.state = liveAPIClient.voiceChatState

        super.init(
            apiKey: apiKey,
            provider: .gemini,
            model: .gemini20FlashExp,
            richTextFieldState: RichTextFieldState(showVoiceChat: true)
        )

        setupLiveAPISubscription()
    }

    override func updateTools() {
        super.updateTools()
        self.geminiTool = toolManager.getGeminiTool()
    }

    public func sendMessageUseClient() async throws {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let (userMessage, _) = await prepareGeminiMessage()
        addOrUpdateMessage(.gemini(userMessage, stableId: UUID().uuidString), persistInCache: true)
        newMessage = ""
        try await generateContent()
    }

    public func generateContent() async throws {
        do {
            let messageParams = Array(self.cueChatMessages.suffix(maxMessages))
            let geminiChatParams = messageParams.compactMap { $0.geminiChatParam?.modelContent }

            let tools = geminiTool.map { [$0] } ?? []
            let response = try await gemini.chat.generateContent(
                model: model.id,
                messages: geminiChatParams,
                tools: tools
            )
            AppLog.log.debug("Generate content response: \(String(describing: response.candidates[0]))")
            let candidateContent = response.candidates[0].content
            let newMessage = CueChatMessage.gemini(Gemini.ChatMessageParam.assistantMessage(candidateContent), stableId: UUID().uuidString)
            addOrUpdateMessage(newMessage, persistInCache: true)

            for part in candidateContent.parts {
                if case .functionCall(let functionCall) = part {
                    try await handleFunctionCallAndRecursivelyGenerate(functionCall)
                }
                // The text parts are already included in the message we added
            }
        } catch let error as Gemini.Error {
            handleError(error)
        } catch {
            self.error = .sessionError("An unexpected error occurred: \(error.localizedDescription)")
            AppLog.log.error("Generate content error: \(error)")
        }
    }

    private func handleFunctionCallAndRecursivelyGenerate(_ functionCall: GeminiFunctionCall) async throws {
        AppLog.log.debug("Handling function call: \(String(describing: functionCall))")
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
        let newMessage = CueChatMessage.gemini(Gemini.ChatMessageParam.toolMessage(functionResponse), stableId: UUID().uuidString)
        addOrUpdateMessage(newMessage, persistInCache: true)
        try await generateContent()
    }

    private func handleError(_ error: Error) {
        var errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        guard let geminiError = error as? Gemini.Error else {
            self.error = .sessionError(errorMessage)
            AppLog.log.error("Generate content error: \(error)")
            return
        }

        switch geminiError {
        case .apiError(let apiError):
            let message = apiError.error.message

            if message.contains("key expired") || message.contains("key not valid") {
                errorMessage = "Your API key is invalid or has expired. Please renew your API key to continue."
                break
            }
            let detailMessage = apiError.error.details.first { $0.message != nil }?.message ?? message
            errorMessage = "Error: \(detailMessage)"

        case .unexpectedAPIResponse(let message):
            if message.contains("key expired") {
                errorMessage = "Your API key has expired. Please renew your API key to continue."
                break
            }

            errorMessage = "An error occurred while generating content: \(message)"
        default:
            break
        }

        self.error = .sessionError(errorMessage)
        AppLog.log.error("Generate content error: \(error)")
    }

    override func sendMessage() async {
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
            try await sendLiveText(newMessage)
            newMessage = ""
        } catch {
            self.error = .sessionError(error.localizedDescription)
        }
    }
}
