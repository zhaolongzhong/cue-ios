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

// MARK: - Convenience Extension for MessagePayload
extension MessagePayload {
    var toolResponse: ToolResponse? {
        return payload?.toToolResponse()
    }
}
