import Foundation

enum APIKeysEndpoint {
    case create(name: String, keyType: String, scopes: [String]?, expiresAt: Date?)
    case get(id: String)
    case list(skip: Int, limit: Int)
    case update(id: String, name: String?, scopes: [String]?, expiresAt: Date?, isActive: Bool?)
    case delete(id: String)
}

extension APIKeysEndpoint: Endpoint {
    var path: String {
        switch self {
        case .create:
            return "/api-keys"
        case let .get(id):
            return "/api-keys/\(id)"
        case let .list(skip, limit):
            return "/api-keys?skip=\(skip)&limit=\(limit)"
        case let .update(id, _, _, _, _):
            return "/api-keys/\(id)"
        case let .delete(id):
            return "/api-keys/\(id)"
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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        switch self {
        case let .create(name, keyType, scopes, expiresAt):
            var params: [String: Any] = [
                "name": name,
                "key_type": keyType
            ]

            if let scopes = scopes {
                params["scopes"] = scopes
            }

            if let expiresAt = expiresAt {
                params["expires_at"] = ISO8601DateFormatter().string(from: expiresAt)
            }

            return try? JSONSerialization.data(withJSONObject: params)

        case .get, .list:
            return nil

        case let .update(_, name, scopes, expiresAt, isActive):
            var params: [String: Any] = [:]

            if let name = name {
                params["name"] = name
            }

            if let scopes = scopes {
                params["scopes"] = scopes
            }

            if let expiresAt = expiresAt {
                params["expires_at"] = ISO8601DateFormatter().string(from: expiresAt)
            }

            if let isActive = isActive {
                params["is_active"] = isActive
            }

            return try? JSONSerialization.data(withJSONObject: params)

        case .delete:
            return nil
        }
    }

    var requiresAuth: Bool {
        return true
    }
}
