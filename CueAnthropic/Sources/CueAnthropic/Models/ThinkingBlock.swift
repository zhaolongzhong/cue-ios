//
//  ThinkingBlock.swift
//  CueAnthropic
//

extension Anthropic {
    public struct ThinkingBlock: Codable, Equatable, Sendable {
        public let type: String  // Will be "thinking"
        public let thinking: String
        public let signature: String

        public init(type: String, thinking: String, signature: String) {
            self.type = type
            self.thinking = thinking
            self.signature = signature
        }
    }
}
