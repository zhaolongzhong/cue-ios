import Foundation

@MainActor
final class AnthropicClient {
    private let configuration: Anthropic.Configuration
    private let session: URLSession

    init(configuration: Anthropic.Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func send<T: Decodable>(
        endpoint: String,
        method: String,
        body: Encodable? = nil
    ) async throws -> T {
        let url = configuration.baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw Anthropic.Error.invalidResponse
            }

            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? JSONDecoder().decode(Anthropic.APIError.self, from: data) {
                    throw Anthropic.Error.apiError(apiError)
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw Anthropic.Error.unexpectedAPIResponse(errorMessage)
                }
            }

            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error as Anthropic.Error {
            throw error
        } catch let error as DecodingError {
            throw Anthropic.Error.decodingError(error)
        } catch {
            throw Anthropic.Error.networkError(error)
        }
    }
}
