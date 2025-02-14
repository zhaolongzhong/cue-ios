import Foundation

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
protocol GenerativeAIRequest: Encodable {
  associatedtype Response: Decodable

  var url: URL { get }

  var options: RequestOptions { get }
}

/// Configuration parameters for sending requests to the backend.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct RequestOptions {
  /// The request’s timeout interval in seconds.
  let timeout: TimeInterval

  /// The API version to use in requests to the backend.
  let apiVersion: String

  /// Initializes a request options object.
  ///
  /// - Parameters:
  ///   - timeout: The request’s timeout interval in seconds; defaults to 300 seconds (5 minutes).
  ///   - apiVersion: The API version to use in requests to the backend; defaults to "v1beta".
  public init(timeout: TimeInterval = 300.0, apiVersion: String = "v1beta") {
    self.timeout = timeout
    self.apiVersion = apiVersion
  }
}
