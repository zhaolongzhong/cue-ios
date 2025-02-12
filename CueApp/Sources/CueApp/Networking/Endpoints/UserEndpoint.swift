import Foundation

enum UserEndpoint {
    case updateProfile(name: String)
    case logout
}

extension UserEndpoint: Endpoint {
    var path: String {
        switch self {
        case .updateProfile:
            return "/user/profile"
        case .logout:
            return "/logout"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .updateProfile:
            return .put
        case .logout:
            return .post
        }
    }
    
    var body: Data? {
        switch self {
        case .updateProfile(let name):
            let parameters = ["name": name]
            return try? JSONSerialization.data(withJSONObject: parameters)
        default:
            return nil
        }
    }
}