/// https://github.com/google-gemini/generative-ai-swift/blob/main/Sources/GoogleAI/GenerateContentResponse.swift
import Foundation

/// The model's response to a generate content request.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct GenerateContentResponse: Equatable, Sendable {
  /// Token usage metadata for processing the generate content request.
    public struct UsageMetadata: Equatable, Sendable {
    /// The number of tokens in the request prompt.
    public let promptTokenCount: Int

    /// The total number of tokens across the generated response candidates.
    public let candidatesTokenCount: Int

    /// The total number of tokens in both the request and response.
    public let totalTokenCount: Int
  }

  /// A list of candidate response content, ordered from best to worst.
  public let candidates: [CandidateResponse]

  /// A value containing the safety ratings for the response, or, if the request was blocked, a
  /// reason for blocking the request.
  public let promptFeedback: PromptFeedback?

  /// Token usage metadata for processing the generate content request.
  public let usageMetadata: UsageMetadata?

  /// The response's content as text, if it exists.
  public var text: String? {
    guard let candidate = candidates.first else {
      return nil
    }
    let textValues: [String] = candidate.content.parts.compactMap { part in
      switch part {
      case let .text(text):
        return text
      case let .executableCode(executableCode):
        let codeBlockLanguage: String
        if executableCode.language == "LANGUAGE_UNSPECIFIED" {
          codeBlockLanguage = ""
        } else {
          codeBlockLanguage = executableCode.language.lowercased()
        }
        return "```\(codeBlockLanguage)\n\(executableCode.code)\n```"
      case let .codeExecutionResult(codeExecutionResult):
        if codeExecutionResult.output.isEmpty {
          return nil
        }
        return "```\n\(codeExecutionResult.output)\n```"
      case .data, .fileData, .functionCall, .functionResponse:
        return nil
      }
    }
    guard textValues.count > 0 else {
      return nil
    }
    return textValues.joined(separator: "\n")
  }

  /// Returns function calls found in any `Part`s of the first candidate of the response, if any.
  public var functionCalls: [FunctionCall] {
    guard let candidate = candidates.first else {
      return []
    }
    return candidate.content.parts.compactMap { part in
      guard case let .functionCall(functionCall) = part else {
        return nil
      }
      return functionCall
    }
  }

  /// Initializer for SwiftUI previews or tests.
  public init(candidates: [CandidateResponse], promptFeedback: PromptFeedback? = nil,
              usageMetadata: UsageMetadata? = nil) {
    self.candidates = candidates
    self.promptFeedback = promptFeedback
    self.usageMetadata = usageMetadata
  }
}

/// A struct representing a possible reply to a content generation prompt. Each content generation
/// prompt may produce multiple candidate responses.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct CandidateResponse: Equatable, Sendable {
  /// The response's content.
  public let content: ModelContent

  /// The safety rating of the response content.
  public let safetyRatings: [SafetyRating]

  /// The reason the model stopped generating content, if it exists; for example, if the model
  /// generated a predefined stop sequence.
  public let finishReason: FinishReason?

  /// Cited works in the model's response content, if it exists.
  public let citationMetadata: CitationMetadata?

  /// Initializer for SwiftUI previews or tests.
  public init(content: ModelContent, safetyRatings: [SafetyRating], finishReason: FinishReason?,
              citationMetadata: CitationMetadata?) {
    self.content = content
    self.safetyRatings = safetyRatings
    self.finishReason = finishReason
    self.citationMetadata = citationMetadata
  }
}

/// A collection of source attributions for a piece of content.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct CitationMetadata: Equatable, Sendable {
  /// A list of individual cited sources and the parts of the content to which they apply.
  public let citationSources: [Citation]
}

/// A struct describing a source attribution.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct Citation: Equatable, Sendable {
  /// The inclusive beginning of a sequence in a model response that derives from a cited source.
  public let startIndex: Int

  /// The exclusive end of a sequence in a model response that derives from a cited source.
  public let endIndex: Int

  /// A link to the cited source.
  public let uri: String?

  /// The license the cited source work is distributed under, if specified.
  public let license: String?
}

/// A value enumerating possible reasons for a model to terminate a content generation request.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public enum FinishReason: String, Sendable {
  case unknown = "FINISH_REASON_UNKNOWN"

  case unspecified = "FINISH_REASON_UNSPECIFIED"

  /// Natural stop point of the model or provided stop sequence.
  case stop = "STOP"

  /// The maximum number of tokens as specified in the request was reached.
  case maxTokens = "MAX_TOKENS"

  /// The token generation was stopped because the response was flagged for safety reasons.
  /// NOTE: When streaming, the Candidate.content will be empty if content filters blocked the
  /// output.
  case safety = "SAFETY"

  /// The token generation was stopped because the response was flagged for unauthorized citations.
  case recitation = "RECITATION"

  /// All other reasons that stopped token generation.
  case other = "OTHER"
}

