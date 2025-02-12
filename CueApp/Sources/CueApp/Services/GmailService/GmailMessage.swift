import Foundation

struct InboxResponse: Codable, Sendable {
    let messages: [MessageIdentifier]

    struct MessageIdentifier: Codable, Sendable {
        let id: String
    }
}

struct GmailMessage: Codable, Sendable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let historyId: String?
    let internalDate: String?  // "int64 format" represented as a String
    let payload: MessagePart?
    let sizeEstimate: Int?
    let raw: String?
}

extension GmailMessage {
    // Convert internalDate (Unix timestamp in milliseconds) to Date
    var messageDate: Date {
        if let internalDate = self.internalDate,
           let timestamp = Double(internalDate) {
            // Convert milliseconds to seconds
            return Date(timeIntervalSince1970: timestamp / 1000.0)
        }
        return .distantPast
    }
}

// Represents a MIME message part.
struct MessagePart: Codable, Sendable {
    let partId: String?
    let mimeType: String?
    let filename: String?
    let headers: [Header]?
    let body: MessagePartBody?
    let parts: [MessagePart]?
}

// Represents an individual email header.
struct Header: Codable, Sendable {
    let name: String?
    let value: String?
}

// Represents the body of a message part.
struct MessagePartBody: Codable, Sendable {
    let size: Int?
    let data: String?
    let attachmentId: String?
}

struct CleanGmailMessage: Sendable {
    let id: String
    let subject: String
    let from: String
    let snippet: String
    let content: String
    let date: String
    let labelIds: [String]
}

extension CleanGmailMessage {
    // Initialize from a raw GmailMessage by extracting header values.
    init(from gmailMessage: GmailMessage) {
        self.id = gmailMessage.id
        self.snippet = gmailMessage.snippet ?? "[No snippet]"
        self.content = extractEmailBody(from: gmailMessage)
        let headers = gmailMessage.payload?.headers
        self.subject = getHeaderValue(headers, key: "Subject") ?? "[No subject]"
        self.from = getHeaderValue(headers, key: "From") ?? "[No sender]"
        self.date = getHeaderValue(headers, key: "Date") ?? "[No date]"
        self.labelIds = gmailMessage.labelIds ?? []
    }

    func toString(includeContent: Bool = false) -> String {
        if includeContent {
            return """
            ID: \(self.id)
            Subject: \(self.subject)
            From: \(self.from)
            Date: \(self.date)
            LabelIds: \(self.labelIds.joined(separator: ", "))
            Snippet: \(self.snippet)
            Content: \(self.content)
            """
        } else {
            return """
            ID: \(self.id)
            Subject: \(self.subject)
            From: \(self.from)
            Date: \(self.date)
            LabelIds: \(self.labelIds.joined(separator: ", "))
            Snippet: \(self.snippet)
            """
        }
    }
}

// Helper to fetch a header's value from an array.
func getHeaderValue(_ headers: [Header]?, key: String) -> String? {
    guard let headers = headers else { return nil }
    return headers.first { ($0.name?.lowercased() ?? "") == key.lowercased() }?.value
}

// Helper to extract the email body from a GmailMessage.
// It first looks at the top-level payload, and if not available, then in the payload parts.
func extractEmailBody(from message: GmailMessage) -> String {
    if let dataString = message.payload?.body?.data,
       let decoded = decodeBase64URL(dataString) {
        return decoded
    }
    if let parts = message.payload?.parts {
        for part in parts {
            if part.mimeType == "text/plain",
               let dataString = part.body?.data,
               let decoded = decodeBase64URL(dataString) {
                return decoded
            }
        }
    }
    return "[No body content]"
}

// Helper to decode a base64url-encoded string.
func decodeBase64URL(_ base64URLString: String) -> String? {
    var base64 = base64URLString
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    // Add padding if necessary.
    let remainder = base64.count % 4
    if remainder > 0 {
        base64.append(String(repeating: "=", count: 4 - remainder))
    }
    guard let data = Data(base64Encoded: base64) else { return nil }
    return String(data: data, encoding: .utf8)
}
