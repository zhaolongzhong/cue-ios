import Foundation

public enum JSONFormatter {
    public static func prettyString(from jsonObject: Any) -> String? {
        do {
            let prettyData = try JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted]
            )
            return String(data: prettyData, encoding: .utf8)
        } catch {
            return nil
        }
    }

    public static func prettyString(from jsonString: String) -> String? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            return prettyString(from: jsonObject)
        } catch {
            return nil
        }
    }

    public static func stringify(_ value: Any) -> String {
        if let str = value as? String {
            return "\"\(str.replacingOccurrences(of: "\"", with: "\\\""))\""
        } else {
            return "\(value)"
        }
    }
}
