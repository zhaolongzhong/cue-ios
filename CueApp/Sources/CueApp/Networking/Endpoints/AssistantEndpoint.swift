import Foundation

enum AssistantEndpoint {
    case create(name: String, isPrimary: Bool)
    case get(id: String)
    case list(skip: Int, limit: Int)
    case listAssistantConversations(id: String, isPrimary: Bool?, skip: Int, limit: Int)
    case listMessages(conversationId: String, skip: Int, limit: Int)
    case getMessage(id: String)
    case update(id: String, name: String?, metadata: AssistantMetadataUpdate?)
    case delete(id: String)
    case createConversation(assistantId: String, isPriamary: Bool)
    case generateToken
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
        case let .update(id, _, _):
            return "/assistants/\(id)"
        case let .delete(id):
            return "/assistants/\(id)"
        case .createConversation:
            return "/conversations"
        case let .getMessage(id):
            return "/messages/\(id)"
        case .generateToken:
            return "/auth/token"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create, .createConversation, .generateToken:
            return .post
        case .get, .getMessage, .list, .listAssistantConversations, .listMessages:
            return .get
        case .update:
            return .put
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
        case .get, .getMessage, .list, .listAssistantConversations, .listMessages, .delete, .generateToken:
            return nil
        case let .createConversation(assistantId, is_primary):
            var params: [String: Any] = ["title": "Default"]
            params["assistant_id"] = assistantId
            params["metadata"] = ["is_primary": is_primary]
            return try? JSONSerialization.data(withJSONObject: params)
        case let .update(_, name, metadata):
            var params: [String: Any] = [:]
            if let name = name {
                params["name"] = name
            }

            if let metadata = metadata {
                if let metadataData = try? JSONEncoder().encode(metadata) {
                    if let metadataDict = try? JSONSerialization.jsonObject(with: metadataData, options: []) as? [String: Any] {
                        params["metadata"] = metadataDict
                    }
                }
            }
            return try? JSONSerialization.data(withJSONObject: params)
        }
    }

    var requiresAuth: Bool {
        return true
    }
}
