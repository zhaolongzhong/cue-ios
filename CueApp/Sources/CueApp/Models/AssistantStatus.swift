import Foundation

public struct AssistantStatus: Identifiable, Sendable {
    public let id: String
    let name: String
    let assistant: Assistant
    let clientStatus: ClientStatus?

    var isOnline: Bool {
        return clientStatus?.isOnline ?? false
    }
}

extension AssistantStatus: Hashable {
    public static func == (lhs: AssistantStatus, rhs: AssistantStatus) -> Bool {
        lhs.id == rhs.id && lhs.clientStatus == rhs.clientStatus
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(clientStatus)
    }
}
