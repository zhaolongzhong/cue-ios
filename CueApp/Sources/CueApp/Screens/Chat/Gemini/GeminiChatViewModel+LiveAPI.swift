import Foundation
import CueGemini

extension GeminiChatViewModel {
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
            AppLog.log.debug("function response: \(String(describing: functionResponse))")
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
            try await liveAPIClient.send(toolResponse)
        } catch {
            self.error = .sessionError(error.localizedDescription)
        }
    }
}
