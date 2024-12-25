import Foundation

extension EventMessage {
    var clientStatus: ClientStatus? {
        if case .clientEvent(let payload) = self.payload {
            switch self.type {
            case .clientConnect, .clientStatus:
                if let jsonPayload = payload.payload,
                   case .dictionary(let dict) = jsonPayload {
                    return  ClientStatus(
                        clientId: payload.clientId,
                        assistantId: dict["assistant_id"]?.asString,
                        runnerId: dict["runner_id"]?.asString,
                        isOnline: true
                    )
                }
            case .clientDisconnect:
                return ClientStatus(
                    clientId: payload.clientId,
                    assistantId: nil,
                    runnerId: nil,
                    isOnline: false
                )
            default:
                break
            }
        }
        return nil
    }
}

extension EventMessage: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        EventMessage(
            type: \(type)
            clientId: \(clientId ?? "nil")
            websocketRequestId: \(websocketRequestId ?? "nil")
            metadata: \(String(describing: metadata))
            payload: \(String(describing: payload))
        )
        """
    }
}

extension MessagePayload: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        MessagePayload(
            message: \(message ?? "nil")
            sender: \(sender ?? "nil")
            recipient: \(recipient ?? "nil")
            websocketRequestId: \(websocketRequestId ?? "nil")
            userId: \(userId ?? "nil")
            msgId: \(msgId ?? "nil")
            metadata: \(String(describing: metadata))
            payload: \(String(describing: payload))
        )
        """
    }
}

// MARK: - Convenience Extension for MessagePayload
extension MessagePayload {
    var toolResponse: ToolResponse? {
        return payload?.toToolResponse()
    }
}
