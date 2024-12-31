import Foundation

enum AuthEndpoint {
    case login(email: String, password: String)
    case signup(email: String, password: String, inviteCode: String?)
    case refreshToken(token: String)
    case logout
    case me
}

extension AuthEndpoint: Endpoint {
    var path: String {
        switch self {
        case .login:
            return "/accounts/login"
        case .signup:
            return "/accounts/register"
        case .refreshToken:
            return "/accounts/refresh"
        case .logout:
            return "/accounts/logout"
        case .me:
            return "/accounts/me"
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
            var params: [String: String] = ["email": email, "password": password]
            if let inviteCode = inviteCode {
                params["invite_code"] = inviteCode
            }
            return try? JSONSerialization.data(withJSONObject: params)

        case let .refreshToken(token):
            let params = ["refresh_token": token]
            return try? JSONSerialization.data(withJSONObject: params)
        case .logout, .me:
            return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .signup, .refreshToken:
            return false
        case .logout, .me:
            return true
        }
    }
}
