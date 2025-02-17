import SwiftUI

@MainActor
class EmailDetailViewModel: ObservableObject {
    @Published var emailMessage: GmailMessage?
    @Published var isLoading = false
    @Published var error: Error?

    func loadEmailDetails(emailId: String) {
        isLoading = true
        error = nil

        Task {
            do {
                let message = try await GmailService.getEmailDetails(messageId: emailId)
                await MainActor.run {
                    self.emailMessage = message
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }

    func markAsRead(emailId: String) {
        Task {
            do {
                _ = try await GmailService.modifyEmailLabels(
                    messageId: emailId,
                    removeLabelIds: ["UNREAD"]
                )
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }

    func archiveEmails(_ emailIds: [String]) {
        Task {
            do {
                _ = try await GmailService.batchModifyEmails(
                    ids: emailIds,
                    removeLabelIds: ["INBOX"]
                )
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
}

// MARK: - View Model State

extension EmailDetailViewModel {
    enum State {
        case loading
        case error(Error)
        case loaded(GmailMessage)
        case empty
    }

    var state: State {
        if isLoading {
            return .loading
        } else if let error = error {
            return .error(error)
        } else if let message = emailMessage {
            return .loaded(message)
        } else {
            return .empty
        }
    }
}
