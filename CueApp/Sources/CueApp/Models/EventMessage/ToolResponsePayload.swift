struct ToolResponsePayload: Codable {
    let msgId: String
    let model: String
    let author: Author
    let toolResultMessage: ToolResultMessage?
    let toolMessages: ToolMessages?

    enum CodingKeys: String, CodingKey {
        case msgId = "msg_id"
        case model
        case author
        case toolResultMessage = "tool_result_message"
        case toolMessages = "tool_messages"
    }
}
