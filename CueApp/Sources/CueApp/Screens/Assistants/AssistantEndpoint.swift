import Foundation
import CueCommon

enum AssistantEndpoint {
    case create(name: String, isPrimary: Bool)
    case get(id: String)
    case list(skip: Int, limit: Int)
    case listAssistantConversations(id: String, isPrimary: Bool?, skip: Int, limit: Int)
    case update(id: String, name: String?, metadata: AssistantMetadataUpdate?)
    case delete(id: String)
    case createConversation(assistantId: String, isPrimary: Bool)
}

extension AssistantEndpoint: Endpoint {
    var path: String {
        switch self {
        case .create:
            return "/assistants"
        case let .get(id):
            return "/assistants/\(id)"
        case .list:
            return "/assistants"
        case let .listAssistantConversations(id, _, _, _):
            return "/assistants/\(id)/conversations"
        case let .update(id, _, _):
            return "/assistants/\(id)"
        case let .delete(id):
            return "/assistants/\(id)"
        case .createConversation:
            return "/conversations"
        }
    }

    var queryParameters: [String: String]? {
        switch self {
        case let .list(skip, limit):
            return ["skip": String(skip), "limit": String(limit)]
        case let .listAssistantConversations(_, isPrimary, skip, limit):
            var params: [String: String] = [
                "skip": String(skip),
                "limit": String(limit)
            ]

            if let isPrimary = isPrimary {
                params["is_primary"] = String(isPrimary)
            }

            return params
        default:
            return nil
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create, .createConversation:
            return .post
        case .get, .list, .listAssistantConversations:
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
        case .get, .list, .listAssistantConversations, .delete:
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
