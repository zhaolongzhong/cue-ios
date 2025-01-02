import Foundation
import Dependencies
import os.log

extension APIKeyService: DependencyKey {
    public static let liveValue = APIKeyService()
}

extension DependencyValues {
    var apiKeyService: APIKeyService {
        get { self[APIKeyService.self] }
        set { self[APIKeyService.self] = newValue }
    }
}

protocol APIKeyServiceProtocol: Sendable {
    func createAPIKey(name: String, keyType: String, scopes: [String]?, expiresAt: Date?) async throws -> APIKeyPrivate
    func listAPIKeys(skip: Int, limit: Int) async throws -> [APIKey]
    func getAPIKey(id: String) async throws -> APIKey
    func updateAPIKey(id: String, name: String?, scopes: [String]?, expiresAt: Date?, isActive: Bool?) async throws -> APIKey
    func deleteAPIKey(id: String) async throws -> APIKey
}

final class APIKeyService: APIKeyServiceProtocol {
    private let logger = Logger(subsystem: "APIKeyService", category: "APIKeys")

    func createAPIKey(name: String, keyType: String, scopes: [String]?, expiresAt: Date?) async throws -> APIKeyPrivate {
        do {
            return try await NetworkClient.shared.request(
                APIKeysEndpoint.create(
                    name: name,
                    keyType: keyType,
                    scopes: scopes,
                    expiresAt: expiresAt
                )
            )
        } catch NetworkError.unauthorized {
            throw AuthError.unauthorized
        } catch {
            logger.error("Create API key error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }

    func listAPIKeys(skip: Int, limit: Int) async throws -> [APIKey] {
        do {
            return try await NetworkClient.shared.request(
                APIKeysEndpoint.list(skip: skip, limit: limit)
            )
        } catch NetworkError.unauthorized {
            throw AuthError.unauthorized
        } catch {
            logger.error("List API keys error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }

    func getAPIKey(id: String) async throws -> APIKey {
        do {
            return try await NetworkClient.shared.request(
                APIKeysEndpoint.get(id: id)
            )
        } catch NetworkError.unauthorized {
            throw AuthError.unauthorized
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw AuthError.invalidResponse
        } catch {
            logger.error("Get API key error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }

    func updateAPIKey(id: String, name: String?, scopes: [String]?, expiresAt: Date?, isActive: Bool?) async throws -> APIKey {
        do {
            return try await NetworkClient.shared.request(
                APIKeysEndpoint.update(
                    id: id,
                    name: name,
                    scopes: scopes,
                    expiresAt: expiresAt,
                    isActive: isActive
                )
            )
        } catch NetworkError.unauthorized {
            throw AuthError.unauthorized
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw AuthError.invalidResponse
        } catch {
            logger.error("Update API key error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }

    func deleteAPIKey(id: String) async throws -> APIKey {
        do {
            return try await NetworkClient.shared.request(
                APIKeysEndpoint.delete(id: id)
            )
        } catch NetworkError.unauthorized {
            throw AuthError.unauthorized
        } catch NetworkError.httpError(let code, _) where code == 404 {
            throw AuthError.invalidResponse
        } catch {
            logger.error("Delete API key error: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }
}
