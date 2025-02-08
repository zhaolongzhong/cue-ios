import Foundation
import GoogleSignIn
import CueOpenAI

// MARK: - Gmail Service

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

    static func readInbox(maxCount: Int = 20) async throws -> String {
        let token = try getAccessToken()
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?labelIds=INBOX&maxResults=\(maxCount)") else {
            throw GmailServiceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            throw GmailServiceError.invalidResponse
        }
        let ids = messages.compactMap { $0["id"] as? String }
        return "Inbox message IDs: \(ids.joined(separator: ", "))"
    }

    static func getEmailDetails(messageId: String) async throws -> String {
        let token = try getAccessToken()
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)?format=full") else {
            throw GmailServiceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GmailServiceError.invalidResponse
        }
        // For simplicity, return the pretty-printed JSON？ ？？ddfddd
        let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        return String(data: prettyData, encoding: .utf8) ?? "No details"
    }

    static func sendEmail(to: String, subject: String, body: String) async throws -> String {
        let token = try getAccessToken()
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send") else {
            throw GmailServiceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Create a simple MIME message.
        let messageString = "To: \(to)\r\nSubject: \(subject)\r\n\r\n\(body)"
        guard let messageData = messageString.data(using: .utf8) else {
            throw GmailServiceError.invalidResponse
        }
        var raw = messageData.base64EncodedString()
        // Make URL-safe.
        raw = raw.replacingOccurrences(of: "+", with: "-")
                 .replacingOccurrences(of: "/", with: "_")
                 .replacingOccurrences(of: "=", with: "")

        let jsonBody: [String: Any] = ["raw": raw]
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            print("Error sending email. Status code: \(httpResponse.statusCode), response: \(responseString)")
            throw GmailServiceError.invalidResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            throw GmailServiceError.invalidResponse
        }
        return "Email sent successfully. Message ID: \(id)"
    }

    static func modifyEmailLabels(messageId: String,
                                  addLabelIds: [String] = [],
                                  removeLabelIds: [String] = []) async throws -> String {
        let token = try getAccessToken()
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)/modify") else {
            print("DEBUG: Invalid URL for modifying labels")
            throw GmailServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let jsonBody: [String: Any] = [
            "addLabelIds": addLabelIds,
            "removeLabelIds": removeLabelIds
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("DEBUG: HTTP Status code: \(httpResponse.statusCode)")
            throw GmailServiceError.invalidResponse
        }

        return "Email \(messageId) modified successfully."
    }

    // New: Batch modify labels on multiple emails
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
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GmailServiceError.invalidResponse
        }
        return "Batch modification successful for emails: \(messageIds.joined(separator: ", "))"
    }

    static func listLabels() async throws -> String {
        let token = try getAccessToken()
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/labels") else {
            throw GmailServiceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

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
}

// MARK: - Tool Definition

struct GmailParameters: ToolParameters, Sendable {
    let schema: [String: Property] = [
        "action": Property(type: "string", description: "Action: readInbox, getEmailDetails, sendEmail, modifyEmailLabels, batchModifyEmails, archiveEmail, batchArchiveEmails, listLabels"),
        "maxCount": Property(type: "integer", description: "Max inbox messages (readInbox only), default is 20"),
        "messageId": Property(type: "string", description: "Message ID (getEmailDetails, modifyEmailLabels, archiveEmail)"),
        "messageIds": Property(
            type: "array",
            description: "Array of Message IDs (batchModifyEmails, batchArchiveEmails)",
            items: Property.PropertyItems(type: "string")
        ),
        "to": Property(type: "string", description: "Recipient email (sendEmail only)"),
        "subject": Property(type: "string", description: "Email subject (sendEmail only)"),
        "body": Property(type: "string", description: "Email body (sendEmail only)"),
        "addLabelIds": Property(
            type: "array",
            description: "Label IDs to add (modifyEmailLabels, batchModifyEmails)",
            items: Property.PropertyItems(type: "string")
        ),
        "removeLabelIds": Property(
            type: "array",
            description: "Label IDs to remove (modifyEmailLabels, batchModifyEmails)",
            items: Property.PropertyItems(type: "string")
        )
    ]

    let required: [String] = ["action"]
}

struct GmailTool: LocalTool, Sendable {
    let name: String = "manage_gmail"
    let description: String = "Manage Gmail: read inbox, get details, send email, and modify labels."
    let parameterDefinition: ToolParameters = GmailParameters()

    func call(_ args: ToolArguments) async throws -> String {
        guard let action = args.getString("action") else {
            throw ToolError.invalidArguments("Missing action")
        }
        switch action {
        case "readInbox":
            let maxCount = args.getInt("maxCount") ?? 20
            return try await GmailService.readInbox(maxCount: maxCount)
        case "getEmailDetails":
            guard let messageId = args.getString("messageId") else {
                throw ToolError.invalidArguments("Missing messageId")
            }
            return try await GmailService.getEmailDetails(messageId: messageId)
        case "sendEmail":
            guard let to = args.getString("to"),
                  let subject = args.getString("subject"),
                  let body = args.getString("body") else {
                throw ToolError.invalidArguments("Missing to, subject, or body")
            }
            return try await GmailService.sendEmail(to: to, subject: subject, body: body)
        case "modifyEmailLabels":
            guard let messageId = args.getString("messageId") else {
                throw ToolError.invalidArguments("Missing messageId")
            }
            let addLabels = args.getArray("addLabelIds") as? [String] ?? []
            let removeLabels = args.getArray("removeLabelIds") as? [String] ?? []
            return try await GmailService.modifyEmailLabels(messageId: messageId,
                                                             addLabelIds: addLabels,
                                                             removeLabelIds: removeLabels)
        case "batchModifyEmails":
            guard let messageIds = args.getArray("messageIds") as? [String] else {
                throw ToolError.invalidArguments("Missing messageIds")
            }
            let addLabels = args.getArray("addLabelIds") as? [String] ?? []
            let removeLabels = args.getArray("removeLabelIds") as? [String] ?? []
            return try await GmailService.batchModifyEmails(messageIds: messageIds,
                                                            addLabelIds: addLabels,
                                                            removeLabelIds: removeLabels)
        // Convenience actions for archiving (removing the INBOX label)
        case "archiveEmail":
            guard let messageId = args.getString("messageId") else {
                throw ToolError.invalidArguments("Missing messageId")
            }
            return try await GmailService.modifyEmailLabels(messageId: messageId, removeLabelIds: ["INBOX"])
        case "batchArchiveEmails":
            guard let messageIds = args.getArray("messageIds") as? [String] else {
                throw ToolError.invalidArguments("Missing messageIds")
            }
            return try await GmailService.batchModifyEmails(messageIds: messageIds, removeLabelIds: ["INBOX"])
        case "listLabels":
            return try await GmailService.listLabels()
        default:
            throw ToolError.invalidArguments("Invalid action: \(action)")
        }
    }
}
