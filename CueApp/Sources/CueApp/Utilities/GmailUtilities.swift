import Foundation

public struct GmailUtilities {
    public static func formatGmailDate(timestamp: String?) -> String {
        guard let timestamp = timestamp,
              let timestampDouble = Double(timestamp) else {
            return Date().formatted(date: .abbreviated, time: .shortened)
        }

        let date = Date(timeIntervalSince1970: timestampDouble / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    public static func createGmailStyleReply(newMessage: String, originalMessage: String, date: String, from: String) -> String {
        // Escape HTML special characters in the messages
        let escapedNewMessage = newMessage
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")

        let escapedOriginalMessage = originalMessage
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")

        return """
        \(escapedNewMessage)<br>
        On \(date), \(from) wrote:<br>
        <blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px solid rgb(204,204,204);padding-left:1ex">
            \(escapedOriginalMessage)
        </blockquote>
        """
    }

    public static func createMIMEMessage(to: String, subject: String, body: String, threadId: String, boundary: String) -> String {
        // Create the plain text version (for non-HTML clients)
        let plainText = body.replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        let message = """
MIME-Version: 1.0
To: \(to)
Subject: Re: \(subject)
In-Reply-To: \(threadId)
References: \(threadId)
Content-Type: multipart/alternative; boundary=\(boundary)

--\(boundary)
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

\(plainText)

--\(boundary)
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: 7bit

\(body)
--\(boundary)--
"""
        return message
    }
}
