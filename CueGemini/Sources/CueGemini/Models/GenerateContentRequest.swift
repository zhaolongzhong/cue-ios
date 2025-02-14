/// https://github.com/google-gemini/generative-ai-swift/blob/main/Sources/GoogleAI/GenerateContentRequest.swift
import Foundation

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
struct GenerateContentRequest {
  /// Model name.
  let model: String
  let contents: [ModelContent]
  let generationConfig: GenerationConfig?
  let safetySettings: [SafetySetting]?
  let tools: [Tool]?
  let toolConfig: ToolConfig?
  let systemInstruction: ModelContent?
  let isStreaming: Bool
  let options: RequestOptions
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GenerateContentRequest: Encodable {
  enum CodingKeys: String, CodingKey {
    case model
    case contents
    case generationConfig
    case safetySettings
    case tools
    case toolConfig
    case systemInstruction
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GenerateContentRequest: GenerativeAIRequest {
  typealias Response = GenerateContentResponse

  var url: URL {
    let modelURL = "\(GenerativeAISwift.baseURL)/\(options.apiVersion)/\(model)"
    if isStreaming {
      return URL(string: "\(modelURL):streamGenerateContent?alt=sse")!
    } else {
      return URL(string: "\(modelURL):generateContent")!
    }
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public enum GenerativeAISwift {
  /// String value of the SDK version
  public static let version = "0.5.6"
  /// The Google AI backend endpoint URL.
  static let baseURL = "https://generativelanguage.googleapis.com"
}
