//
//  GeminiChatViewModel.swift
//  CueApp
//

import os
import Foundation
import Combine
import Dependencies
import CueCommon
import CueGemini
import CueOpenAI

@MainActor
public class GeminiChatViewModel: BaseChatViewModel, ChatViewModel {
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
            model: .gemini20FlashExp
        )

        setupLiveAPISubscription()
    }

    override func updateTools() {
        super.updateTools()
        self.geminiTool = toolManager.getGeminiTool()
    }

    public func sendMessageUseClient() async throws {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let newContent = ModelContent(role: "user", parts: [ModelContent.Part.text(newMessage)])
        let userMessage = Gemini.ChatMessageParam.userMessage(newContent)
        cueChatMessages.append(.gemini(userMessage))
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
            AppLog.log.debug("Response: \(String(describing: response))")
            let candidateContent = response.candidates[0].content
            let newMessage = CueChatMessage.gemini(Gemini.ChatMessageParam.assistantMessage(candidateContent), stableId: UUID().uuidString)
            addOrUpdateMessage(newMessage)

            if case .functionCall(let functionCall) = candidateContent.parts[0] {
                try await handleFunctionCallAndRecursivelyGenerate(functionCall)
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
        let newMessage = CueChatMessage.gemini(Gemini.ChatMessageParam.toolMessage(functionResponse), stableId: UUID().uuidString)
        addOrUpdateMessage(newMessage)
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
