import SwiftUI

enum ProcessingState: Equatable {
    case idle
    case gettingInbox
    case organizingTasks
    case analyzingMessages
    case almostReady
    case ready
    case error(String)

    var description: String {
        switch self {
        case .idle: return "Starting..."
        case .gettingInbox: return "Getting tasks from inbox..."
        case .organizingTasks: return "Organizing tasks..."
        case .analyzingMessages: return "Analyzing messages..."
        case .almostReady: return "Almost ready..."
        case .ready: return "Ready"
        case .error(let message): return "Error: \(message)"
        }
    }

    var isLoading: Bool {
        switch self {
        case .idle,
                .gettingInbox,
                .organizingTasks,
                .analyzingMessages,
                .almostReady:
            return true
        default:
            return false
        }
    }

    static func == (lhs: ProcessingState, rhs: ProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.gettingInbox, .gettingInbox),
             (.organizingTasks, .organizingTasks),
             (.analyzingMessages, .analyzingMessages),
             (.almostReady, .almostReady),
             (.ready, .ready):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}
