import Foundation
import GoogleSignIn
import CueOpenAI
import OSLog

enum GmailServiceError: Error {
    case noUser, invalidResponse
}

struct GmailService {
    static func getAccessToken() throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw GmailServiceError.noUser
        }
        let token = currentUser.accessToken.tokenString
        return token
    }

    private static func buildRequest(for endpoint: GmailEndpoint) throws -> URLRequest {
        let token = try getAccessToken()
        let request = try endpoint.urlRequest(with: token, includeAdditionalHeaders: false)
        return request
    }

    static func readInbox(maxCount: Int = 20) async throws -> [CleanGmailMessage] {
        let request = try buildRequest(for: GmailEndpoint.listInbox(maxResults: maxCount))
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
        let request = try buildRequest(for: GmailEndpoint.getMessageDetails(id: messageId))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GmailServiceError.invalidResponse
        }
        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }

    static func sendEmail(to: String, subject: String, body: String) async throws -> String {
        let request = try buildRequest(for: GmailEndpoint.sendMessage(to: to, subject: subject, body: body))

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
        let request = try buildRequest(for: GmailEndpoint.listLabels)
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

        let request = try buildRequest(for: GmailEndpoint.modifyMessage(id: messageId, addLabels: addLabelIds, removeLabels: removeLabelIds))
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
        let token = try getAccessToken()
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
