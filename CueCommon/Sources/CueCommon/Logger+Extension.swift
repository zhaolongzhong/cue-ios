//
//  Logger+Extension.swift
//  CueCommon
//
import os.log
import Foundation

// Extension to pretty print Encodable objects
extension Encodable {
    func prettyPrinted() -> String? {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)

            guard var dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return nil
            }

            dictionary.removeValue(forKey: "tools")

            let prettyData = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted])
            return String(data: prettyData, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// Extension for logging
extension Logger {
    public func debugRequest(_ message: String, body: Encodable?) {
        if let body = body, let prettyString = body.prettyPrinted() {
            self.debug("\(message):\n\(prettyString)")
        } else {
            self.debug("\(message): No body or unable to pretty print")
        }
    }
}
