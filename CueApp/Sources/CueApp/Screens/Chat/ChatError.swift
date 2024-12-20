import Foundation

enum ChatError: Equatable, Identifiable {
    case apiError(String)
    case toolError(String)
    case unknownError(String)

    var id: UUID {
        UUID()
    }

    var message: String {
        switch self {
        case .apiError(let message),
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
            AppLog.log.error("API Error: \(message)")
        case .toolError(let message):
            AppLog.log.error("Tool Error: \(message)")
        case .unknownError(let message):
            AppLog.log.error("Unknown Error: \(message)")
        }
    }
}
