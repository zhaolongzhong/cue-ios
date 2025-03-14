import Foundation

enum GmailEndpoint {
    case listInbox(maxResults: Int = 10)
    case getMessageDetails(id: String)
    case sendMessage(to: String, subject: String, body: String)
    case replyToMessage(threadId: String, body: String)
    case deleteMessage(id: String)
    case modifyMessage(id: String, addLabels: [String], removeLabels: [String])
    case listLabels
}

extension GmailEndpoint: Endpoint {
    var baseURL: String {
        return "https://gmail.googleapis.com"
    }

    var path: String {
        switch self {
        case .listInbox:
            return "/gmail/v1/users/me/messages"
        case .getMessageDetails(let id):
            return "/gmail/v1/users/me/messages/\(id)"
        case .sendMessage:
            return "/gmail/v1/users/me/messages/send"
        case .replyToMessage:
            return "/gmail/v1/users/me/messages/send"
        case .deleteMessage(let id):
            return "/gmail/v1/users/me/messages/\(id)"
        case .modifyMessage(let id, _, _):
            return "/gmail/v1/users/me/messages/\(id)/modify"
        case .listLabels:
            return "/gmail/v1/users/me/labels"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .listInbox, .getMessageDetails, .listLabels:
            return .get
        case .sendMessage:
            return .post
        case .replyToMessage:
            return .post
        case .deleteMessage:
            return .delete
        case .modifyMessage:
            return .post
        }
    }

    var headers: [String: String]? {
        return [
            "Content-Type": "application/json"
        ]
    }

    var queryParameters: [String: String]? {
        switch self {
        case .listInbox(let maxResults):
            return [
                "labelIds": "INBOX",
                "maxResults": String(maxResults)
            ]
        case .getMessageDetails:
            return ["format": "full"]
        default:
            return nil
        }
    }

    var body: Data? {
        switch self {
        case .sendMessage(let to, let subject, let body):
            // Create MIME message
            let message = [
                "raw": createMimeMessage(to: to, subject: subject, body: body)
                    .data(using: .utf8)?
                    .base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "") ?? ""
            ]
            return try? JSONSerialization.data(withJSONObject: message)
        case .replyToMessage(let threadId, let body):
            let message = [
                "raw": body
                    .data(using: .utf8)?
                    .base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "") ?? "",
                "threadId": threadId
            ]
            return try? JSONSerialization.data(withJSONObject: message)
        case .modifyMessage(_, let addLabels, let removeLabels):
            let params: [String: [String]] = [
                "addLabelIds": addLabels,
                "removeLabelIds": removeLabels
            ]
            return try? JSONSerialization.data(withJSONObject: params)

        default:
            return nil
        }
    }

    var requiresAuth: Bool {
        return true
    }

    // Helper function to create MIME message
    private func createMimeMessage(to: String, subject: String, body: String) -> String {
//        """
//        From: me
//        To: \(to)
//        Subject: \(subject)
//        Content-Type: text/plain; charset="UTF-8"
//        Content-Transfer-Encoding: 8bit
//
//        \(body)
//        """
        return "To: \(to)\r\nSubject: \(subject)\r\n\r\n\(body)"
    }
}
