import SwiftUI
import Dependencies

final class HomeViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Dependency(\.webSocketService) public var webSocketService
    private let userId: String

    init(userId: String) {
        self.userId = userId
    }

    @MainActor
    func initialize() async {
        await self.webSocketService.connect()
    }

    func navigateToDestination(_ destination: HomeDestination) {
        navigationPath.append(destination)
    }
}
