import Foundation

struct AssistantStatus: Identifiable {
    let id: String
    let name: String
    let assistant: Assistant
    let clientStatus: ClientStatus?

    var isOnline: Bool {
        return clientStatus?.isOnline ?? false
    }
}
