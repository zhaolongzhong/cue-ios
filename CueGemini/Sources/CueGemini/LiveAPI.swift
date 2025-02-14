import Foundation

public final class LiveAPI: Sendable {
    private let host = "generativelanguage.googleapis.com"

    func createConnection(apiKey: String) throws -> WebSocketConnection {
        // https://github.com/google-gemini/cookbook/blob/main/gemini-2/websockets/live_api_starter.py
        let wsURL = "wss://\(host)/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: wsURL) else {
            throw LiveAPIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return WebSocketConnection(urlRequest: request)
    }
}
