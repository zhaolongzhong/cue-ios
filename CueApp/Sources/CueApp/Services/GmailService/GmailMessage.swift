import Foundation

struct InboxResponse: Codable, Sendable {
    let messages: [MessageIdentifier]

    struct MessageIdentifier: Codable, Sendable {
        let id: String
    }
}

struct GmailMessage: Codable, Equatable, Sendable, Identifiable, Hashable {
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
    var messageDate: String {
         if let internalDate = self.internalDate,
            let timestamp = Double(internalDate) {
             let date = Date(timeIntervalSince1970: timestamp / 1000.0)
             let dateFormatter = DateFormatter()
             dateFormatter.dateFormat = "MMMM d"
             return dateFormatter.string(from: date)
         }
         return ""
     }

    var receivedAt: Date? {
        if let internalDate = self.internalDate,
           let timestamp = Double(internalDate) {
            let date = Date(timeIntervalSince1970: timestamp / 1000.0)
            return date
        }
        return nil
    }

    var subject: String {
        getHeaderValue(self.payload?.headers, key: "Subject") ?? "No Subject"
    }
    var from: String {
        getHeaderValue(self.payload?.headers, key: "From") ?? "Unknown Sender"
    }

    var htmlContent: String? {
        getEmailContent(from: self, mimeType: .html)
    }

    var plainTextContent: String? {
        extractEmailBody(from: self)
    }
}

// Represents a MIME message part.
struct MessagePart: Codable, Equatable, Sendable, Hashable {
    let partId: String?
    let mimeType: String?
    let filename: String?
    let headers: [Header]?
    let body: MessagePartBody?
    let parts: [MessagePart]?
}

// Represents an individual email header.
struct Header: Codable, Equatable, Sendable, Hashable {
    let name: String?
    let value: String?
}

// Represents the body of a message part.
struct MessagePartBody: Codable, Equatable, Sendable, Hashable {
    let size: Int?
    let data: String?
    let attachmentId: String?
}

// Helper to fetch a header's value from an array.
func getHeaderValue(_ headers: [Header]?, key: String) -> String? {
    guard let headers = headers else { return nil }
    return headers.first { ($0.name?.lowercased() ?? "") == key.lowercased() }?.value
}

// Helper to extract the email body from a GmailMessage.
// It first looks at the top-level payload, and if not available, then in the payload parts.
enum MimeType: String {
    case html = "text/html"
    case plainText = "text/plain"
}

func getEmailContent(from message: GmailMessage, mimeType: MimeType = .plainText) -> String? {
    guard let parts = message.payload?.parts else {
        return nil
    }
    for part in parts {
        if part.mimeType == mimeType.rawValue,
           let dataString = part.body?.data,
           let decoded = decodeBase64URL(dataString) {
            return decoded
        }
    }
    if let dataString = message.payload?.body?.data,
       let decoded = decodeBase64URL(dataString) {
        return decoded
    }
    return nil
}

func extractEmailBody(from message: GmailMessage) -> String {
    // First try to get HTML content as it's typically more complete
    if let parts = message.payload?.parts {
        // Look for plain text first
        for part in parts {
            if part.mimeType == "text/plain",
               let dataString = part.body?.data,
               let decoded = decodeBase64URL(dataString) {
                return decoded
            }
        }

        // Fall back to HTML if plain text
        for part in parts {
            if part.mimeType == "text/html",
               let dataString = part.body?.data,
               let decoded = decodeBase64URL(dataString) {
                return decoded
            }
        }
    }

    // Try direct body content if no parts
    if let dataString = message.payload?.body?.data,
       let decoded = decodeBase64URL(dataString) {
        return decoded
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