/// A metadata struct containing any feedback the model had on the prompt it was provided.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct PromptFeedback: Equatable, Sendable {
  /// A type describing possible reasons to block a prompt.
    public enum BlockReason: String, Sendable {
    /// The block reason is unknown.
    case unknown = "UNKNOWN"

    /// The block reason was not specified in the server response.
    case unspecified = "BLOCK_REASON_UNSPECIFIED"

    /// The prompt was blocked because it was deemed unsafe.
    case safety = "SAFETY"

    /// All other block reasons.
    case other = "OTHER"
  }

  /// The reason a prompt was blocked, if it was blocked.
  public let blockReason: BlockReason?

  /// The safety ratings of the prompt.
  public let safetyRatings: [SafetyRating]

  /// Initializer for SwiftUI previews or tests.
  public init(blockReason: BlockReason?, safetyRatings: [SafetyRating]) {
    self.blockReason = blockReason
    self.safetyRatings = safetyRatings
  }
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GenerateContentResponse: Decodable {
  enum CodingKeys: CodingKey {
    case candidates
    case promptFeedback
    case usageMetadata
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    guard container.contains(CodingKeys.candidates) || container
      .contains(CodingKeys.promptFeedback) else {
      let context = DecodingError.Context(
        codingPath: [],
        debugDescription: "Failed to decode GenerateContentResponse;" +
          " missing keys 'candidates' and 'promptFeedback'."
      )
      throw DecodingError.dataCorrupted(context)
    }

    if let candidates = try container.decodeIfPresent(
      [CandidateResponse].self,
      forKey: .candidates
    ) {
      self.candidates = candidates
    } else {
      candidates = []
    }
    promptFeedback = try container.decodeIfPresent(PromptFeedback.self, forKey: .promptFeedback)
    usageMetadata = try container.decodeIfPresent(UsageMetadata.self, forKey: .usageMetadata)
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GenerateContentResponse.UsageMetadata: Decodable {
  enum CodingKeys: CodingKey {
    case promptTokenCount
    case candidatesTokenCount
    case totalTokenCount
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    promptTokenCount = try container.decodeIfPresent(Int.self, forKey: .promptTokenCount) ?? 0
    candidatesTokenCount = try container
      .decodeIfPresent(Int.self, forKey: .candidatesTokenCount) ?? 0
    totalTokenCount = try container.decodeIfPresent(Int.self, forKey: .totalTokenCount) ?? 0
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CandidateResponse: Decodable {
  enum CodingKeys: CodingKey {
    case content
    case safetyRatings
    case finishReason
    case finishMessage
    case citationMetadata
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    do {
      if let content = try container.decodeIfPresent(ModelContent.self, forKey: .content) {
        self.content = content
      } else {
        content = ModelContent(parts: [])
      }
    } catch {
      // Check if `content` can be decoded as an empty dictionary to detect the `"content": {}` bug.
      if let content = try? container.decode([String: String].self, forKey: .content),
         content.isEmpty {
        throw InvalidCandidateError.emptyContent(underlyingError: error)
      } else {
        throw InvalidCandidateError.malformedContent(underlyingError: error)
      }
    }

    if let safetyRatings = try container.decodeIfPresent(
      [SafetyRating].self,
      forKey: .safetyRatings
    ) {
      self.safetyRatings = safetyRatings
    } else {
      safetyRatings = []
    }

    finishReason = try container.decodeIfPresent(FinishReason.self, forKey: .finishReason)

    citationMetadata = try container.decodeIfPresent(
      CitationMetadata.self,
      forKey: .citationMetadata
    )
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CitationMetadata: Decodable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension Citation: Decodable {
  enum CodingKeys: CodingKey {
    case startIndex
    case endIndex
    case uri
    case license
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    startIndex = try container.decodeIfPresent(Int.self, forKey: .startIndex) ?? 0
    endIndex = try container.decodeIfPresent(Int.self, forKey: .endIndex) ?? 0
    uri = try container.decodeIfPresent(String.self, forKey: .uri)
    license = try container.decodeIfPresent(String.self, forKey: .license)
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension FinishReason: Decodable {
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let decodedFinishReason = FinishReason(rawValue: value) else {
      self = .unknown
      return
    }

    self = decodedFinishReason
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension PromptFeedback.BlockReason: Decodable {
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let decodedBlockReason = PromptFeedback.BlockReason(rawValue: value) else {
      self = .unknown
      return
    }

    self = decodedBlockReason
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension PromptFeedback: Decodable {
  enum CodingKeys: CodingKey {
    case blockReason
    case safetyRatings
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    blockReason = try container.decodeIfPresent(
      PromptFeedback.BlockReason.self,
      forKey: .blockReason
    )
    if let safetyRatings = try container.decodeIfPresent(
      [SafetyRating].self,
      forKey: .safetyRatings
    ) {
      self.safetyRatings = safetyRatings
    } else {
      safetyRatings = []
    }
  }
}
