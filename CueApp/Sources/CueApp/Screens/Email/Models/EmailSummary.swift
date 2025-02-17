import Foundation

struct EmailSummary: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let thread: String
    let title: String
    let snippet: String
    let keyInsights: [String]?
    let category: EmailCategory
    let date: Date
    let priority: Int
    let originalEmailId: String
    var isRead: Bool
    var requiresAction: Bool
    var tags: [String]
    var from: String?
    var content: String?
    var originalEmail: GmailMessage?
}

extension EmailSummary {
    var fromName: String? {
        from?.components(separatedBy: " <").first ?? from
    }
}

struct SummaryResponse: Codable {
    let id: String
    let threadId: String
    let title: String
    let summary: String
    let keyInsights: [String]?
    let category: String
    let priority: Int
    let requiresAction: Bool
    let tags: [String]
}

extension EmailSummary {
    static func parse(from response: SummaryResponse, originalEmail: GmailMessage?) -> EmailSummary? {
        return EmailSummary(
            id: response.id,
            thread: response.threadId,
            title: response.title,
            snippet: response.summary,
            keyInsights: response.keyInsights ?? [],
            category: EmailCategory(rawValue: response.category) ?? .updates,
            date: Date(),
            priority: response.priority,
            originalEmailId: originalEmail?.id ?? "",
            isRead: false,
            requiresAction: response.requiresAction,
            tags: response.tags,
            from: originalEmail?.from,
            content: originalEmail?.plainTextContent,
            originalEmail: originalEmail
        )
    }
}
