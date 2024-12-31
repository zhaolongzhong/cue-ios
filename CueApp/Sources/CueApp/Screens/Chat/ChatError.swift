import Foundation

enum ChatError: Equatable, Identifiable {
    case apiError(String)
    case sessionError(String)
    case toolError(String)
    case unknownError(String)

    var id: UUID {
        UUID()
    }

    var message: String {
        switch self {
        case .apiError(let message),
             .sessionError(let message),
             .toolError(let message),
             .unknownError(let message):
            return message
        }
    }
}

struct ErrorLogger {
    static func log(_ error: ChatError) {
        switch error {
        case .apiError(let message):
            AppLog.log.error("API error: \(message)")
        case .sessionError(let message):
            AppLog.log.error("Session error: \(message)")
        case .toolError(let message):
            AppLog.log.error("Tool error: \(message)")
        case .unknownError(let message):
            AppLog.log.error("Unknown error: \(message)")
        }
    }
}
