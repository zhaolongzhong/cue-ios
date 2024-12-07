import Foundation

@MainActor
final class OpenAIClient {
    private let configuration: OpenAI.Configuration
    private let session: URLSession
    
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
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw OpenAI.Error.apiError(errorMessage)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw OpenAI.Error.decodingError(error)
        } catch {
            throw OpenAI.Error.networkError(error)
        }
    }
}
