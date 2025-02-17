import Foundation

enum EmailCategory: String, Codable, Hashable {
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
