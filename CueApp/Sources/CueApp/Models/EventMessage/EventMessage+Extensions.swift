import Foundation

extension EventMessage: CustomDebugStringConvertible {
    var debugDescription: String {
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
    var debugDescription: String {
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
