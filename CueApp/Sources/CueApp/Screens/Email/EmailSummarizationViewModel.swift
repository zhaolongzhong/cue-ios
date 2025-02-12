import Foundation
import CueOpenAI

@MainActor
class EmailSummarizationViewModel: ObservableObject {
    @Published private(set) var emailSummaries: [EmailSummary] = []
    @Published private(set) var processingState: ProcessingState = .idle

    func startProcessing() async {
        await updateState(.gettingInbox)
        do {
            let inboxResponse = try await GmailService.readInbox(maxCount: 20)
            await updateState(.organizingTasks)
            try await Task.sleep(nanoseconds: 1_500_000_000)

            await updateState(.analyzingMessages)

            let emails = inboxResponse.map { $0.toString()}
            await summarizeEmails(emails)

            await updateState(.almostReady)
            try await Task.sleep(nanoseconds: 1_000_000_000)

            await updateState(.ready)
        } catch {
            await updateState(.error(error.localizedDescription))
        }
    }

    func stopProcessing() {

    }

    private func updateState(_ newState: ProcessingState) async {
        await MainActor.run {
            print("inx newState: \(newState)")
            processingState = newState
        }
    }

    private func summarizeEmails(_ emails: [String]) async {
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

        do {
            print("Sending request with prompt...")
            let agent = AgentLoop(chatClient: cueClient, model: ChatModel.gpt4oMini.id)
            let completionRequest = CompletionRequest(model: ChatModel.gpt4oMini.id, maxTokens: 5000)
            let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)
            print("Received response messages: \(updatedMessages)")

            if let summaries = parseEmailSummaries(from: updatedMessages.last) {
                await MainActor.run {
                    self.emailSummaries = summaries
                }
            } else {
                throw NSError(domain: "EmailSummarization", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse email summaries"])
            }
        } catch {
            await updateState(.error(error.localizedDescription))
        }
    }

    private func parseEmailSummaries(from message: CueChatMessage?) -> [EmailSummary]? {
        guard case .openAI(let param) = message,
              case .assistantMessage(let msg) = param,
              let content = msg.content else {
            print("Failed to extract content from message")
            return nil
        }

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

        struct APIResponse: Codable {
            let title: String
            let snippet: String
            let category: String
            let priority: Int
            let requiresAction: Bool
            let tags: [String]
        }

        do {
            let decoder = JSONDecoder()
            // Add better error handling with custom debugging
            do {
                let responses = try decoder.decode([APIResponse].self, from: Data(validJSONString.utf8))

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
                // Enhanced error reporting
                print("JSON Decoding Error: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("Data Corrupted: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type '\(type)' mismatch: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value of type '\(type)' not found: \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error: \(error)")
                    }
                }
                // Print the problematic JSON for debugging
                print("Attempted to parse JSON: \(validJSONString)")
            }
        } catch {
            print("Unexpected error during parsing: \(error)")
        }
        return nil
    }
}

// Add this extension to help with JSON validation
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
