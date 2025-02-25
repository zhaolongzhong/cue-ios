import Foundation
import OSLog
import CueOpenAI

enum SummarizationProgress {
    case starting
    case batchProcessing(current: Int, total: Int, summariesCount: Int)
    case completed(summaries: [EmailSummary])
    case failed(Error)

    var description: String {
        switch self {
        case .starting:
            return "Starting email summarization..."
        case .batchProcessing(let current, let total, let summariesCount):
            return "Processing batch \(current)/\(total) (found \(summariesCount) summaries)"
        case .completed(let summaries):
            return "Completed processing \(summaries.count) summaries"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
}

actor EmailSummarizationService {
    private let logger = Logger(subsystem: "EmailSummarizationService", category: "Email")
    private let batchSize: Int
    private var progressStream: AsyncStream<SummarizationProgress>.Continuation?

    init(batchSize: Int = 5) {
        self.batchSize = batchSize
    }

    func summarizeEmails(_ emails: [CleanEmailMessage], originalEmails: [String: GmailMessage]) -> AsyncThrowingStream<SummarizationProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.starting)

                    let startTime = DispatchTime.now()
                    let emailStrings = emails.map { $0.toString(includeContent: true) }
                    let emailBatches = createBatches(from: emailStrings)

                    logger.debug("⚡️ Starting batch processing - \(emailBatches.count) batches of \(self.batchSize) emails each")

                    // Process batches with progress updates
                    let summaries = try await processBatchesWithProgress(
                        emailBatches,
                        originalEmails: originalEmails
                    ) { current, total, summariesCount in
                        continuation.yield(.batchProcessing(
                            current: current,
                            total: total,
                            summariesCount: summariesCount
                        ))
                    }

                    let endTime = DispatchTime.now()
                    let nanoseconds = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
                    let totalTime = Double(nanoseconds) / 1_000_000_000
                    logTimingSummary(totalTime: totalTime)

                    let sortedSummaries = summaries.sortedByPriority()
                    continuation.yield(.completed(summaries: sortedSummaries))
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(error))
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func processBatchesWithProgress(
        _ batches: [[String]],
        originalEmails: [String: GmailMessage],
        progress: @escaping (Int, Int, Int) -> Void
    ) async throws -> [EmailSummary] {
        try await withThrowingTaskGroup(of: (Int, [EmailSummary], TimeInterval).self) { group in
            var allSummaries: [EmailSummary] = []

            // Add processing tasks for each batch
            for (batchIndex, batch) in batches.enumerated() {
                let batchStartTime = CFAbsoluteTimeGetCurrent()

                group.addTask {
                    let result = try await self.processBatch(batch, originalEmails: originalEmails)
                    let duration = CFAbsoluteTimeGetCurrent() - batchStartTime
                    return (batchIndex, result, duration)
                }
            }

            // Collect results with progress updates
            for try await (batchIndex, batchResult, duration) in group {
                allSummaries.append(contentsOf: batchResult)

                logger.debug("✅ Batch \(batchIndex + 1)/\(batches.count) completed in \(String(format: "%.2f", duration))s (\(batchResult.count) summaries)")

                progress(batchIndex + 1, batches.count, allSummaries.count)
            }

            return allSummaries
        }
    }

    // MARK: - Private Methods

    private func createBatches(from emails: [String]) -> [[String]] {
        stride(from: 0, to: emails.count, by: batchSize).map {
            Array(emails[$0..<min($0 + batchSize, emails.count)])
        }
    }

    private func processBatches(_ batches: [[String]], originalEmails: [String: GmailMessage]) async throws -> [EmailSummary] {
        try await withThrowingTaskGroup(of: (Int, [EmailSummary], TimeInterval).self) { group in
            var allSummaries: [EmailSummary] = []

            // Add processing tasks for each batch
            for (batchIndex, batch) in batches.enumerated() {
                let batchStartTime = CFAbsoluteTimeGetCurrent()

                group.addTask {
                    let result = try await self.processBatch(batch, originalEmails: originalEmails)
                    let duration = CFAbsoluteTimeGetCurrent() - batchStartTime
                    return (batchIndex, result, duration)
                }
            }

            // Collect results
            for try await (batchIndex, batchResult, duration) in group {
                allSummaries.append(contentsOf: batchResult)
                logger.debug("✅ Batch \(batchIndex + 1)/\(batches.count) completed in \(String(format: "%.2f", duration))s (\(batchResult.count) summaries)")
            }

            return allSummaries
        }
    }

    private func processBatch(_ emails: [String], originalEmails: [String: GmailMessage]) async throws -> [EmailSummary] {
        return try await summarizeEmails(emails, inboxEmailDetails: originalEmails)
    }

    private func logTimingSummary(totalTime: TimeInterval) {
        logger.debug("""
        📊 Time Summary:
        --------------------------------
        🔸 Total Processing Time: \(String(format: "%.2f", totalTime))s
        --------------------------------
        """)
    }
}

// MARK: - Error Handling
extension EmailSummarizationService {
    enum SummarizationError: Error {
        case insufficientEmails
        case processingFailed(String)
    }
}

extension EmailSummarizationService {
    func summarizeEmails(_ emails: [String], inboxEmailDetails: [String: GmailMessage]) async throws -> [EmailSummary] {
        let cueClient = await CueClient()
        var messageParams: [CueChatMessage] = []

        let content = Instructions.buildSummarizationMessage(emails)

        let userMessage = CueChatMessage.openAI(
            OpenAI.ChatMessageParam.userMessage(
                OpenAI.MessageParam(role: "user", content: .string(content))
            )
        )
        messageParams.append(userMessage)

        let agent = await AgentLoop(chatClient: cueClient, model: ChatModel.gpt4oMini.id)
        let completionRequest = CompletionRequest(model: ChatModel.gpt4oMini.id, maxTokens: 5000)
        let updatedMessages = try await agent.run(with: messageParams, request: completionRequest)

        if let summaries = handleResponse(from: updatedMessages.last, inboxEmailDetails: inboxEmailDetails) {
            return summaries
        } else {
            throw NSError(domain: "EmailSummarization", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse email summaries"])
        }
    }

    private func handleResponse(from message: CueChatMessage?, inboxEmailDetails: [String: GmailMessage]) -> [EmailSummary]? {
        if case .openAI(let param) = message, case .assistantMessage(let msg) = param {
            let content = msg.content ?? ""
            let validJSONString = parseToJSON(content).trimmingCharacters(in: .whitespacesAndNewlines)
            return parseEmailSummaries(validJSONString, inboxEmailDetails: inboxEmailDetails)
        } else if case .anthropic(let param, _, _) = message, case .assistantMessage(let msg) = param {
            let content = msg.content.first?.text ?? ""
            let validJSONString = parseToJSON(content).trimmingCharacters(in: .whitespacesAndNewlines)
            return parseEmailSummaries(validJSONString, inboxEmailDetails: inboxEmailDetails)
        }
        return []
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

    private func parseEmailSummaries(_ jsonStr: String, inboxEmailDetails: [String: GmailMessage]) -> [EmailSummary]? {
        struct APIResponse: Codable {
            let id: String
            let threadId: String
            let title: String
            let snippet: String
            let category: String
            let priority: Int
            let requiresAction: Bool
            let tags: [String]
        }

        let decoder = JSONDecoder()
        do {
            let responses = try decoder.decode([SummaryResponse].self, from: Data(jsonStr.utf8))
            return responses.compactMap { response in
                let originalEmail = inboxEmailDetails[response.id]
                return EmailSummary.parse(from: response, originalEmail: originalEmail)
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
