//
//  ConversationEndpoint.swift
//  CueApp
//

import Foundation
import CueCommon

enum ConversationEndpoint {
    case create(title: String, assistantId: String?, isPrimary: Bool)
    case get(id: String)
    case list(skip: Int, limit: Int)
    case update(id: String, title: String?, metadata: [String: Any]?)
    case delete(id: String)
    case listByAssistantId(assistantId: String, isPrimary: Bool?, skip: Int, limit: Int)
}

extension ConversationEndpoint: Endpoint {
    var path: String {
        switch self {
        case .create:
            return "/conversations"
        case let .get(id):
            return "/conversations/\(id)"
        case .list:
            return "/conversations"
        case let .update(id, _, _):
            return "/conversations/\(id)"
        case let .delete(id):
            return "/conversations/\(id)"
        case let .listByAssistantId(assistantId, _, _, _):
            return "/assistants/\(assistantId)/conversations"
        }
    }

    var queryParameters: [String: String]? {
        switch self {
        case let .list(skip, limit):
            return ["skip": String(skip), "limit": String(limit)]
        case let .listByAssistantId(_, isPrimary, skip, limit):
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
        case .create:
            return .post
        case .get, .list, .listByAssistantId:
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
        case let .create(title, assistantId, isPrimary):
            var params: [String: Any] = ["title": title]

            if let assistantId = assistantId {
                params["assistant_id"] = assistantId
            }

            params["metadata"] = ["is_primary": isPrimary]

            return try? JSONSerialization.data(withJSONObject: params)

        case .get, .list, .listByAssistantId, .delete:
            return nil

        case let .update(_, title, metadata):
            var params: [String: Any] = [:]

            if let title = title {
                params["title"] = title
            }

            if let metadata = metadata {
                params["metadata"] = metadata
            }

            return try? JSONSerialization.data(withJSONObject: params)
        }
    }

    var requiresAuth: Bool {
        return true
    }
}
