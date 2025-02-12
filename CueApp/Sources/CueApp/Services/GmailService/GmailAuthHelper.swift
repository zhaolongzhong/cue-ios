import Foundation
import GoogleSignIn
import OSLog

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum GmailAuthError: Error {
    case noWindow
    case noViewController
    case signInFailed(Error)
    case scopeAdditionFailed(Error)
    case invalidPresentingViewController
        case invalidPresentingWindow

    var localizedDescription: String {
        switch self {
        case .noWindow:
            return "Could not get window"
        case .noViewController:
            return "Could not get root view controller"
        case .signInFailed(let error):
            return "Sign in failed: \(error.localizedDescription)"
        case .scopeAdditionFailed(let error):
            return "Failed to add Gmail scopes: \(error.localizedDescription)"
        case .invalidPresentingViewController:
            return "Invalid presenting view controller"
        case .invalidPresentingWindow:
            return "Invalid presenting window"
        }
    }
}

@MainActor
final class GmailAuthHelper: @unchecked Sendable {
    static let shared = GmailAuthHelper()
    private let logger = Logger(subsystem: "GmailAuthHelper", category: "Permissions")
    private let gmailReadScope = "https://www.googleapis.com/auth/gmail.readonly"
    private let gmailSendScope = "https://www.googleapis.com/auth/gmail.send"
    private let gmailModifyScope = "https://www.googleapis.com/auth/gmail.modify"

    private init() {}

    var requiredScopes: [String] {
        [gmailReadScope, gmailSendScope, gmailModifyScope]
    }

    func checkGmailAccessScopes() -> Bool {
        if let currentUser = GIDSignIn.sharedInstance.currentUser,
           let scopes = currentUser.grantedScopes {
            return scopes.contains(gmailReadScope) &&
                   scopes.contains(gmailSendScope) &&
                   scopes.contains(gmailModifyScope)
        }
        return false
    }

    func requestGmailAccess() async throws -> Bool {
        logger.debug("request gmail access")
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootViewController = windowScene.keyWindow?.rootViewController else {
            throw GmailAuthError.noViewController
        }
        #elseif os(macOS)
        guard let window = NSApplication.shared.windows.first else {
            throw GmailAuthError.noWindow
        }
        #endif

        do {
            try await withCheckedThrowingContinuation { continuation in
                #if os(iOS)
                handleSignIn(presenting: rootViewController, continuation: continuation)
                #elseif os(macOS)
                handleSignIn(presenting: window, continuation: continuation)
                #endif
            }
            return true
        } catch {
            throw error
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    #if os(iOS)
    private func handleSignIn(presenting viewController: UIViewController, continuation: CheckedContinuation<Void, Error>) {
        if GIDSignIn.sharedInstance.currentUser == nil {
            GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] signInResult, error in
                guard let self = self else { return }

                if let error = error {
                    continuation.resume(throwing: GmailAuthError.signInFailed(error))
                    return
                }

                self.handleScopeAddition(signInResult: signInResult, presenting: viewController, continuation: continuation)
            }
        } else {
            handleExistingUser(presenting: viewController, continuation: continuation)
        }
    }
    #elseif os(macOS)
    private func handleSignIn(presenting window: NSWindow, continuation: CheckedContinuation<Void, Error>) {
        if GIDSignIn.sharedInstance.currentUser == nil {
            GIDSignIn.sharedInstance.signIn(withPresenting: window) { [weak self] signInResult, error in
                guard let self = self else { return }

                if let error = error {
                    continuation.resume(throwing: GmailAuthError.signInFailed(error))
                    return
                }

                self.handleScopeAddition(signInResult: signInResult, presenting: window, continuation: continuation)
            }
        } else {
            handleExistingUser(presenting: window, continuation: continuation)
        }
    }
    #endif

    private func handleScopeAddition(signInResult: GIDSignInResult?, presenting: Any, continuation: CheckedContinuation<Void, Error>) {
        // First verify which scopes we already have
        let grantedScopes = signInResult?.user.grantedScopes ?? []
        let missingScopes = requiredScopes.filter { !grantedScopes.contains($0) }

        if missingScopes.isEmpty {
            continuation.resume()
            return
        }

        // Only request scopes we don't already have
        #if os(iOS)
        guard let presentingViewController = presenting as? UIViewController else {
            continuation.resume(throwing: GmailAuthError.invalidPresentingViewController)
            return
        }
        signInResult?.user.addScopes(missingScopes, presenting: presentingViewController) { _, error in
            if let error = error {
                continuation.resume(throwing: GmailAuthError.scopeAdditionFailed(error))
            } else {
                continuation.resume()
            }
        }
        #elseif os(macOS)
        guard let presentingWindow = presenting as? NSWindow else {
            continuation.resume(throwing: GmailAuthError.invalidPresentingWindow)
            return
        }
        signInResult?.user.addScopes(missingScopes, presenting: presentingWindow) { _, error in
            if let error = error {
                continuation.resume(throwing: GmailAuthError.scopeAdditionFailed(error))
            } else {
                continuation.resume()
            }
        }
        #endif
    }

    private func handleExistingUser(presenting: Any, continuation: CheckedContinuation<Void, Error>) {
        if checkGmailAccessScopes() {
            logger.debug("Already have all scopes")
            return
        }

        #if os(iOS)
        guard let presentingViewController = presenting as? UIViewController else {
            continuation.resume(throwing: GmailAuthError.invalidPresentingViewController)
            return
        }
        GIDSignIn.sharedInstance.currentUser?.addScopes(
            requiredScopes,
            presenting: presentingViewController
        ) { _, error in
            if let error = error {
                continuation.resume(throwing: GmailAuthError.scopeAdditionFailed(error))
            } else {
                continuation.resume()
            }
        }
        #elseif os(macOS)
        guard let presentingWindow = presenting as? NSWindow else {
            continuation.resume(throwing: GmailAuthError.invalidPresentingWindow)
            return
        }
        GIDSignIn.sharedInstance.currentUser?.addScopes(
            requiredScopes,
            presenting: presentingWindow
        ) { _, error in
            if let error = error {
                continuation.resume(throwing: GmailAuthError.scopeAdditionFailed(error))
            } else {
                continuation.resume()
            }
        }
        #endif
    }
}
