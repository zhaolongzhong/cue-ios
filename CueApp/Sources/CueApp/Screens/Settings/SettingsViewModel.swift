import Foundation
import Dependencies

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var error: Error?
    @Published var showingNameEdit = false
    @Published var newName = ""
    
    @Dependency(\.userClient) private var userClient
    
    init() {
        self.currentUser = userClient.currentUser
    }
    
    func getVersionInfo() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    func updateName() async {
        guard !newName.isEmpty else { return }
        
        do {
            let updatedUser = try await userClient.updateUser(name: newName)
            self.currentUser = updatedUser
            self.showingNameEdit = false
            self.newName = ""
        } catch {
            self.error = error
        }
    }
    
    func clearError() {
        error = nil
    }
    
    func logout() async {
        do {
            try await userClient.logout()
        } catch {
            self.error = error
        }
    }
}