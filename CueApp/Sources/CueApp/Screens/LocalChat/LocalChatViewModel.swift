import Foundation
import Combine
import SwiftUI

@MainActor
final class LocalChatViewModel: ObservableObject {
    @Published var messages: [LocalChatMessage] = []
    @Published var newMessage: String = ""
    @Published var isLoading = false
    @Published var settings: LocalChatSettings {
        didSet {
            // Save settings when changed
            if let encoded = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(encoded, forKey: "LocalChatSettings")
            }
        }
    }
    
    init() {
        // Load saved settings or use default
        if let savedSettings = UserDefaults.standard.data(forKey: "LocalChatSettings"),
           let decoded = try? JSONDecoder().decode(LocalChatSettings.self, from: savedSettings) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
    }
    
    func sendMessage() async {
        guard !newMessage.isEmpty else { return }
        
        // Add user message
        let userMessage = LocalChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: newMessage,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Clear input and set loading state
        let userInput = newMessage
        newMessage = ""
        isLoading = true
        
        // Simulate network delay (1-2 seconds)
        try? await Task.sleep(nanoseconds: UInt64.random(in: 1_000_000_000...2_000_000_000))
        
        // Simulate assistant response
        let responseContent = "This is a simulated response to: \(userInput)\n\nLocal server settings:\nURL: \(settings.baseURL)\nModel: \(settings.model)"
        
        let assistantMessage = LocalChatMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: responseContent,
            timestamp: Date()
        )
        messages.append(assistantMessage)
        isLoading = false
    }
    
    func clearMessages() {
        messages.removeAll()
    }
}

// Simple message model for local chat
struct LocalChatMessage: Identifiable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
}

enum MessageRole {
    case user
    case assistant
    
    var color: Color {
        switch self {
        case .user: return .blue
        case .assistant: return .green
        }
    }
}

extension LocalChatMessage: Equatable {}