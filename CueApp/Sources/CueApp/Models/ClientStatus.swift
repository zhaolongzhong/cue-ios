import Foundation

struct ClientStatus: Identifiable, Equatable {
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
}
