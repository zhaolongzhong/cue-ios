//
//  CalendarService.swift
//  CueApp
//

import Foundation
import GoogleSignIn
import OSLog

struct CalendarService {
    static let tokenKey = "calendar_access_token"
    static let refreshTokenKey = "calendar_refresh_token"
    static let tokenExpirationKey = "calendar_token_expiration"

    static let logger = Logger(subsystem: "CalendarService", category: "CalendarTool")

    private static var clientId: String {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            fatalError("GIDClientID not found in Info.plist")
        }
        return clientId
    }

    // Get access token with automatic refresh if needed
    static func getAccessToken() async throws -> String {
        // Check if token needs refresh
        if let expirationDate = UserDefaults.standard.object(forKey: tokenExpirationKey) as? Date,
           Date() >= expirationDate {
            return try await refreshTokenOffline()
        }

        // Return stored token if available
        if let storedToken = UserDefaults.standard.string(forKey: tokenKey) {
            return storedToken
        }

        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw GmailServiceError.authenticationError
        }

        // If no stored token, get fresh token and store it
        let token = currentUser.accessToken.tokenString
        let expirationDate = currentUser.accessToken.expirationDate ?? Date().addingTimeInterval(3600) // Default to 1 hour if no expiration provided
        try storeToken(token, expirationDate: expirationDate)
        return token
    }

    // Store token and its expiration date
    static private func storeToken(_ token: String, expirationDate: Date) throws {
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(expirationDate, forKey: tokenExpirationKey)

        // Store refresh token if available
        if let refreshToken = GIDSignIn.sharedInstance.currentUser?.refreshToken.tokenString {
            UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        }

        if !UserDefaults.standard.synchronize() {
            throw GmailServiceError.tokenStorageError
        }
    }

    // Refresh token using refresh token
    static func refreshTokenOffline() async throws -> String {
        guard let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) else {
            throw GmailServiceError.tokenRefreshError
        }

        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw GmailServiceError.authenticationError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Parameters for public client token refresh
        let parameters = [
            "client_id": clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        let bodyString = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailServiceError.invalidResponse("Not an HTTPURLResponse")
        }

        if httpResponse.statusCode != 200 {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            AppLog.log.error("Token refresh failed with status code: \(httpResponse.statusCode), error: \(errorResponse)")
            throw GmailServiceError.tokenRefreshError
        }

        let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        let expirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))

        try storeToken(tokenResponse.accessToken, expirationDate: expirationDate)
        return tokenResponse.accessToken
    }

    // Clear stored tokens
    static func clearTokens() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpirationKey)
        UserDefaults.standard.synchronize()
    }

    private static func buildRequest(for endpoint: CalendarEndpoint) async throws -> URLRequest {
        let token = try await getAccessToken()
        let request = try endpoint.urlRequest(with: token, includeAdditionalHeaders: false)
        return request
    }

    // MARK: - Calendar Operations

    static func listCalendars() async throws -> String {
        let request = try await buildRequest(for: CalendarEndpoint.listCalendars)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            logger.error("Invalid response from Calendar API, status code: \(String(describing: (response as? HTTPURLResponse)?.statusCode)). json: \(String(data: data, encoding: .utf8) ?? "No JSON")")
            throw GmailServiceError.invalidResponse("Invalid response from Calendar API")
        }

        var result = "Calendars:\n"
        for (index, calendar) in items.enumerated() {
            if let id = calendar["id"] as? String, let summary = calendar["summary"] as? String {
                result += "\(index + 1). \(summary) (ID: \(id))\n"
            }
        }

        return result
    }

    static func listEvents(calendarId: String, maxResults: Int = 10) async throws -> String {
        let request = try await buildRequest(for: CalendarEndpoint.listEvents(calendarId: calendarId, maxResults: maxResults))
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            logger.error("Invalid response from Calendar API, status code: \(String(describing: (response as? HTTPURLResponse)?.statusCode)). json: \(String(data: data, encoding: .utf8) ?? "No JSON")")
            throw GmailServiceError.invalidResponse("Invalid response from Calendar API")
        }

        if items.isEmpty {
            return "No events found in the calendar."
        }

        var result = "Events:\n"
        for (index, event) in items.enumerated() {
            if let id = event["id"] as? String,
               let summary = event["summary"] as? String,
               let start = event["start"] as? [String: Any],
               let end = event["end"] as? [String: Any] {

                let startDateTime = start["dateTime"] as? String ?? start["date"] as? String ?? "Unknown"
                let endDateTime = end["dateTime"] as? String ?? end["date"] as? String ?? "Unknown"

                result += "\(index + 1). \(summary)\n"
                result += "   ID: \(id)\n"
                result += "   Start: \(formatDateTime(startDateTime))\n"
                result += "   End: \(formatDateTime(endDateTime))\n"

                if let description = event["description"] as? String, !description.isEmpty {
                    let shortDesc = description.count > 100 ? description.prefix(100) + "..." : description
                    result += "   Description: \(shortDesc)\n"
                }

                result += "\n"
            }
        }

        return result
    }

    static func getEvent(calendarId: String, eventId: String) async throws -> String {
        let request = try await buildRequest(for: CalendarEndpoint.getEvent(calendarId: calendarId, eventId: eventId))
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode == 200,
              let event = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("Invalid response from Calendar API, status code: \(String(describing: (response as? HTTPURLResponse)?.statusCode)). json: \(String(data: data, encoding: .utf8) ?? "No JSON")")
            throw GmailServiceError.invalidResponse("Invalid response from Calendar API")
        }

        var result = "Event Details:\n"

        if let summary = event["summary"] as? String {
            result += "Summary: \(summary)\n"
        }

        if let description = event["description"] as? String {
            result += "Description: \(description)\n"
        }

        if let start = event["start"] as? [String: Any],
           let startDateTime = start["dateTime"] as? String ?? start["date"] as? String {
            result += "Start: \(formatDateTime(startDateTime))\n"
        }

        if let end = event["end"] as? [String: Any],
           let endDateTime = end["dateTime"] as? String ?? end["date"] as? String {
            result += "End: \(formatDateTime(endDateTime))\n"
        }

        if let location = event["location"] as? String {
            result += "Location: \(location)\n"
        }

        if let status = event["status"] as? String {
            result += "Status: \(status)\n"
        }

        if let creator = event["creator"] as? [String: Any],
           let email = creator["email"] as? String {
            result += "Creator: \(email)\n"
        }

        return result
    }

    static func createEvent(calendarId: String, summary: String, description: String, startDateTime: Date, endDateTime: Date) async throws -> String {
        let request = try await buildRequest(for: CalendarEndpoint.createEvent(
            calendarId: calendarId,
            summary: summary,
            description: description,
            startDateTime: startDateTime,
            endDateTime: endDateTime
        ))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200...299).contains(statusCode),
              let event = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventId = event["id"] as? String else {
            logger.error("Invalid response from Calendar API, status code: \(String(describing: (response as? HTTPURLResponse)?.statusCode)). json: \(String(data: data, encoding: .utf8) ?? "No JSON")")
            throw GmailServiceError.invalidResponse("Failed to create event")
        }

        return "Event created successfully. Event ID: \(eventId)"
    }

    static func updateEvent(calendarId: String, eventId: String, summary: String?, description: String?, startDateTime: Date?, endDateTime: Date?) async throws -> String {
        let request = try await buildRequest(for: CalendarEndpoint.updateEvent(
            calendarId: calendarId,
            eventId: eventId,
            summary: summary,
            description: description,
            startDateTime: startDateTime,
            endDateTime: endDateTime
        ))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200...299).contains(statusCode),
              let event = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventId = event["id"] as? String else {
            logger.error("Invalid response from Calendar API, status code: \(String(describing: (response as? HTTPURLResponse)?.statusCode)). json: \(String(data: data, encoding: .utf8) ?? "No JSON")")
            throw GmailServiceError.invalidResponse("Failed to update event")
        }

        return "Event updated successfully. Event ID: \(eventId)"
    }

    static func deleteEvent(calendarId: String, eventId: String) async throws -> String {
        let request = try await buildRequest(for: CalendarEndpoint.deleteEvent(calendarId: calendarId, eventId: eventId))

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200...299).contains(statusCode) else {
            logger.error("Invalid response from Calendar API, status code: \(String(describing: (response as? HTTPURLResponse)?.statusCode)).")
            throw GmailServiceError.invalidResponse("Failed to delete event")
        }

        return "Event deleted successfully"
    }

    // MARK: - Helper Functions

    private static func formatDateTime(_ dateString: String) -> String {
        // Simple formatter to make the date more readable
        if let date = ISO8601DateFormatter().date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return dateString
    }
}
