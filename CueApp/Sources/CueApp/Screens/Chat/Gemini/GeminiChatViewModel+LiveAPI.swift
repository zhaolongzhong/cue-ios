import Foundation
import CueGemini

extension GeminiChatViewModel {
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

    func setupLiveAPISubscription() {
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

    public func sendLiveText(_ text: String) async throws {
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

    func handleServerMessage(_ message: ServerMessage) async {
        switch message {
        case .setupComplete:
            logger.debug("Setup completed")
        case .serverContent(let content):
            await handleModelTurn(content.modelTurn)
            if content.turnComplete == true {
                await handleTurnComplete()
            }
        case .toolCall(let toolCall):
            if let functionCalls = toolCall.functionCalls {
                await handleToolCall(functionCalls)
            }
        case .toolCallCancellation(let cancellation):
            if let ids = cancellation.ids {
                await handleToolCallCancellation(ids)
            }
        }
    }

    private func handleModelTurn(_ modelTurn: ModelContent) async {
        guard !modelTurn.parts.isEmpty else { return }

        for part in modelTurn.parts {
            await handlePart(part)
        }
    }

    private func handlePart(_ part: ModelContent.Part) async {
        switch part {
        case .text(let content):
            logger.debug("Processing text content: \(content)")
        case .functionCall(let functionCall):
            logger.debug("Processing function call")
            _ = await handleFunctionCall(functionCall)
        default:
            break
        }
    }

    func handleFunctionCall(_ functionCall: FunctionCall) async -> String {
        // Convert JSONValue arguments to [String: Any] using the extension
        let arguments = functionCall.args.toNativeDictionary
        do {
            let result = try await toolManager.callTool(
                name: functionCall.name,
                arguments: arguments
            )
            return result
        } catch {
            AppLog.log.error("Error calling tool: \(error.localizedDescription)")
            return "Error calling tool: \(error.localizedDescription)"
        }
    }

    private func handleTurnComplete() async {
        logger.debug("Turn completed")
    }

    private func handleToolCallCancellation(_ ids: [String]) async {
        logger.debug("Tool calls cancelled: \(ids)")

    }

    private func handleToolCall(_ functionCalls: [FunctionCall]) async {
        var functionReponses: [FunctionResponse] = []
        for functionCall in functionCalls {
            let id = functionCall.id
            let result = await handleFunctionCall(functionCall)
            let functionResponse = FunctionResponse(
                id: id,
                name: functionCall.name,
                response: [
                    "result": .string(result)
                ]
            )
            functionReponses.append(functionResponse)
        }

        let toolResponse = BidiGenerateContentToolResponse(toolResponse: .init(functionResponses: functionReponses))
        do {
            _ = try await sendToolResponse(toolResponse)
        } catch {
            AppLog.log.error("Error sending tool response: \(error.localizedDescription)")
        }
    }

    private func sendToolResponse(_ toolResponse: BidiGenerateContentToolResponse) async throws {
        do {
            AppLog.log.debug("Send tool response: \(String(describing: toolResponse))")
            try await liveAPIClient.send(toolResponse)
        } catch {
            self.error = .sessionError(error.localizedDescription)
        }
    }
}
