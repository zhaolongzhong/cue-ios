import XCTest
@testable import CueApp

actor MockNetworkClient: NetworkClientProtocol {
    enum MockError: Error {
        case noMockResponseSet
        case invalidMockResponse
    }
    
    // Store mock responses for different endpoints
    private var mockResponses: [String: Result<Any, Error>] = [:]
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        // Use endpoint description as key to find mock response
        let key = String(describing: endpoint)
        guard let mockResult = mockResponses[key] else {
            throw MockError.noMockResponseSet
        }
        
        switch mockResult {
        case .success(let value):
            guard let response = value as? T else {
                throw MockError.invalidMockResponse
            }
            return response
        case .failure(let error):
            throw error
        }
    }
    
    // Helper method to set success response
    func setResponse<T>(_ value: T, for endpoint: Endpoint) {
        let key = String(describing: endpoint)
        mockResponses[key] = .success(value)
    }
    
    // Helper method to set error response
    func setError(_ error: Error, for endpoint: Endpoint) {
        let key = String(describing: endpoint)
        mockResponses[key] = .failure(error)
    }
}

final class AuthServiceTests: XCTestCase {
    var mockNetworkClient: MockNetworkClient!
    var authService: AuthService!
    
    override func setUp() async throws {
        try await super.setUp()
        EnvironmentConfig.shared = EnvironmentConfig(domain: "test-api.example.com")
        mockNetworkClient = MockNetworkClient()
        authService = AuthService(networkClient: mockNetworkClient)
    }
    
    override func tearDown() async throws {
        EnvironmentConfig.resetShared()
        try await super.tearDown()
    }
    
    func testLoginSuccess() async throws {
        let expectedToken = TokenResponse(accessToken: "test-token", refreshToken: "refresh-token", tokenType: "token-type")
        await mockNetworkClient.setResponse(
            expectedToken,
            for: AuthEndpoint.login(email: "test@example.com", password: "password123")
        )
        
        let result = try await authService.login(email: "test@example.com", password: "password123")
        XCTAssertEqual(result.accessToken, expectedToken.accessToken)
        XCTAssertEqual(result.refreshToken, expectedToken.refreshToken)
    }
    
    func testLoginInvalidCredentials() async throws {
        await mockNetworkClient.setError(
            NetworkError.unauthorized,
            for: AuthEndpoint.login(email: "test@example.com", password: "wrong-password")
        )
        
        do {
            _ = try await authService.login(email: "test@example.com", password: "wrong-password")
            XCTFail("Expected invalid credentials error")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
    }
    
    func testSignupEmailAlreadyExists() async throws {
        await mockNetworkClient.setError(
            NetworkError.httpError(409, nil),
            for: AuthEndpoint.signup(email: "existing@example.com", password: "password123", inviteCode: nil)
        )
        
        do {
            _ = try await authService.signup(email: "existing@example.com", password: "password123", inviteCode: nil)
            XCTFail("Expected email already exists error")
        } catch {
            XCTAssertEqual(error as? AuthError, .emailAlreadyExists)
        }
    }
    
    func testFetchUserProfileUnauthorized() async throws {
        await mockNetworkClient.setError(
            NetworkError.unauthorized,
            for: AuthEndpoint.me
        )
        
        do {
            _ = try await authService.fetchUserProfile()
            XCTFail("Expected unauthorized error")
        } catch {
            XCTAssertEqual(error as? AuthError, .unauthorized)
        }
    }
}
