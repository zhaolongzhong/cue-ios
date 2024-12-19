import Foundation
import Combine

@MainActor
public class GeminiChatViewModel: ObservableObject {
    let liveAPIWebSocketManager: LiveAPIWebSocketManager

    init(liveAPIWebSocketManager: LiveAPIWebSocketManager) {
        self.liveAPIWebSocketManager = liveAPIWebSocketManager
    }
}
