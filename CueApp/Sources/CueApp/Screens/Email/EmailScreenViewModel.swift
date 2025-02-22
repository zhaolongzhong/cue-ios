import Foundation
import Combine
import CueCommon
import CueOpenAI
import Dependencies
import OSLog

@MainActor
class EmailScreenViewModel: ObservableObject {
    let logger = Logger(subsystem: "EmailScreenViewModel", category: "Email")

    @Dependency(\.realtimeClient) var realtimeClient
    @Dependency(\.authRepository) var authRepository
    @Published var emailSummaries: [EmailSummary] = []
    @Published var cleanEmails: [String: CleanEmailMessage] = [:]
    @Published var originalEmails: [String: GmailMessage] = [:]
    @Published private(set) var processingState: ProcessingState = .idle
    @Published var voiceChatState: VoiceChatState = .idle
    @Published var deltaMessage: String = ""
    @Published var micPermissionGranted: Bool = true
    @Published var showMicAlert: Bool = false
    @Published var name: String = ""
    @Published var newMessage: String = ""
    @Published var error: ChatError?

    var handledEventIds: Set<String> = []
    var cancellables = Set<AnyCancellable>()
    let toolManager: ToolManager
    var apiKey: String?
    private let maxEmails: Int = 20
    private let summarizationService: EmailSummarizationService

    @Published private(set) var summarizationProgress: String = ""
    private var summarizationTask: Task<Void, Never>?

    public init(summarizationService: EmailSummarizationService = EmailSummarizationService()) {
        self.summarizationService = summarizationService
        self.toolManager = ToolManager()
    }

    public func updateApiKey(_ apiKey: String?) {
        self.apiKey = apiKey
    }

    func startProcessing() async {
        AppLog.log.debug("startProcessing")
        name = authRepository.currentUser?.name ?? "there"
        let hasAccess = await ensureGmailAccess()
        guard hasAccess else {
            return
        }
        await updateState(.gettingInbox)
        do {
            let originalEmails = try await GmailService.listInboxDetails(maxCount: maxEmails)
            debugPrint("📩 Processing \(originalEmails.count) emails")

            await updateState(.organizingTasks)
            self.originalEmails = Dictionary(uniqueKeysWithValues: originalEmails.map { ($0.id, $0) })
            let cleanEmails = originalEmails.map { CleanEmailMessage(from: $0) }
            self.cleanEmails = Dictionary(uniqueKeysWithValues: cleanEmails.map { ($0.id, $0) })

            await updateState(.analyzingMessages)
            // Start summarization with progress tracking
            summarizationTask = Task {
                do {
                    let progressStream = await summarizationService.summarizeEmails(
                        cleanEmails,
                        originalEmails: self.originalEmails
                    )

                    for try await progress in progressStream {
                        await handleProgress(progress)
                    }
                } catch {
                    await handleError(error)
                }
            }

            // Wait for summarization to complete
            await summarizationTask?.value
            await updateState(.ready)
            await startVoiceChat()
            await autoStartVoiceSummarization()
        } catch {
            // Handle specific Gmail errors
            if let gmailError = error as? GmailServiceError {
                switch gmailError {
                case .authenticationError:
                    await updateState(.error("Gmail authentication required. Please check your connection in Settings."))
                case .permissionDenied:
                    await updateState(.error("Gmail access denied. Please grant access in Settings > Connected Apps."))
                default:
                    await updateState(.error("Failed to access Gmail: \(error.localizedDescription)"))
                }
            } else {
                await updateState(.error(error.localizedDescription))
            }
        }
    }

    private func handleProgress(_ progress: SummarizationProgress) async {
        summarizationProgress = progress.description

        switch progress {
        case .batchProcessing(let current, _, _):
            if current > 1 {
                await updateState(.almostReady)
            }
        case .completed(let summaries):
            self.emailSummaries = summaries
        case .failed(let error):
            await handleError(error)
        default:
            break
        }
    }

    private func handleError(_ error: Error) async {
        summarizationProgress = "Error: \(error)"
        self.error = .sessionError(error.localizedDescription)
    }

    func cancelSummarization() {
        summarizationTask?.cancel()
        summarizationTask = nil
    }

    func stopSession() {
        AppLog.log.debug("stop session")
        stopVoiceChat()
    }

    func updateState(_ newState: ProcessingState) async {
        await MainActor.run {
            AppLog.log.debug("Update to state: \(newState.description)")
            processingState = newState
        }
    }
}

extension EmailScreenViewModel {
    func getEmail(_ messageId: String) async -> GmailMessage? {
        do {
            let email = try await GmailService.getEmailDetails(messageId: messageId)
            originalEmails[messageId] = email
            return email
        } catch {
            self.error = .sessionError(error.localizedDescription)
        }
        return nil
    }

    func archiveEmails(_ emailIds: [String]) async throws {
        _ = try await GmailService.batchModifyEmails(
            ids: emailIds,
            removeLabelIds: ["INBOX"]
        )
    }

    func sendReply(_ email: GmailMessage, showQuote: Bool) async {
        guard !self.newMessage.isEmpty else { return }

        let replyBody = GmailUtilities.createGmailStyleReply(
            newMessage: self.newMessage,
            originalMessage: email.plainTextContent ?? "",
            date: GmailUtilities.formatGmailDate(timestamp: email.internalDate),
            from: email.from
        )

        do {
            _ = try await GmailService.replyToEmail(
                threadId: email.threadId,
                to: email.from,
                subject: email.subject,
                body: replyBody
            )
            self.newMessage = ""
        } catch {
            self.error = .sessionError(error.localizedDescription)
        }
    }
}

// MARK: Email permission
extension EmailScreenViewModel {
    private func checkGmailAccess() -> Bool {
        return GmailAuthHelper.shared.checkGmailAccessScopes()
    }

    private func ensureGmailAccess() async -> Bool {
        do {
            let token = try await GmailService.getAccessToken()
            return !token.isEmpty
        } catch {
            AppLog.log.debug("request gmail access due to: \(error)")
            do {
                let success = try await GmailAuthHelper.shared.requestGmailAccess()
                if success {
                    AppLog.log.debug("Gmail access granted successfully")
                } else {
                    AppLog.log.debug("Gmail access request returned false")
                }
                return success
            } catch let error as GmailAuthError {
                AppLog.log.error("Gmail Auth Error: \(error.localizedDescription)")
                let errorMessage: String
                switch error {
                case .noWindow, .noViewController:
                    errorMessage = "Cannot display Gmail login. Please try again."
                case .signInFailed(let underlying):
                    errorMessage = "Gmail sign in failed: \(underlying.localizedDescription)"
                case .scopeAdditionFailed(let underlying):
                    errorMessage = "Failed to get Gmail permissions: \(underlying.localizedDescription)"
                default:
                    errorMessage = "Unexpected Gmail Auth Error: \(error.localizedDescription)"
                }

                await updateState(.error(errorMessage))
            } catch {
                print("Unexpected error: \(error)")
                await updateState(.error("Gmail access required. Please grant access in Settings > Connected Apps."))
            }
            return false
        }
    }
}

// MARK: Helper extensions

extension EmailScreenViewModel {
    var weekDay: String {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: date)
    }

    var monthDay: String {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d"
        return dateFormatter.string(from: date)
    }
}
