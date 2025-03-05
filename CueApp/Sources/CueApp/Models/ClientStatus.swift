import Foundation

public struct ClientStatus: Identifiable, Equatable, Hashable, Sendable {
    let clientId: String
    let runnerId: String?
    let assistantId: String?
    let lastUpdated: Date
    let isOnline: Bool
    let isUnread: Bool
    let lastMessage: String?
    public var id: String { clientId }

    init(clientId: String, assistantId: String?, runnerId: String?, isOnline: Bool, isUnread: Bool = false, lastMessage: String? = nil, lastUpdated: Date = Date()) {
        self.clientId = clientId
        self.runnerId = runnerId
        self.assistantId = assistantId
        self.isOnline = isOnline
        self.isUnread = isUnread
        self.lastMessage = lastMessage
        self.lastUpdated = lastUpdated
    }
}
