import Foundation

struct AssistantStatus: Identifiable {
    let id: String
    let name: String
    let clientId: String?
    let isOnline: Bool
    let avatarUrl: String?
    let description: String
}
