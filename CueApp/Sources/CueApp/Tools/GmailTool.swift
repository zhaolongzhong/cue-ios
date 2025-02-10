import Foundation
import GoogleSignIn
import CueOpenAI

// MARK: - Tool Definition

struct GmailParameters: ToolParameters, Sendable {
    let schema: [String: Property] = [
        "action": Property(
            type: "string",
            description: "Action: readInbox, getEmailDetails, sendEmail, modifyEmailLabels, batchModifyEmails, archiveEmail, batchArchiveEmails, listLabels"
        ),
        "maxCount": Property(
            type: "integer",
            description: "Max inbox messages (readInbox only), default is 20"
        ),
        "messageId": Property(
            type: "string",
            description: "Message ID (getEmailDetails, modifyEmailLabels, archiveEmail)"
        ),
        "messageIds": Property(
            type: "array",
            description: "Array of Message IDs (batchModifyEmails, batchArchiveEmails)",
            items: Property.PropertyItems(type: "string")
        ),
        "to": Property(
            type: "string",
            description: "Recipient email (sendEmail only)"
        ),
        "subject": Property(
            type: "string",
            description: "Email subject (sendEmail only)"
        ),
        "body": Property(
            type: "string",
            description: "Email body (sendEmail only)"
        ),
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
            let message = try await GmailService.getEmailDetails(messageId: messageId)
            let cleanMessage = CleanGmailMessage(from: message)
            return cleanMessage.toString(includeContent: true)
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
