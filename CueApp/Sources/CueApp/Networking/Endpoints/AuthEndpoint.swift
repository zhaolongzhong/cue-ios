import Foundation

enum AuthEndpoint {
    case login(email: String, password: String)
    case signup(email: String, password: String, inviteCode: String?)
    case refreshToken(token: String)
    case logout
    case me
    case signInWithGoogle(idToken: String, email: String?, fullName: String?, avatarURL: String?)
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
        case .signInWithGoogle:
            return "/accounts/social/google"
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
        case .signInWithGoogle:
            return .post
        }
    }

    var headers: [String: String]? {
        var platform = "ios"
        #if os(macOS)
        platform = "macos"
        #endif
        switch self {
        case .login:
            return ["Content-Type": "application/x-www-form-urlencoded"]
        default:
            return [
                "Content-Type": "application/json",
                "platform": platform
            ]
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
        case let .signInWithGoogle(idToken, email, fullName, avatarURL):
            let params: [String: String?] = [
                "id_token": idToken,
                "email": email,
                "full_name": fullName,
                "avatar_url": avatarURL
            ]
            return try? JSONSerialization.data(withJSONObject: params)
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .signup, .refreshToken, .signInWithGoogle:
            return false
        case .logout, .me:
            return true
        }
    }
}
