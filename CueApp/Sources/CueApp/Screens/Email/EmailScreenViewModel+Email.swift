import Foundation
import CueOpenAI

extension EmailScreenViewModel {
    private func getCategorySummaries() -> String {
        let categoryCounts = Dictionary(grouping: emailSummaries) { $0.category }
            .mapValues { $0.count }

        let summaries = EmailCategory.allCases.map { category in
            "\(category.displayName): \(categoryCounts[category, default: 0])"
        }
        return summaries.joined(separator: "\n")
    }

    func summarizeEmails(_ emails: [String]) async throws -> [EmailSummary] {
        print("Starting email summarization...")
        let cueClient = CueClient()
        var messageParams: [CueChatMessage] = []

        let prompt = """
        For the following emails, create summaries and return them in a JSON array. Each summary should follow this exact format:
        [
            {
                "title": "brief title",
                "snippet": "concise summary",
                "category": "newsletters",
                "priority": 3,
                "requiresAction": false,
                "tags": ["tag1", "tag2"]
            }
        ]

        Rules:
        1. Response MUST be valid JSON array
        2. Category must be one of: newsletters, updates, actionItems, replies
        3. Priority must be 1-5 (5 is highest)
        4. Include 2-3 relevant tags per email
        5. Mark requiresAction as true if email needs response or action

        Emails to analyze:
        \(emails.joined(separator: "\n---\n"))

        Return the JSON array only, no additional text.
        """

        let userMessage = CueChatMessage.openAI(
            OpenAI.ChatMessageParam.userMessage(
                OpenAI.MessageParam(role: "user", content: prompt)
            )
        )
        messageParams.append(userMessage)

        let agent = AgentLoop(chatClient: cueClient, model: ChatModel.gpt4oMini.id)
        let completionRequest = CompletionRequest(model: ChatModel.gpt4oMini.id, maxTokens: 5000)
        let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)

        if let summaries = handleResponse(from: updatedMessages.last) {
            return summaries
        } else {
            throw NSError(domain: "EmailSummarization", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse email summaries"])
        }
    }

    private func handleResponse(from message: CueChatMessage?) -> [EmailSummary]? {
        guard case .openAI(let param) = message,
              case .assistantMessage(let msg) = param,
              let content = msg.content else {
            print("Failed to extract content from message")
            return nil
        }

        let validJSONString = parseToJSON(content).trimmingCharacters(in: .whitespacesAndNewlines)
        return parseEmailSummaries(validJSONString)
    }

    private func parseToJSON(_ content: String) -> String {
        // Clean up the content - remove any markdown and get just the JSON
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle truncated JSON by attempting to find the last complete object
        var validJSONString = cleanContent
        if !cleanContent.hasSuffix("]") {
            // Find the last complete object by looking for the last "},"
            if let lastCompleteIndex = cleanContent.range(of: "},\n    {", options: .backwards)?.lowerBound {
                validJSONString = String(cleanContent[..<lastCompleteIndex]) + "}"
            }
            // Add closing bracket if missing
            if !validJSONString.hasSuffix("]") {
                validJSONString += "]"
            }
        }
        return validJSONString
    }

    private func parseEmailSummaries(_ jsonStr: String) -> [EmailSummary]? {
        struct APIResponse: Codable {
            let title: String
            let snippet: String
            let category: String
            let priority: Int
            let requiresAction: Bool
            let tags: [String]
        }

        let decoder = JSONDecoder()
        // Add better error handling with custom debugging
        do {
            let responses = try decoder.decode([APIResponse].self, from: Data(jsonStr.utf8))

            return responses.enumerated().map { index, response in
                EmailSummary(
                    id: UUID().uuidString,
                    title: response.title,
                    snippet: response.snippet,
                    category: EmailCategory(rawValue: response.category) ?? .updates,
                    date: Date(),
                    priority: response.priority,
                    originalEmailId: "email_\(index)",
                    isRead: false,
                    requiresAction: response.requiresAction,
                    tags: response.tags
                )
            }
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
