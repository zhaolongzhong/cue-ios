import Foundation
import Combine
import Dependencies

enum APIKeyResult<T: Sendable>: Sendable {
    case success(T)
    case failure(AuthError)
}

extension APIKeyRepository: DependencyKey {
    static let liveValue: APIKeyRepositoryProtocol = APIKeyRepository()
}

extension DependencyValues {
    var apiKeyRepository: APIKeyRepositoryProtocol {
        get { self[APIKeyRepository.self] }
        set { self[APIKeyRepository.self] = newValue }
    }
}

protocol APIKeyRepositoryProtocol: Sendable {
    func createAPIKey(name: String, keyType: String, scopes: [String]?, expiresAt: Date?) async -> APIKeyResult<APIKeyPrivate>
    func listAPIKeys(skip: Int, limit: Int) async -> APIKeyResult<[APIKey]>
    func getAPIKey(id: String) async -> APIKeyResult<APIKey>
    func updateAPIKey(id: String, name: String?, scopes: [String]?, expiresAt: Date?, isActive: Bool?) async -> APIKeyResult<APIKey>
    func deleteAPIKey(id: String) async -> APIKeyResult<APIKey>
}

actor APIKeyRepository: APIKeyRepositoryProtocol {
    @Dependency(\.apiKeyService) private var apiKeyService

    func createAPIKey(name: String, keyType: String, scopes: [String]?, expiresAt: Date?) async -> APIKeyResult<APIKeyPrivate> {
        do {
            let apiKey = try await apiKeyService.createAPIKey(
                name: name,
                keyType: keyType,
                scopes: scopes,
                expiresAt: expiresAt
            )
            return .success(apiKey)
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown)
        }
    }

    func listAPIKeys(skip: Int, limit: Int) async -> APIKeyResult<[APIKey]> {
        do {
            var apiKeys = try await apiKeyService.listAPIKeys(skip: skip, limit: limit)
            // Sort by creation date (newest first)
            apiKeys.sort { $0.createdAt > $1.createdAt }
            apiKeys.sort { first, second in
               switch (first.lastUsedAt, second.lastUsedAt) {
               case (nil, nil):
                   return false  // Both nil, maintain creation date order
               case (nil, _):
                   return false  // First is nil, move to end
               case (_, nil):
                   return true   // Second is nil, move to end
               case (let date1?, let date2?):
                   return date1 > date2  // Both have dates, newest first
               }
           }
            return .success(apiKeys)
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown)
        }
    }

    func getAPIKey(id: String) async -> APIKeyResult<APIKey> {
        do {
            let apiKey = try await apiKeyService.getAPIKey(id: id)
            return .success(apiKey)
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown)
        }
    }

    func updateAPIKey(id: String, name: String?, scopes: [String]?, expiresAt: Date?, isActive: Bool?) async -> APIKeyResult<APIKey> {
        do {
            let apiKey = try await apiKeyService.updateAPIKey(
                id: id,
                name: name,
                scopes: scopes,
                expiresAt: expiresAt,
                isActive: isActive
            )
            return .success(apiKey)
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown)
        }
    }

    func deleteAPIKey(id: String) async -> APIKeyResult<APIKey> {
        do {
            let apiKey = try await apiKeyService.deleteAPIKey(id: id)
            return .success(apiKey)
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown)
        }
    }
}
