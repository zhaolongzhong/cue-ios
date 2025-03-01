import Foundation

@MainActor
final class OpenAIHTTPClient {
    let configuration: OpenAI.Configuration
    let session: URLSession
    
    init(configuration: OpenAI.Configuration, session: URLSession = .shared) {
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
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAI.Error.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? JSONDecoder().decode(OpenAI.APIError.self, from: data) {
                    throw OpenAI.Error.apiError(apiError)
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw OpenAI.Error.unexpectedAPIResponse(errorMessage)
                }
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
            
        } catch let error as OpenAI.Error {
            throw error
        } catch let error as DecodingError {
            throw OpenAI.Error.decodingError(error)
        } catch {
            throw OpenAI.Error.networkError(error)
        }
    }
}
