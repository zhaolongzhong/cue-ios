import Foundation
import Combine
import CueOpenAI
import Dependencies
import OSLog

@MainActor
class EmailScreenViewModel: ObservableObject {
    let logger = Logger(subsystem: "EmailScreenViewModel", category: "Email")

    @Dependency(\.realtimeClient) var realtimeClient
    @Dependency(\.authRepository) var authRepository
    @Published var emailSummaries: [EmailSummary] = []
    @Published private(set) var processingState: ProcessingState = .idle
    @Published var voiceChatState: VoiceChatState = .idle
    @Published var deltaMessage: String = ""
    @Published var micPermissionGranted: Bool = true
    @Published var showMicAlert: Bool = false
    @Published var name: String = ""

    var handledEventIds: Set<String> = []
    var cancellables = Set<AnyCancellable>()
    let toolManager: ToolManager
    let apiKey: String
    private let maxEmails: Int = 20

    public init(apiKey: String) {
        self.apiKey = apiKey
        self.toolManager = ToolManager()
    }

    // MARK: - Main Processing Methods

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

    func startProcessing() async {
        name = authRepository.currentUser?.name ?? "there"
        let hasAccess = await ensureGmailAccess()
        guard hasAccess else {
            return
        }
        await updateState(.gettingInbox)
        do {
            let inboxResponse = try await GmailService.readInbox(maxCount: maxEmails)
            await updateState(.organizingTasks)
            try await Task.sleep(nanoseconds: 1_500_000_000)

            await updateState(.analyzingMessages)

            let emails = inboxResponse.map { $0.toString()}
            let summaries = try await summarizeEmails(emails)
            await MainActor.run {
                self.emailSummaries = summaries
            }

            await updateState(.almostReady)
            try await Task.sleep(nanoseconds: 1_000_000_000)

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

    func stopSession() {
        stopVoiceChat()
    }

    func updateState(_ newState: ProcessingState) async {
        await MainActor.run {
            AppLog.log.debug("Update to state: \(newState.description)")
            processingState = newState
        }
    }
}
