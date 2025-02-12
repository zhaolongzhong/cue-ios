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

enum EmailCategory: String, Codable {
    case newsletters
    case updates
    case actionItems
    case replies

    var displayName: String {
        switch self {
        case .newsletters: return "Newsletters"
        case .updates: return "Updates"
        case .actionItems: return "Action Items"
        case .replies: return "Replies"
        }
    }
}

struct EmailSummary: Identifiable, Codable {
    let id: String
    let title: String
    let snippet: String
    let category: EmailCategory
    let date: Date
    let priority: Int
    let originalEmailId: String
    var isRead: Bool
    var requiresAction: Bool
    var tags: [String]
}

// MARK: - Helper Extensions

extension Array where Element == EmailSummary {
    func groupedByCategory() -> [EmailCategory: [EmailSummary]] {
        Dictionary(grouping: self) { $0.category }
    }

    func sortedByPriority() -> [EmailSummary] {
        sorted { $0.priority > $1.priority }
    }
}

extension EmailCategory: CaseIterable {
    static let allCases: [EmailCategory] = [
        .newsletters,
        .updates,
        .actionItems,
        .replies
    ]
}

extension String {
    var isValidJSON: Bool {
        guard let data = self.data(using: .utf8) else { return false }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            return false
        }
    }
}
