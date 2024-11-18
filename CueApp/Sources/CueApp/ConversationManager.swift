import SwiftUI
import OpenAI
import AVFoundation
import Combine
import os.log

public class ConversationManager: ObservableObject, @unchecked Sendable {
    public init() {}
    public var conversation: Conversation?

    public func initialize(authToken: String) {
        if self.conversation == nil {
            DispatchQueue.global(qos: .background).async {
                self.conversation = Conversation(authToken: authToken)
            }
        }
    }

    public func cleanup() {
        DispatchQueue.global(qos: .background).async {
            self.conversation = nil
        }
    }
}
