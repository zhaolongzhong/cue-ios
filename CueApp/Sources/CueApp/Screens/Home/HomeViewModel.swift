import SwiftUI
import Dependencies
import CueOpenAI

@MainActor
final class HomeViewModel: ObservableObject {
    @Dependency(\.authRepository) var authRepository
    @Dependency(\.webSocketService) public var webSocketService

    @Published var navigationPath = NavigationPath()
    @Published var greeting: String = ""
    @Published var quoteOrFunFact: [QuoteContent] = []

    func initialize() async {
        guard let currentUser = authRepository.currentUser else { return }
        getGreeting(for: currentUser)
        await self.webSocketService.connect()
    }

    private func getGreeting(for user: User) {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeBasedGreeting: String

        if hour < 12 {
            timeBasedGreeting = "Good morning"
        } else if hour < 18 {
            timeBasedGreeting = "Good afternoon"
        } else {
            timeBasedGreeting = "Good evening"
        }

        if let displayName = extractDisplayName(from: user) {
            greeting = "\(timeBasedGreeting), \(displayName)"
        } else {
            greeting = timeBasedGreeting
        }
    }

    private func extractDisplayName(from user: User) -> String? {
        if let fullName = user.name,
           let firstName = fullName.split(separator: " ").first {
            return String(firstName)
        }

        // If no name is available, process the email
        let emailParts = user.email.split(separator: "@")
        if let username = emailParts.first, username.count >= 2 {
            return String(username.prefix(2).uppercased())
        }

        return nil
    }

    func navigateToDestination(_ destination: HomeDestination) {
        navigationPath.append(destination)
    }
}
