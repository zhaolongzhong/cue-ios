import SwiftUI
import Dependencies
import CueOpenAI

struct QuoteContent: Identifiable {
    let id = UUID()
    let text: String
    let source: String?
    let isQuote: Bool
}

extension HomeViewModel {
    func fetchQuoteOrFunFact() async {
        let quotes = await generateQuotes()
        self.quoteOrFunFact = quotes
    }

    private var previousQuotes: Set<String> = []
    
    func generateQuotes() async -> [QuoteContent] {
        let cueClient = CueClient()
        var messageParams: [CueChatMessage] = []

        // Convert previous quotes to a formatted string
        let previousQuotesContext = previousQuotes.isEmpty ? "" : """
        Previously generated quotes (avoid these):
        \(previousQuotes.map { "- \($0)" }.joined(separator: "\n"))

        """

        let prompt = """
        Generate 3 NEW and DIFFERENT meaningful quotes that would resonate with someone who values personal growth and innovation and entrepreneurship. Format your response as a JSON array where each quote has 'text' and optional 'source' fields.

        \(previousQuotesContext)Requirements:
        - Each quote MUST BE DIFFERENT from previously generated quotes
        - Mix of both famous quotes and original insights
        - Focus on themes of growth, creativity, and wisdom
        - Each quote should be concise and impactful
        - Include source attribution where applicable
        - Output must be valid JSON format
        - Ensure variety in themes and authors

        Example format:
        [
            {"text": "Your quote here", "source": "Author Name"},
            {"text": "Another quote without source"}
        ]
        """

        let userMessage = CueChatMessage.openAI(
            OpenAI.ChatMessageParam.userMessage(
                OpenAI.MessageParam(role: "user", content: prompt)
            )
        )
        messageParams.append(userMessage)

        do {
            let agent = AgentLoop(chatClient: cueClient, model: ChatModel.gpt4oMini.id)
            let completionRequest = CompletionRequest(model: ChatModel.gpt4oMini.id)
            let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)

            let quotes = parseQuotesFromMessage(updatedMessages.last)
            AppLog.log.debug("Parsed quotes: \(quotes)")
            return quotes
        } catch {
            ErrorLogger.log(ChatError.unknownError(error.localizedDescription))
        }
        return[]
    }

    private func extractJSONFromResponse(_ message: CueChatMessage?) -> String? {
        guard case .openAI(let param) = message,
              case .assistantMessage(let msg) = param,
              let content = msg.content else {
            return nil
        }

        // Remove markdown code block markers and any whitespace
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleanContent
    }

    private func parseQuotesFromMessage(_ message: CueChatMessage?) -> [QuoteContent] {
        guard let jsonString = extractJSONFromResponse(message) else {
            AppLog.log.error("Failed to extract JSON from message")
            return []
        }

        let quotes = parseQuotesResponse(jsonString)
        
        // Update previous quotes set with new quotes
        quotes.forEach { quote in
            // Only store the text to save memory
            previousQuotes.insert(quote.text)
            
            // Keep set size manageable by removing oldest quotes if too large
            if previousQuotes.count > 50 {
                previousQuotes.remove(previousQuotes.first!)
            }
        }
        
        return quotes
    }

    private func parseQuotesResponse(_ response: String) -> [QuoteContent] {
        guard let data = response.data(using: .utf8) else { return [] }

        struct QuoteResponse: Codable {
            let text: String
            let source: String?
        }

        do {
            let decoder = JSONDecoder()
            let quotes = try decoder.decode([QuoteResponse].self, from: data)
            return quotes.map { quote in
                QuoteContent(
                    text: quote.text,
                    source: quote.source,
                    isQuote: true
                )
            }
        } catch {
            print("Error parsing quotes response: \(error)")
            return []
        }
    }
}
