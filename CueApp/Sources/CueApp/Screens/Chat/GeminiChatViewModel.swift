import Foundation
import Combine

@MainActor
class GeminiChatViewModel: ObservableObject {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }
}
