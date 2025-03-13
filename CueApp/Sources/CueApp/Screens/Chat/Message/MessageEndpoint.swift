import Foundation
import CueCommon

enum MessageEndpoint {
    case create(message: MessageModel)
    case get(id: String)
    case list(conversationId: String, skip: Int, limit: Int)
    case update(id: String, messageModel: MessageModel)
    case delete(id: String)
}

extension MessageEndpoint: Endpoint {
    var path: String {
        switch self {
        case .create:
            return "/messages"
        case let .get(id):
            return "/messages/\(id)"
        case let .list(conversationId, _, _):
            return "/conversations/\(conversationId)/messages"
        case let .update(id, _):
            return "/messages/\(id)"
        case let .delete(id):
            return "/messages/\(id)"
        }
    }

    var queryParameters: [String: String]? {
        switch self {
        case let .list(_, skip, limit):
            return ["skip": String(skip), "limit": String(limit)]
        default:
            return nil
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create:
            return .post
        case .get, .list:
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
        case .get, .list, .delete:
            return nil
        case let .update(_, message):
            if let messageData = try? JSONEncoder().encode(message) {
                return messageData
            }
            return nil
        case let .create(message):
            if let messageData = try? JSONEncoder().encode(message) {
                return messageData
            }
            return nil
        }
    }

    var requiresAuth: Bool {
        return true
    }
}
