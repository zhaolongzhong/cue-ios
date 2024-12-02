import Foundation

struct ClientStatus: Identifiable, Equatable, Hashable {
    let clientId: String
    let runnerId: String?
    let assistantId: String?
    let lastUpdated: Date
    let isOnline: Bool
    var id: String { clientId }

    init(clientId: String, assistantId: String?, runnerId: String?, isOnline: Bool, lastUpdated: Date = Date()) {
        self.clientId = clientId
        self.runnerId = runnerId
        self.assistantId = assistantId
        self.isOnline = isOnline
        self.lastUpdated = lastUpdated
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(clientId)
        hasher.combine(runnerId)
        hasher.combine(assistantId)
        hasher.combine(lastUpdated)
        hasher.combine(isOnline)
    }
}
