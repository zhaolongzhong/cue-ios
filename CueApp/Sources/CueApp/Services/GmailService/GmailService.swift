import Foundation
import GoogleSignIn
import CueOpenAI
import OSLog

struct GmailService {
    static let tokenKey = "gmail_access_token"
    static let refreshTokenKey = "gmail_refresh_token"
    static let tokenExpirationKey = "gmail_token_expiration"

    private static var clientId: String {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            fatalError("GIDClientID not found in Info.plist")
        }
        return clientId
    }

    // Get access token with automatic refresh if needed
    static func getAccessToken() async throws -> String {
        // Check if token needs refresh
        if let expirationDate = UserDefaults.standard.object(forKey: tokenExpirationKey) as? Date,
           Date() >= expirationDate {
            return try await refreshTokenOffline()
        }

        // Return stored token if available
        if let storedToken = UserDefaults.standard.string(forKey: tokenKey) {
            return storedToken
        }

        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw GmailServiceError.authenticationError
        }

        // If no stored token, get fresh token and store it
       let token = currentUser.accessToken.tokenString
       let expirationDate = currentUser.accessToken.expirationDate ?? Date().addingTimeInterval(3600) // Default to 1 hour if no expiration provided
       try storeToken(token, expirationDate: expirationDate)
       return token
    }

    // Store token and its expiration date
    static private func storeToken(_ token: String, expirationDate: Date) throws {
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(expirationDate, forKey: tokenExpirationKey)

        // Store refresh token if available
        if let refreshToken = GIDSignIn.sharedInstance.currentUser?.refreshToken.tokenString {
            UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        }

        if !UserDefaults.standard.synchronize() {
            throw GmailServiceError.tokenStorageError
        }
    }

    // Refresh token using refresh token
    static func refreshTokenOffline() async throws -> String {
            guard let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) else {
                throw GmailServiceError.tokenRefreshError
            }

            guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
                throw GmailServiceError.invalidResponse
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            // Parameters for public client token refresh
            let parameters = [
                "client_id": clientId,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token"
            ]

            let bodyString = parameters
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "&")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

            request.httpBody = bodyString.data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GmailServiceError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
                AppLog.log.error("Token refresh failed with status code: \(httpResponse.statusCode), error: \(errorResponse)")
                throw GmailServiceError.tokenRefreshError
            }

            let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
            let expirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))

            try storeToken(tokenResponse.accessToken, expirationDate: expirationDate)
            return tokenResponse.accessToken
        }

    // Clear stored tokens
    static func clearTokens() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpirationKey)
        UserDefaults.standard.synchronize()
    }

    private static func buildRequest(for endpoint: GmailEndpoint) async throws -> URLRequest {
        let token = try await getAccessToken()
        let request = try endpoint.urlRequest(with: token, includeAdditionalHeaders: false)
        return request
    }

    static func readInbox(maxCount: Int = 20) async throws -> [CleanGmailMessage] {
        let request = try await buildRequest(for: GmailEndpoint.listInbox(maxResults: maxCount))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            throw GmailServiceError.invalidResponse
        }

        // Fetch full details concurrently for each message to get snippets
        let detailedMessages = try await withThrowingTaskGroup(of: GmailMessage.self) { group -> [GmailMessage] in
            for message in messages {
                if let id = message["id"] as? String {
                    group.addTask {
                        return try await getEmailDetails(messageId: id)
                    }
                }
            }
            var results: [GmailMessage] = []
            for try await detail in group {
                results.append(detail)
            }
            // Sort messages by date, latest first
            return results.sorted { $0.messageDate > $1.messageDate }
        }
        var output: [CleanGmailMessage] = []
        for message in detailedMessages {
            let cleanMessage = CleanGmailMessage(from: message)
            output.append(cleanMessage)
        }
        return output
    }

    static func getEmailDetails(messageId: String) async throws -> GmailMessage {
        let request = try await buildRequest(for: GmailEndpoint.getMessageDetails(id: messageId))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GmailServiceError.invalidResponse
        }
        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }

    static func sendEmail(to: String, subject: String, body: String) async throws -> String {
        let request = try await buildRequest(for: GmailEndpoint.sendMessage(to: to, subject: subject, body: body))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            AppLog.log.error("Error sending email. Status code: \(httpResponse.statusCode), response: \(responseString)")
            throw GmailServiceError.invalidResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            throw GmailServiceError.invalidResponse
        }
        return "Email sent successfully. Message ID: \(id)"
    }

    static func listLabels() async throws -> String {
        let request = try await buildRequest(for: GmailEndpoint.listLabels)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let labels = json["labels"] as? [[String: Any]] else {
            throw GmailServiceError.invalidResponse
        }

        let labelList = labels.compactMap { label -> String? in
            if let id = label["id"] as? String, let name = label["name"] as? String {
                return "\(name) (\(id))"
            }
            return nil
        }.joined(separator: "\n")

        return "Labels:\n\(labelList)"
    }

    static func modifyEmailLabels(messageId: String,
                                  addLabelIds: [String] = [],
                                  removeLabelIds: [String] = []) async throws -> String {

        let request = try await buildRequest(for: GmailEndpoint.modifyMessage(id: messageId, addLabels: addLabelIds, removeLabels: removeLabelIds))
        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            AppLog.log.error("HTTP Status code: \(httpResponse.statusCode)")
            throw GmailServiceError.invalidResponse
        }

        return "Email \(messageId) modified successfully."
    }

    static func batchModifyEmails(messageIds: [String],
                                  addLabelIds: [String] = [],
                                  removeLabelIds: [String] = []) async throws -> String {
        let token = try await getAccessToken()
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/batchModify") else {
            throw GmailServiceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonBody: [String: Any] = [
            "ids": messageIds,
            "addLabelIds": addLabelIds,
            "removeLabelIds": removeLabelIds
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            AppLog.log.error("HTTP Status code: \(httpResponse.statusCode)")
            throw GmailServiceError.invalidResponse
        }
        return "Batch modification successful for emails: \(messageIds.joined(separator: ", "))"
    }
}
