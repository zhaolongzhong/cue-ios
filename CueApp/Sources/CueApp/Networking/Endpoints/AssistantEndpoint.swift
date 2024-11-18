import Foundation

enum AssistantEndpoint {
    case create(name: String, isPrimary: Bool)
    case get(id: String)
    case list(skip: Int, limit: Int)
    case listAssistantConversations(id: String, isPrimary: Bool?, skip: Int, limit: Int)
    case listMessages(conversationId: String, skip: Int, limit: Int)
    case getMessage(id: String)
    case delete(id: String)
    case createConversation(assistantId: String, isPriamary: Bool)
}

extension AssistantEndpoint: Endpoint {
    var path: String {
        switch self {
        case .create:
            return "/assistants"
        case let .get(id):
            return "/assistants/\(id)"
        case let .list(skip, limit):
            return "/assistants?skip=\(skip)&limit=\(limit)"
        case let .listAssistantConversations(id, isPrimary, skip, limit):
            let baseUrl = "/assistants/\(id)/conversations"
            var queryParams: [String: String] = [
                "skip": String(skip),
                "limit": String(limit)
            ]

            if let isPrimary = isPrimary {
                queryParams["is_primary"] = String(isPrimary)
            }

            let queryString = queryParams
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "&")

            return "\(baseUrl)?\(queryString)"
        case let .listMessages(conversationId, skip, limit):
            return "/conversations/\(conversationId)/messages?skip=\(skip)&limit=\(limit)"
        case let .delete(id):
            return "/assistants/\(id)"
        case .createConversation:
            return "/conversations"
        case let .getMessage(id):
            return "/messages/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create, .createConversation:
            return .post
        case .get, .getMessage, .list, .listAssistantConversations, .listMessages:
            return .get
        case .delete:
            return .delete
        }
    }

    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }

    var body: Data? {
        switch self {
        case let .create(name, isPrimary):
            var params: [String: Any] = ["name": name]
            params["metadata"] = ["is_primary": isPrimary]
            return try? JSONSerialization.data(withJSONObject: params)
        case .get, .getMessage, .list, .listAssistantConversations, .listMessages, .delete:
            return nil
        case let .createConversation(assistantId, is_primary):
            var params: [String: Any] = ["title": "Default"]
            params["assistant_id"] = assistantId
            params["metadata"] = ["is_primary": is_primary]
            return try? JSONSerialization.data(withJSONObject: params)
        }
    }

    var requiresAuth: Bool {
        return true
    }
}
