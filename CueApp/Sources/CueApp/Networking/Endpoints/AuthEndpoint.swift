import Foundation

enum AuthEndpoint {
    case login(email: String, password: String)
    case signup(email: String, password: String, inviteCode: String?)
    case refreshToken
    case logout
    case me
}

extension AuthEndpoint: Endpoint {
    var path: String {
        switch self {
        case .login:
            return "/login/access-token"
        case .signup:
            return "/auth/signup"
        case .refreshToken:
            return "/auth/refresh"
        case .logout:
            return "/auth/logout"
        case .me:
            return "/users/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .signup:
            return .post
        case .refreshToken:
            return .post
        case .logout:
            return .post
        case .me:
            return .get
        }
    }

    var headers: [String: String]? {
            switch self {
            case .login:
                return ["Content-Type": "application/x-www-form-urlencoded"]
            default:
                return ["Content-Type": "application/json"]
            }
        }
    var body: Data? {
        switch self {
        case let .login(email, password):
            // Create form-urlencoded body correctly
            func encodeURIComponent(_ string: String) -> String {
                let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")
                return string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? string
            }

            let params = [
                "grant_type": "password",
                "username": email,
                "password": password
            ]

            let formBody = params
                .map { key, value in
                    "\(encodeURIComponent(key))=\(encodeURIComponent(value))"
                }
                .joined(separator: "&")
            return formBody.data(using: .utf8)

        case let .signup(email, password, inviteCode):
            var params: [String: String] = ["username": email, "password": password]
            if let inviteCode = inviteCode {
                params["inviteCode"] = inviteCode
            }
            return try? JSONSerialization.data(withJSONObject: params)

        case .refreshToken, .logout, .me:
            return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .signup:
            return false
        case .refreshToken, .logout, .me:
            return true
        }
    }
}
