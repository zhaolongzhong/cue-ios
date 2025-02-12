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

        if let displayName = user.name {
            greeting = "\(timeBasedGreeting), \(displayName)"
        } else {
            greeting = timeBasedGreeting
        }
    }

    func navigateToDestination(_ destination: HomeDestination) {
        navigationPath.append(destination)
    }
}
