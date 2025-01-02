import SwiftUI
import Dependencies

@MainActor
public final class APIKeysViewModel: ObservableObject {
    @Dependency(\.apiKeyRepository) private var apiKeyRepository

    // MARK: - Published Properties
    @Published private(set) var apiKeys: [APIKey] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: AuthError?
    @Published var selectedKeyType = "live"
    @Published var selectedScopes: [String] = ["all"]
    @Published var expirationDate: Date?
    @Published var isShowingAddKey = false
    @Published var newKeyCreated: APIKeyPrivate?

    // MARK: - Pagination
    private let pageSize = 20
    private var currentPage = 0
    @Published private(set) var hasMorePages = true

    // MARK: - Fetch API Keys
    func fetch() async {
        isLoading = true
        error = nil

        let result = await apiKeyRepository.listAPIKeys(
            skip: currentPage * pageSize,
            limit: pageSize
        )

        switch result {
        case .success(let keys):
            apiKeys = currentPage == 0 ? keys : apiKeys + keys
            hasMorePages = keys.count == pageSize
            currentPage += 1
        case .failure(let fetchError):
            error = fetchError
        }

        isLoading = false
    }

    // MARK: - Create API Key
    func createNewAPIKey(name: String) async {
        isLoading = true
        error = nil

        let result = await apiKeyRepository.createAPIKey(
            name: name.isEmpty ? "My API Key" : name,
            keyType: selectedKeyType,
            scopes: selectedScopes,
            expiresAt: expirationDate
        )

        switch result {
        case .success(let privateKey):
            newKeyCreated = privateKey
            apiKeys.insert(privateKey.toPublicKey(), at: 0)
            resetForm()
        case .failure(let createError):
            error = createError
        }

        isLoading = false
    }

    func updateKey(_ key: APIKey, name: String) async {
        isLoading = true
        error = nil

        let result = await apiKeyRepository.updateAPIKey(
            id: key.id,
            name: name.isEmpty ? key.name : name,
            scopes: nil,  // Keep existing scopes
            expiresAt: nil,  // Keep existing expiration
            isActive: nil  // Keep existing active state
        )

        switch result {
        case .success(let updatedKey):
            if let index = apiKeys.firstIndex(where: { $0.id == key.id }) {
                apiKeys[index] = updatedKey
            }
        case .failure(let updateError):
            error = updateError
        }

        isLoading = false
    }

    func deleteKey(_ key: APIKey) async {
        isLoading = true
        error = nil

        let result = await apiKeyRepository.deleteAPIKey(id: key.id)

        switch result {
        case .success:
            apiKeys.removeAll { $0.id == key.id }
        case .failure(let deleteError):
            error = deleteError
        }

        isLoading = false
    }

    private func resetForm() {
        selectedKeyType = "live"
        selectedScopes = ["all"]
        expirationDate = nil
    }

    // MARK: - Update API Key
    func updateAPIKey(id: String, name: String?, scopes: [String]?, expiresAt: Date?, isActive: Bool?) async {
        isLoading = true
        error = nil

        let result = await apiKeyRepository.updateAPIKey(
            id: id,
            name: name,
            scopes: scopes,
            expiresAt: expiresAt,
            isActive: isActive
        )

        switch result {
        case .success(let updatedKey):
            if let index = apiKeys.firstIndex(where: { $0.id == id }) {
                apiKeys[index] = updatedKey
            }
        case .failure(let updateError):
            error = updateError
        }

        isLoading = false
    }

    // MARK: - Delete API Key
    func deleteAPIKey(id: String) async {
        isLoading = true
        error = nil

        let result = await apiKeyRepository.deleteAPIKey(id: id)

        switch result {
        case .success:
            apiKeys.removeAll { $0.id == id }
        case .failure(let deleteError):
            error = deleteError
        }

        isLoading = false
    }

    // MARK: - Refresh
    func refresh() async {
        currentPage = 0
        hasMorePages = true
        await fetch()
    }

    // MARK: - Load More
    func loadMoreIfNeeded(currentItem: APIKey) async {
        guard !isLoading,
              hasMorePages,
              let lastItem = apiKeys.last,
              lastItem.id == currentItem.id else {
            return
        }

        await fetch()
    }
}
