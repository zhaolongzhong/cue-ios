import Foundation

public struct CompletionRequest: Codable {
    public let model: String
    public let tools: [JSONValue]
    public let toolChoice: String
    public let conversationId: String?
    
    public init(model: String, tools: [JSONValue], toolChoice: String, conversationId: String? = nil) {
        self.model = model
        self.tools = tools
        self.toolChoice = toolChoice
        self.conversationId = conversationId
    }
}