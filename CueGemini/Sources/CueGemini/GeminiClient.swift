import Foundation
import os.log

@MainActor
final class GeminiClient {
    private let configuration: Gemini.Configuration
    private let session: URLSession
    private let logger = Logger(subsystem: "GeminiClient", category: "GeminiClient")

    init(configuration: Gemini.Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func send<T: Decodable>(
        endpoint: String,
        method: String,
        body: Encodable? = nil
    ) async throws -> T {
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)!

        components.queryItems = [
            URLQueryItem(name: "key", value: configuration.apiKey)
        ]
        
        guard let url = components.url else {
            throw Gemini.Error.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw Gemini.Error.invalidResponse
            }

            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? JSONDecoder().decode(Gemini.APIError.self, from: data) {
                    throw Gemini.Error.apiError(apiError)
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw Gemini.Error.unexpectedAPIResponse(errorMessage)
                }
            }

            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error as Gemini.Error {
            throw error
        } catch let error as DecodingError {
            throw Gemini.Error.decodingError(error)
        } catch {
            throw Gemini.Error.networkError(error)
        }
    }
}
