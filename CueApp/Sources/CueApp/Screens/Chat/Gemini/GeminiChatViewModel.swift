import Foundation
import CueGemini

@MainActor
public class GeminiChatViewModel: ObservableObject {

    @Published var messageContent: String = ""
    @Published var newMessage: String = ""
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isConnecting: Bool = false
    @Published private(set) var error: ChatError? = nil

    private let liveAPIWebSocketManager: LiveAPIWebSocketManager
    private var messages: [String] = []

    public init() {
        self.liveAPIWebSocketManager = LiveAPIWebSocketManager()
        setupWebSocketCallbacks()
    }

    public func connect(apiKey: String) async throws {
        isConnecting = true
        do {
            try await liveAPIWebSocketManager.connect(apiKey: apiKey)
            isConnected = true
        } catch {
            self.error = .sessionError(error.localizedDescription)
            isConnected = false
        }
        isConnecting = false
    }

    public func disconnect() {
        liveAPIWebSocketManager.disconnect()
        isConnected = false
    }

    public func sendMessage(apiKey: String) async throws {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        do {
            try await liveAPIWebSocketManager.sendText(newMessage)
            messages.append(newMessage)
            newMessage = ""
        } catch {
            self.error = .sessionError(error.localizedDescription)
        }
    }

    public func clearError() {
        error = nil
    }

    func handleBackgroundState() {
        disconnect()
    }

    func handleActiveState() {
        // Implement reconnection logic if needed
    }

    func handleInactiveState() {
        // Implement any cleanup needed
    }

    // MARK: - Private Methods

    private func setupWebSocketCallbacks() {
        // Add any WebSocket callback handling here
        // For example, message received callbacks, connection status updates, etc.
    }
}
