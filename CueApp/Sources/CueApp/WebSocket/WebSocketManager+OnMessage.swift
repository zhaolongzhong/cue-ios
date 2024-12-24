import SwiftUI

extension WebSocketManager {
    func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) async {
        reconnectAttempts = 0
        lastPongReceived = Date()

        switch message {
        case .string(let text):
            if let data = text.data(using: .utf8) {
                do {
                    let eventMessage = try JSONDecoder().decode(EventMessage.self, from: data)
                    Task { @MainActor in
                        await processEventMessage(eventMessage)
                    }
                } catch {
                    AppLog.websocket.error("Error decoding EventMessage: \(error)")
                }
            }
        case .data(let data):
            AppLog.websocket.error("Received binary message: \(data)")
        @unknown default:
            AppLog.websocket.error("Received unknown message type")
        }
    }

    private func processEventMessage(_ eventMessage: EventMessage) async {
        switch eventMessage.type {
        case .ping:
            break
        case .pong:
            break
        case .clientConnect, .clientDisconnect, .clientStatus:
            await handleClientEvent(eventMessage)
        case .assistant, .user:
            if case .message(let messagePayload) = eventMessage.payload {
                await MainActor.run {
                    self.onMessageReceived?(messagePayload)
                }
            }
        case .generic, .error:
            if case .genericMessage(let genericPayload) = eventMessage.payload {
                AppLog.websocket.debug("Received generic message: \(genericPayload.message ?? "")")
            }
        }
    }

    private func handleClientEvent(_ eventMessage: EventMessage) async {
        guard case .clientEvent(let clientEventPayload) = eventMessage.payload else { return }

        if clientId == clientEventPayload.clientId {
            return
        }

        if let jsonPayload = clientEventPayload.payload, case .dictionary(let dict) = jsonPayload {
            let runnerId = dict["runner_id"]?.asString
            let assistantId = dict["assistant_id"]?.asString
            let clientStatus = ClientStatus(
                clientId: clientEventPayload.clientId,
                assistantId: assistantId,
                runnerId: runnerId,
                isOnline: true
            )
            await MainActor.run {
                if let existingIndex = clientStatuses.firstIndex(where: { $0.id == clientStatus.id }) {
                    clientStatuses[existingIndex] = clientStatus
                } else {
                    clientStatuses.append(clientStatus)
                }
                onClientStatusUpdated?(clientStatus)
            }
        } else if eventMessage.type == .clientDisconnect {
            await MainActor.run {
                if let existingIndex = clientStatuses.firstIndex(where: { $0.id == clientEventPayload.clientId }) {
                    let clientStatus = ClientStatus(
                        clientId: clientEventPayload.clientId,
                        assistantId: nil,
                        runnerId: nil,
                        isOnline: false
                    )
                    clientStatuses[existingIndex] = clientStatus
                } else {
                    let clientStatus = ClientStatus(
                        clientId: clientEventPayload.clientId,
                        assistantId: nil,
                        runnerId: nil,
                        isOnline: false
                    )
                    clientStatuses.append(clientStatus)
                }
            }
        }
    }
}
