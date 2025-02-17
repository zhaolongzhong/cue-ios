import Foundation

struct EmailHighlight: Codable, Hashable {
    let content: EmailContent

    struct EmailContent: Codable, Hashable {
        let keyInsights: [String]
        let mainTopics: [String]
        let highlights: Highlights
        let actionItems: [String]
        let summary: String

        struct Highlights: Codable, Hashable {
            let quotes: [String]
            let stats: [String]
        }

        enum CodingKeys: String, CodingKey {
            case keyInsights = "key_insights"
            case mainTopics = "main_topics"
            case highlights
            case actionItems = "action_items"
            case summary
        }
    }
}

extension EmailHighlight {
    static func parse(from jsonStr: String) -> EmailHighlight? {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(EmailHighlight.self, from: Data(jsonStr.utf8))
        } catch {
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    AppLog.log.error("Data Corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    AppLog.log.error("Key '\(String(describing: key))' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    AppLog.log.error("Type '\(type)' mismatch: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    AppLog.log.error("Value of type '\(type)' not found: \(context.debugDescription)")
                @unknown default:
                    AppLog.log.error("Unknown decoding error: \(error)")
                }
            }
            AppLog.log.error("Attempted to parse JSON: \(jsonStr)")
        }
        return nil
    }
}
